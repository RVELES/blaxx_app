//
//  BiometricGate.swift
//  BlaxxPontos
//
//  Pede confirmação biométrica (Face ID / Touch ID) antes de transações
//  financeiras. Fallback automático para passcode do dispositivo se a
//  biometria não estiver disponível.
//

import Foundation
#if canImport(LocalAuthentication)
import LocalAuthentication
#endif

enum BiometricGate {
    /// Solicita autenticação biométrica do usuário. Retorna `true` se a
    /// autenticação foi concedida. `false` em caso de cancelamento, falha,
    /// ou indisponibilidade do hardware.
    ///
    /// - Parameter reason: Texto exibido pelo iOS na prompt; deve descrever
    ///   a operação ("Confirmar envio de pontos", etc.).
    static func authenticate(reason: String) async -> Bool {
        #if canImport(LocalAuthentication)
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Usar senha do dispositivo"

        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) {
            return await evaluate(ctx: ctx,
                                  policy: .deviceOwnerAuthenticationWithBiometrics,
                                  reason: reason)
        }
        // Sem biometria configurada — cai para passcode do dispositivo.
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            return await evaluate(ctx: ctx,
                                  policy: .deviceOwnerAuthentication,
                                  reason: reason)
        }
        // Sem nenhum método disponível: em DEBUG deixa passar (simulator),
        // em release nega para não burlar a proteção.
        #if DEBUG
        return true
        #else
        return false
        #endif
        #else
        return true
        #endif
    }

    #if canImport(LocalAuthentication)
    private static func evaluate(ctx: LAContext, policy: LAPolicy, reason: String) async -> Bool {
        await withCheckedContinuation { cont in
            ctx.evaluatePolicy(policy, localizedReason: reason) { ok, _ in
                cont.resume(returning: ok)
            }
        }
    }
    #endif
}
