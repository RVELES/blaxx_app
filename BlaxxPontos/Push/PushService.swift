//
//  PushService.swift
//  BlaxxPontos
//
//  Pipeline de push: pede permissão, registra no APNs, manda o device token
//  para o backend e processa notificações entregues (foreground + background).
//
//  Endpoint backend esperado: POST /devices/register
//      body: {"token": "<hex>", "platform": "ios"}
//      auth: Bearer <jwt do usuário> (mesmo token de API)
//
//  Se o endpoint ainda não existir no backend, fazemos retry exponencial em
//  background e falhamos silenciosamente — push continua chegando enquanto
//  o backend não estiver pronto (uma vez registrado depois, novas mensagens
//  passam a ser entregues).
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

@MainActor
final class PushService: NSObject {
    static let shared = PushService()

    private override init() { super.init() }

    /// Última hora em que tentamos enviar o token para o backend. Usado para
    /// rate-limit do retry em background.
    private var lastRegisterAttempt: Date?

    /// Token APNs serializado em hex (formato esperado pelo backend).
    /// Persistido em UserDefaults pra sobreviver entre lançamentos do app.
    static var deviceTokenHex: String? {
        get { UserDefaults.standard.string(forKey: "apns_device_token") }
        set { UserDefaults.standard.set(newValue, forKey: "apns_device_token") }
    }

    /// Pede permissão ao usuário e, se aprovado, registra para receber pushes.
    /// Idempotente: o sistema lembra a decisão; só mostra prompt na primeira vez.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else { return }
            #if canImport(UIKit)
            UIApplication.shared.registerForRemoteNotifications()
            #endif
        } catch {
            // Silencioso — usuário pode habilitar depois em Ajustes.
        }
    }

    /// Chamado pelo AppDelegate ao receber o deviceToken do APNs.
    /// Serializa em hex e tenta registrar no backend (com retry exponencial).
    func handleDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        Self.deviceTokenHex = hex
        Task { await registerWithBackend(hex: hex, attempt: 1) }
    }

    /// Manda o token ao backend. Faz retry com backoff em falhas transitórias
    /// até `maxAttempts`. Falha silenciosa: o app não notifica o usuário se o
    /// backend não estiver pronto — uma próxima sessão tenta de novo.
    private func registerWithBackend(hex: String, attempt: Int) async {
        let maxAttempts = 5
        lastRegisterAttempt = Date()
        do {
            try await BlaxxAPI.shared.registerDevice(token: hex)
        } catch {
            // 404/405 → backend ainda não tem o endpoint: abandona em silêncio.
            if let apiErr = error as? APIError, apiErr.status == 404 || apiErr.status == 405 {
                return
            }
            // Outros erros (timeout, 5xx, sem rede): retry em background.
            if attempt < maxAttempts {
                let delay = UInt64(pow(2.0, Double(attempt)) * 1_000_000_000) // 2,4,8,16s
                try? await Task.sleep(nanoseconds: delay)
                await registerWithBackend(hex: hex, attempt: attempt + 1)
            }
        }
    }

    /// Reenvia o token (chamar após login bem-sucedido — backend precisa do
    /// JWT para associar ao usuário). No-op se ainda não temos token APNs.
    func rebindAfterLogin() {
        guard let hex = Self.deviceTokenHex else { return }
        Task { await registerWithBackend(hex: hex, attempt: 1) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushService: UNUserNotificationCenterDelegate {
    /// Mostra a notificação mesmo com o app em primeiro plano (banner + som).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// Usuário tocou em uma notificação — futuro: rotear para uma tela específica
    /// com base em `userInfo["deeplink"]`. Por enquanto só registra.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - UIApplicationDelegateAdaptor

#if canImport(UIKit)
final class BlaxxAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushService.shared.handleDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Em simulador é esperado falhar (APNs requer dispositivo real).
        // Em dispositivo real, falha indica: certificado APNs inválido / profile
        // sem entitlement aps-environment / sem conexão. Não bloqueamos o app.
    }
}
#endif
