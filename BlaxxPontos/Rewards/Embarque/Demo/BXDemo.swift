//
//  BXDemo.swift
//  BlaxxPontos · Modo demonstração "Embarque" (§4 da spec)
//
//  Argumentos de lançamento lidos SÓ em DEBUG. Em Release, o mesmo `enum` existe com todas as
//  chaves desligadas (constantes `false`/`nil`), para que as telas possam ler `BXDemo.subtela`,
//  `BXDemo.ancora` etc. sem `#if`. Nenhum dado de exemplo mora aqui.
//
//  DEBUG:
//    -BXGaleria [YES]            abre a galeria do design system no lugar do app (ContentView)
//    -BXGaleriaPagina <n>        abre direto a página n da galeria (para fotos)
//    -BXFonteEmbarcada [YES]     usa Archivo + Space Mono (comparação com o web; D16)
//    -BXCongelar [YES]           para letreiros e brilhos (fotos determinísticas)
//    -BXDemo [YES]               sessão logada "Cliente Demo"; tudo pelo BXTransporteDemo (zero rede)
//    -BXDemoVisitante [YES]      visitante, com respostas públicas de exemplo
//    -BXDemoEstado <e>           carregando | vazio | erro | offline | pixIndisponivel
//    -BXDemoEmailPendente [YES]  usuário de exemplo com e-mail ainda não verificado
//    -BXTela <id>                abre direto num destino (ids em docs/redesenho/06-nucleo.md; `BXDemo.telaInicial`)
//    -BXSubtela <nome>           passo interno (valorLivre pix pago confirmar concluido lancamento totp senha
//                                excluir 2fa maisCategorias); cada grupo lê `BXDemo.subtela`
//    -BXAncora <id>              rola até `.id(id)` (cada grupo define as suas); `BXDemo.ancora`
//    -BXTesteNucleo [YES]        teste do núcleo contra o backend LOCAL (BXTesteNucleo.swift); exige
//                                -BXTesteLogin <e-mail de seed.py> -BXTesteSenha <senha de seed.py>
//    -BXLogRede                  uma linha por requisição no console (método, caminho, status)
//

import Foundation

nonisolated enum BXDemo {
    #if DEBUG
    private static let argumentos = ProcessInfo.processInfo.arguments

    /// Valor que segue a chave (nil se ausente ou se o próximo item for outra chave).
    private static func valor(_ chave: String) -> String? {
        guard let i = argumentos.firstIndex(of: chave), i + 1 < argumentos.count else { return nil }
        let v = argumentos[i + 1]
        return v.hasPrefix("-") ? nil : v
    }

    /// Chave presente e não desligada ("NO", "0", "false").
    private static func ligado(_ chave: String) -> Bool {
        guard argumentos.contains(chave) else { return false }
        if let v = valor(chave) { return !["NO", "no", "0", "false", "FALSE"].contains(v) }
        return true
    }

    static let ativo = ligado("-BXDemo")
    static let visitante = ligado("-BXDemoVisitante")
    static let estado = valor("-BXDemoEstado")
    static let tela = valor("-BXTela")
    static let subtela = valor("-BXSubtela")
    static let ancora = valor("-BXAncora")
    static let galeria = ligado("-BXGaleria")
    static let galeriaPagina: Int? = valor("-BXGaleriaPagina").flatMap { Int($0) }
    static let fonteEmbarcada = ligado("-BXFonteEmbarcada")
    static let congelar = ligado("-BXCongelar")
    static let emailPendente = ligado("-BXDemoEmailPendente")
    static let testeNucleo = ligado("-BXTesteNucleo")
    /// Destino de `-BXTela` já interpretado (nil sem argumento ou id desconhecido).
    static let telaInicial: BXTelaDemo? = tela.flatMap(BXTelaDemo.init(id:))
    #else
    static let ativo = false
    static let visitante = false
    static let estado: String? = nil
    static let tela: String? = nil
    static let subtela: String? = nil
    static let ancora: String? = nil
    static let galeria = false
    static let galeriaPagina: Int? = nil
    static let fonteEmbarcada = false
    static let congelar = false
    static let emailPendente = false
    static let testeNucleo = false
    static let telaInicial: BXTelaDemo? = nil
    #endif
}

/// O que `-BXTela <id>` abre. Existe nas duas builds (em Release `BXDemo.telaInicial` é sempre nil).
/// A casca (G1) trata: `.destino` → `nav.ir(_:)` (destinos de acesso na pilha de visitante),
/// `.gaveta` → `nav.abrirGaveta()`, `.galeria` → galeria do design system (DEBUG).
nonisolated enum BXTelaDemo: Hashable, Sendable {
    case destino(BXDestino)
    case gaveta
    /// Galeria do design system: `icones` → página 2; `componentes` → índice (nil).
    case galeria(pagina: Int?)

    var destino: BXDestino? { if case let .destino(d) = self { return d }; return nil }

    #if DEBUG
    /// ids: inicio carteira extrato[:entradas|saidas] cartao notificacoes comprar[:<pacote>] historico
    /// enviar[:<para>] receber parceiros[:<busca>] parceiro:<id> resgates meusResgates beneficio:<id>
    /// voucher:<id> campanhas perfil seguranca privacidade convidar ajuda faq boasVindas entrar cadastro
    /// recuperar redefinir[:<token>] verificarEmail gaveta icones componentes
    init?(id bruto: String) {
        let partes = bruto.split(separator: ":", maxSplits: 1).map(String.init)
        let id = partes.first ?? ""
        let arg = partes.count > 1 ? partes[1] : nil
        switch id {
        case "inicio": self = .destino(.inicio)
        case "carteira": self = .destino(.carteira)
        case "extrato": self = .destino(.extrato(arg.flatMap(BXFiltroExtrato.init(rawValue:)) ?? .tudo))
        case "cartao", "cartaoBlaxx": self = .destino(.cartaoBlaxx)
        case "notificacoes": self = .destino(.notificacoes)
        case "comprar": self = .destino(.comprar(pacote: arg))
        case "historico", "historicoCompras": self = .destino(.historicoCompras)
        case "enviar": self = .destino(.enviar(para: arg))
        case "receber": self = .destino(.receber)
        case "parceiros": self = .destino(.parceiros(busca: arg))
        case "parceiro": self = .destino(.parceiro(id: arg ?? "cafe-ponto-doce"))
        case "resgates": self = .destino(.resgates(.catalogo))
        case "meusResgates": self = .destino(.resgates(.meusResgates))
        case "beneficio": self = .destino(.beneficio(id: arg ?? "b-cafe-expresso"))
        case "voucher": self = .destino(.voucher(id: arg ?? "v-ativo"))
        case "campanhas": self = .destino(.campanhas)
        case "perfil": self = .destino(.perfil)
        case "seguranca": self = .destino(.seguranca)
        case "privacidade": self = .destino(.privacidade)
        case "convidar": self = .destino(.convidar)
        case "ajuda": self = .destino(.ajuda)
        case "faq": self = .destino(.faq)
        case "boasVindas": self = .destino(.boasVindas)
        case "entrar": self = .destino(.entrar)
        case "cadastro": self = .destino(.cadastro)
        case "recuperar", "recuperarSenha": self = .destino(.recuperarSenha)
        case "redefinir", "redefinirSenha": self = .destino(.redefinirSenha(token: arg ?? "demo-token"))
        case "verificarEmail": self = .destino(.verificarEmail)
        case "gaveta": self = .gaveta
        case "icones": self = .galeria(pagina: 2)
        case "componentes": self = .galeria(pagina: arg.flatMap { Int($0) })
        default: return nil
        }
    }
    #endif
}
