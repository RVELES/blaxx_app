//
//  BXNavegacao.swift
//  BlaxxPontos · Núcleo "Embarque" (fundação G0)
//
//  Abas, grupos, destinos e o estado de navegação compartilhado (§1.7.7 da spec).
//  Comunicação entre grupos só por `BXDestino` + `BXNavegacao`: nenhuma tela chama outra diretamente.
//  A casca (G1) liga `NavigationStack(path:)` a `pilhas[aba]` / `pilhaVisitante` e resolve cada
//  destino em `BXTelas<Grupo>.tela(_:)`. Ver docs/redesenho/06-nucleo.md.
//

import Foundation
import Observation
import SwiftUI
#if os(iOS)
import UIKit
import SafariServices
#endif

/// As quatro abas da casca logada. "Menu" não é aba: abre a gaveta.
nonisolated enum BXAba: String, CaseIterable, Hashable, Sendable {
    case inicio, carteira, comprar, resgates

    /// Abas mostradas na barra. "Comprar" some quando a compra no app está desligada (`BXRecursos.compraNoApp`).
    static var visiveis: [BXAba] { allCases.filter { $0 != .comprar || BXRecursos.compraNoApp } }
}

/// Dono de cada destino (seção 5 da spec).
nonisolated enum BXGrupo: String, Hashable, Sendable {
    case acesso, saldo, movimentar, descobrir, conta
}

nonisolated enum BXFiltroExtrato: String, Hashable, Sendable { case tudo, entradas, saidas }
nonisolated enum BXAbaResgates: String, Hashable, Sendable { case catalogo, meusResgates }

/// Todos os lugares do app. `Hashable` para `NavigationStack(path:)` e `navigationDestination(for:)`.
nonisolated enum BXDestino: Hashable, Sendable {
    // G1 Acesso (visitante; verificarEmail é sheet do logado)
    case boasVindas, entrar, cadastro, recuperarSenha
    case redefinirSenha(token: String? = nil)
    case verificarEmail
    // G2 Saldo
    case inicio, carteira
    case extrato(BXFiltroExtrato = .tudo)
    case cartaoBlaxx, notificacoes
    // G3 Movimentar
    case comprar(pacote: String? = nil)
    case historicoCompras
    case enviar(para: String? = nil)
    case receber
    // G4 Descobrir
    case parceiros(busca: String? = nil)
    case parceiro(id: String)
    case resgates(BXAbaResgates = .catalogo)
    case beneficio(id: String)
    case voucher(id: String)
    case campanhas
    // G5 Conta
    case perfil, seguranca, privacidade, convidar, ajuda, faq

    var grupo: BXGrupo {
        switch self {
        case .boasVindas, .entrar, .cadastro, .recuperarSenha, .redefinirSenha, .verificarEmail: return .acesso
        case .inicio, .carteira, .extrato, .cartaoBlaxx, .notificacoes: return .saldo
        case .comprar, .historicoCompras, .enviar, .receber: return .movimentar
        case .parceiros, .parceiro, .resgates, .beneficio, .voucher, .campanhas: return .descobrir
        case .perfil, .seguranca, .privacidade, .convidar, .ajuda, .faq: return .conta
        }
    }

    /// Destinos da compra de pontos (somem quando `BXRecursos.compraNoApp` é falso).
    var ehCompra: Bool {
        switch self {
        case .comprar, .historicoCompras: return true
        default: return false
        }
    }

    /// Destinos que trocam de aba (o resto empilha na aba atual).
    var aba: BXAba? {
        switch self {
        case .inicio: return .inicio
        case .carteira: return .carteira
        case .comprar: return .comprar
        case .resgates: return .resgates
        default: return nil
        }
    }

    /// Públicos: parceiros, parceiro, resgates(.catalogo), beneficio, campanhas, ajuda, faq e as telas de acesso.
    var exigeLogin: Bool {
        switch self {
        case .boasVindas, .entrar, .cadastro, .recuperarSenha, .redefinirSenha: return false
        case .parceiros, .parceiro, .beneficio, .campanhas, .ajuda, .faq: return false
        case .resgates(let aba): return aba != .catalogo
        default: return true
        }
    }

    /// Raiz padrão de cada aba.
    static func raiz(_ aba: BXAba) -> BXDestino {
        switch aba {
        case .inicio: return .inicio
        case .carteira: return .carteira
        case .comprar: return .comprar(pacote: nil)
        case .resgates: return .resgates(.catalogo)
        }
    }

    /// Deep links do esquema `blaxxpontos://` (G1 trata em `onOpenURL`):
    /// `blaxxpontos://redefinir-senha?token=…` (e `reset`), `blaxxpontos://enviar?para=<CARTAO>`.
    static func deLink(_ url: URL) -> BXDestino? {
        guard url.scheme?.lowercased() == "blaxxpontos",
              let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let alvo = (comp.host ?? comp.path).trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        func parametro(_ nome: String) -> String? {
            comp.queryItems?.first(where: { $0.name == nome })?.value?.trimmingCharacters(in: .whitespaces)
        }
        switch alvo {
        case "redefinir-senha", "reset", "reset-password":
            guard let t = parametro("token"), !t.isEmpty else { return nil }
            return .redefinirSenha(token: t)
        case "enviar", "send":
            let para = parametro("para").flatMap { $0.isEmpty ? nil : $0 }
            return .enviar(para: para)
        default:
            return nil
        }
    }
}

