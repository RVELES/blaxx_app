//
//  BXCacheCarteira.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  "Saldo do último acesso": o último saldo conhecido, válido por 1 hora, para o Início não abrir vazio
//  enquanto o servidor acorda. A tela mostra o selo "SALDO DO ÚLTIMO ACESSO" (`BXSessao.carteiraDoCache`).
//  Limpo no sair e na sessão revogada. Em modo demonstração não lê nem grava (não mistura com o real).
//

import Foundation

nonisolated enum BXCacheCarteira {
    private static let chave = "bx_carteira_cache_v2"
    private static let validade: TimeInterval = 60 * 60

    private struct Registro: Codable {
        let carteira: BXCarteira
        let gravadoEm: Date
        let usuarioID: String?
    }

    private static var desligado: Bool { BXDemo.ativo || BXDemo.visitante }

    /// Último saldo se gravado há menos de 1 h (e, se informado, do mesmo usuário).
    static func ler(usuarioID: String? = nil) -> BXCarteira? {
        guard !desligado, let dados = UserDefaults.standard.data(forKey: chave),
              let r = try? JSONDecoder().decode(Registro.self, from: dados),
              Date.now.timeIntervalSince(r.gravadoEm) < validade else { return nil }
        if let usuarioID, let dono = r.usuarioID, dono != usuarioID { return nil }
        return r.carteira
    }

    static func gravar(_ c: BXCarteira, usuarioID: String?) {
        guard !desligado, let dados = try? JSONEncoder().encode(Registro(carteira: c, gravadoEm: .now, usuarioID: usuarioID)) else { return }
        UserDefaults.standard.set(dados, forKey: chave)
    }

    static func limpar() {
        UserDefaults.standard.removeObject(forKey: chave)
    }
}
