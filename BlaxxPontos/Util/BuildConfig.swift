//
//  BuildConfig.swift
//  BlaxxPontos
//
//  Bandeira de build usada para condicionar UI/comportamento de homologação.
//  Em DEBUG (Xcode / TestFlight de desenvolvimento) tudo continua aparecendo
//  para auditoria; em RELEASE os selos, contas demo, e botões de simulação
//  ficam escondidos.
//

import Foundation

enum BuildConfig {
    /// True em builds RELEASE (App Store / TestFlight de release).
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