/// Estado de navegação compartilhado. A casca cria UMA instância e injeta com `.environment(_:)`;
/// as telas leem com `@Environment(BXNavegacao.self)`.
@MainActor @Observable final class BXNavegacao {
    var aba: BXAba = .inicio
    /// Pilha de cada aba (sem a raiz). A casca liga `NavigationStack(path:)` aqui (`pilha(_:)`).
    var pilhas: [BXAba: [BXDestino]] = [:]
    /// Raiz de cada aba. Muda quando um destino de aba traz parâmetro (ex.: `.comprar(pacote: "black")`,
    /// `.resgates(.meusResgates)`): a casca desenha `raiz(da:)` e deve aplicar `.id(raiz(da: aba))`
    /// para a tela raiz reiniciar com o parâmetro novo.
    var raizes: [BXAba: BXDestino] = [:]
    var pilhaVisitante: [BXDestino] = []
    var gavetaAberta = false
    /// A casca apresenta a verificação de e-mail (sheet) enquanto for true.
    var pedidoVerificacaoEmail = false
    /// Deep link ou ação de visitante que exige login: a casca segue para cá ao entrar.
    var destinoAposEntrar: BXDestino?
    /// Espelho de `BXSessao.estado == .logado`, mantido pela casca via `sessaoMudou(logado:)`.
    private(set) var logado = false
    /// Incrementa quando a aba atual é tocada de novo (a tela raiz pode rolar ao topo).
    private(set) var retoques: [BXAba: Int] = [:]

    init() {}

    func raiz(da aba: BXAba) -> BXDestino { raizes[aba] ?? BXDestino.raiz(aba) }
    func pilha(_ aba: BXAba) -> [BXDestino] { pilhas[aba] ?? [] }

    /// Pilha visível agora (visitante ou aba atual).
    var pilhaAtual: [BXDestino] { logado ? pilha(aba) : pilhaVisitante }

    /// Com aba: troca de aba, limpa a pilha e (se houver parâmetro) troca a raiz. Sem aba: empilha.
    /// Visitante: destino que exige conta vira `pedirEntrada(depois:)`; o resto empilha na pilha de visitante.
    func ir(_ d: BXDestino) {
        gavetaAberta = false
        if d.ehCompra && !BXRecursos.compraNoApp { return }      // compra fora do app iOS (preparação App Store)
        guard logado else {
            if d.exigeLogin { pedirEntrada(depois: d); return }
            if d == .boasVindas { pilhaVisitante = []; return }
            if pilhaVisitante.last != d { pilhaVisitante.append(d) }
            return
        }
        switch d {
        case .boasVindas, .entrar, .cadastro, .recuperarSenha, .redefinirSenha:
            return                                  // telas de visitante não abrem logado
        case .verificarEmail:
            exigirVerificacaoEmail(); return
        default: break
        }
        if let a = d.aba {
            aba = a
            raizes[a] = d
            pilhas[a] = []
        } else {
            var p = pilha(aba)
            if p.last != d { p.append(d) }
            pilhas[aba] = p
        }
    }

