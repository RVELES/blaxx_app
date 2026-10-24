//
//  BXPainelPartidasDados.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Lista do quadro "Painel de partidas · Mapa" da boas-vindas, portada de `blaxx/home-embarque.html`
//  (CIDADES_MUNDO) e `blaxx/assets/blaxx-globo.js` (BLAXX_POINTS / BLAXX_SUPPLIERS).
//  No Brasil só São Paulo (Postos) e Rio de Janeiro (Supermercados) entram no mapa, como no web (pedido de 15/10);
//  as cidades do mundo são "rede em expansão" e NÃO ganham serviços inventados.
//  Não é dado de exemplo: é o mesmo conteúdo público da home do site (rótulos da vertical, sem marca de terceiro).
//

import SwiftUI

nonisolated struct BXCidadePainel: Identifiable, Hashable, Sendable {
    let id: String
    let nome: String
    let pais: String
    /// Verticais com rede em implantação na cidade (vazio = rede em expansão).
    let verticais: [BXVerticalPainel]
    let latitude: Double
    let longitude: Double

    var ativa: Bool { !verticais.isEmpty }
    @MainActor var linha: BXQuadroLinha { BXQuadroLinha(id: id, destino: nome, pais: pais, ativa: ativa) }
}

nonisolated enum BXVerticalPainel: String, Hashable, Sendable {
    case postos, mercado, farmacia

    var nome: String {
        switch self {
        case .postos: return "Postos"
        case .mercado: return "Supermercados"
        case .farmacia: return "Farmácias"
        }
    }

    /// Termo de busca da tela de parceiros (categoria canônica).
    var busca: String { nome }

    /// Cores da legenda do web (`BLAXX_SUPPLIERS.rgb`).
    var cor: Color {
        switch self {
        case .postos: return Color(red: 231 / 255, green: 178 / 255, blue: 74 / 255)
        case .mercado: return Color(red: 79 / 255, green: 201 / 255, blue: 106 / 255)
        case .farmacia: return Color(red: 63 / 255, green: 198 / 255, blue: 216 / 255)
        }
    }
}

nonisolated enum BXPainelPartidasDados {
    static let cidades: [BXCidadePainel] = {
        var lista: [BXCidadePainel] = [
            BXCidadePainel(id: "sao-paulo", nome: "São Paulo", pais: "Brasil", verticais: [.postos], latitude: -23.55, longitude: -46.63),
            BXCidadePainel(id: "rio-de-janeiro", nome: "Rio de Janeiro", pais: "Brasil", verticais: [.mercado], latitude: -22.91, longitude: -43.2)
        ]
        let mundo: [(String, String, Double, Double)] = [
            ("Nova York", "Estados Unidos", 40.71, -74.01), ("Los Angeles", "Estados Unidos", 34.05, -118.24),
            ("Miami", "Estados Unidos", 25.76, -80.19), ("Toronto", "Canadá", 43.65, -79.38),
            ("Cidade do México", "México", 19.43, -99.13), ("Bogotá", "Colômbia", 4.71, -74.07),
            ("Lima", "Peru", -12.05, -77.04), ("Santiago", "Chile", -33.45, -70.67),
            ("Buenos Aires", "Argentina", -34.6, -58.38), ("Lisboa", "Portugal", 38.72, -9.14),
            ("Madrid", "Espanha", 40.42, -3.7), ("Paris", "França", 48.86, 2.35),
            ("Londres", "Reino Unido", 51.51, -0.13), ("Berlim", "Alemanha", 52.52, 13.4),
            ("Roma", "Itália", 41.9, 12.5), ("Istambul", "Turquia", 41.01, 28.98),
            ("Cairo", "Egito", 30.04, 31.24), ("Joanesburgo", "África do Sul", -26.2, 28.05),
            ("Dubai", "Emirados Árabes", 25.2, 55.27), ("Mumbai", "Índia", 19.08, 72.88),
            ("Singapura", "Singapura", 1.35, 103.82), ("Xangai", "China", 31.23, 121.47),
            ("Tóquio", "Japão", 35.68, 139.69), ("Seul", "Coreia do Sul", 37.57, 126.98),
            ("Sydney", "Austrália", -33.87, 151.21)
        ]
        for (nome, pais, lat, lon) in mundo {
            let id = BXSanitizador.normalizar(nome).replacingOccurrences(of: " ", with: "-")
            lista.append(BXCidadePainel(id: id, nome: nome, pais: pais, verticais: [], latitude: lat, longitude: lon))
        }
        return lista
    }()

    /// Verticais presentes no mapa (para a legenda), na ordem do web.
    static var verticaisPresentes: [BXVerticalPainel] {
        var vistas: [BXVerticalPainel] = []
        for c in cidades { for v in c.verticais where !vistas.contains(v) { vistas.append(v) } }
        return vistas
    }

    static func cidade(id: String?) -> BXCidadePainel? {
        guard let id else { return nil }
        return cidades.first { $0.id == id }
    }
}
