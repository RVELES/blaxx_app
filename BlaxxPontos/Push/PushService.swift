//
//  PushService.swift
//  BlaxxPontos
//
//  Pipeline de push: pede permissão, registra no APNs, manda o device token
//  para o backend e processa notificações entregues (foreground + background).
//
//  Redesenho "Embarque" (D12): a permissão só é pedida DEPOIS do login (`aposEntrar()`, chamado pela
//  BXRaiz) e o registro no backend vai por `BXPushRegistro` (POST /push/devices/register com o token da
//  sessão nova; o `sair()` da BXSessao remove o aparelho). Em modo demonstração nada é registrado.
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

    /// Manda o token ao backend pelo núcleo novo (`BXPushRegistro`, só com sessão logada).
    /// Falha silenciosa com poucas novas tentativas: sem rede, a próxima abertura tenta de novo.
    private func registerWithBackend(hex: String, attempt: Int) async {
        let maxAttempts = 3
        lastRegisterAttempt = Date()
        await BXPushRegistro.registrar(token: hex)
        if UserDefaults.standard.string(forKey: "bx_push_dispositivo_id") == nil, attempt < maxAttempts {
            try? await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
            await registerWithBackend(hex: hex, attempt: attempt + 1)
        }
    }

    /// Depois do login (D12): pede permissão (o sistema só pergunta uma vez) e registra o aparelho.
    /// Se o token do APNs já é conhecido, registra na hora. Não faz nada no modo demonstração.
    func aposEntrar() async {
        guard !BXDemo.ativo, !BXDemo.visitante else { return }
        if let hex = Self.deviceTokenHex { await registerWithBackend(hex: hex, attempt: 1) }
        await requestAuthorizationAndRegister()
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