    func voltar() {
        if logado {
            var p = pilha(aba)
            if !p.isEmpty { p.removeLast() }
            pilhas[aba] = p
        } else if !pilhaVisitante.isEmpty {
            pilhaVisitante.removeLast()
        }
    }

    func voltarParaRaiz() {
        if logado { pilhas[aba] = [] } else { pilhaVisitante = [] }
    }

    /// Toque na aba já selecionada: volta à raiz padrão (sem parâmetro) e avisa a tela raiz (`retoques`).
    func retocar(_ a: BXAba) {
        if a == aba {
            pilhas[a] = []
            raizes[a] = nil
            retoques[a, default: 0] += 1
        } else if BXAba.visiveis.contains(a) {
            aba = a
        }
    }

    func abrirGaveta() { gavetaAberta = true }
    func fecharGaveta() { gavetaAberta = false }

    /// Chamar ao receber `BXErro.tipo == .emailNaoVerificado`.
    func exigirVerificacaoEmail() { pedidoVerificacaoEmail = true }

    /// Visitante tocou em algo que exige conta: guarda o destino e abre Entrar.
    func pedirEntrada(depois d: BXDestino?) {
        gavetaAberta = false
        if let d, d.ehCompra, !BXRecursos.compraNoApp { return }
        if logado { if let d { ir(d) }; return }
        destinoAposEntrar = d
        if pilhaVisitante.last != .entrar { pilhaVisitante.append(.entrar) }
    }

    /// A casca chama quando `BXSessao.estado` muda. Ao entrar: limpa a pilha de visitante e segue para o
    /// destino pendente. Ao sair: volta tudo para o início.
    func sessaoMudou(logado novo: Bool) {
        guard novo != logado else { return }
        logado = novo
        gavetaAberta = false
        if novo {
            pilhaVisitante = []
            let pendente = destinoAposEntrar
            destinoAposEntrar = nil
            if let pendente, pendente.grupo != .acesso { ir(pendente) }
        } else {
            pilhas = [:]
            raizes = [:]
            aba = .inicio
            pilhaVisitante = []
            pedidoVerificacaoEmail = false
        }
    }

    /// Abre `https://blaxxpontos.com.br/<caminho>` num SFSafariViewController (termos, regulamento, etc.).
    func abrirSite(_ caminho: String) {
        let limpo = caminho.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "https://blaxxpontos.com.br/" + limpo) else { return }
        #if os(iOS)
        guard let cena = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let raiz = (cena.windows.first(where: { $0.isKeyWindow }) ?? cena.windows.first)?.rootViewController else { return }
        var topo = raiz
        while let p = topo.presentedViewController { topo = p }
        let safari = SFSafariViewController(url: url)
        topo.present(safari, animated: true)
        #endif
    }
}

extension BXNavegacao {
    /// Binding para `NavigationStack(path:)` da aba.
    func vinculo(pilha a: BXAba) -> Binding<[BXDestino]> {
        Binding(get: { self.pilha(a) }, set: { self.pilhas[a] = $0 })
    }
    /// Binding para `NavigationStack(path:)` do visitante.
    var vinculoVisitante: Binding<[BXDestino]> {
        Binding(get: { self.pilhaVisitante }, set: { self.pilhaVisitante = $0 })
    }
    /// Binding para a seleção da `BXTabBar` (toque repetido é tratado por `retocar`).
    var vinculoAba: Binding<BXAba> {
        Binding(get: { self.aba }, set: { self.aba = $0 })
    }
}
