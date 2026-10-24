//
//  BXRaiz.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Casca)
//
//  Raiz do app novo (ContentView → BXRaiz). Cria a sessão, a navegação, os toasts e a conectividade,
//  injeta no ambiente e escolhe a casca pelo estado da sessão:
//    .iniciando → abertura (wordmark sobre tinta) · .visitante → BXVisitanteCasca · .logado → BXCasca.
//  Também: verificação de e-mail (sheet), deep links (`redefinir-senha`, `enviar?para=`), volta ao
//  primeiro plano, push só depois do login (D12) e `-BXTela` do modo demonstração.
//  Claro por `.environment(\.colorScheme, .light)` (NÃO `.preferredColorScheme`, que no iOS 27 escurece a
//  barra de status sobre a barra preta; 05-fundacao §2.1) e `.tint(BXCor.tinta)` (o AccentColor é o lima legado).
//

import SwiftUI

struct BXRaiz: View {
    @State private var sessao = BXSessao()
    @State private var nav = BXNavegacao()
    @State private var toast = BXToastCentral()
    @State private var conectividade = BXConectividade()
    @State private var fluxo = BXFluxoAcesso()
    @Environment(\.scenePhase) private var fase
    #if DEBUG
    @State private var galeria: BXTelaDemo?
    #endif

    var body: some View {
        conteudo
            .environment(sessao)
            .environment(nav)
            .environment(toast)
            .environment(conectividade)
            .environment(fluxo)
            .environment(\.colorScheme, .light)
            .tint(BXCor.tinta)
            .bxToastHost(toast)
            .sheet(isPresented: verificandoEmail) {
                BXVerificarEmailTela()
                    .environment(sessao)
                    .environment(nav)
                    .environment(toast)
                    .environment(fluxo)
                    .environment(\.colorScheme, .light)
                    .tint(BXCor.tinta)
            }
            .task { await iniciar() }
            .onChange(of: sessao.estado) { _, estado in
                nav.sessaoMudou(logado: estado == .logado)
                if estado == .logado { Task { await PushService.shared.aposEntrar() } }
            }
            .onChange(of: fase) { _, f in
                if f == .active { Task { await sessao.aoVoltarPrimeiroPlano() } }
            }
            .onOpenURL(perform: abrirLink)
    }

    @ViewBuilder private var conteudo: some View {
        #if DEBUG
        if let galeria, case let .galeria(pagina) = galeria {
            if let pagina { BXGaleria.pagina(pagina) } else { BXGaleria() }
        } else {
            casca
        }
        #else
        casca
        #endif
    }

    @ViewBuilder private var casca: some View {
        ZStack {
            switch sessao.estado {
            case .iniciando:
                BXAbertura().transition(.opacity)
            case .visitante:
                BXVisitanteCasca().transition(.opacity)
            case .logado:
                BXCasca().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessao.estado)
    }

    private var verificandoEmail: Binding<Bool> {
        Binding(get: { nav.pedidoVerificacaoEmail && sessao.logado },
                set: { if !$0 { nav.pedidoVerificacaoEmail = false } })
    }

    private func iniciar() async {
        sessao.toast = toast
        await sessao.iniciar()
        nav.sessaoMudou(logado: sessao.logado)
        aplicarTelaDemo()
        #if DEBUG
        await BXTesteNucleo.rodarSePedido()
        #endif
    }

    /// `-BXTela <id>` (só DEBUG; em Release `BXDemo.telaInicial` é sempre nil).
    private func aplicarTelaDemo() {
        guard let t = BXDemo.telaInicial else { return }
        switch t {
        case .destino(let d):
            switch d {
            case .boasVindas: break
            case .verificarEmail: nav.exigirVerificacaoEmail()
            default: nav.ir(d)
            }
        case .gaveta:
            nav.abrirGaveta()
        case .galeria:
            #if DEBUG
            galeria = t
            #endif
        }
    }

    private func abrirLink(_ url: URL) {
        guard let d = BXDestino.deLink(url) else { return }
        if case .redefinirSenha = d, sessao.logado {
            toast.mostrar("Para redefinir a senha por este link, saia da conta primeiro.", .info)
            return
        }
        nav.ir(d)
    }
}

/// Abertura enquanto a sessão é lida do cofre: wordmark sobre tinta.
private struct BXAbertura: View {
    var body: some View {
        ZStack {
            BXCor.tinta.ignoresSafeArea()
            BXWordmark(.barra, altura: 30)
        }
        .accessibilityElement()
        .accessibilityLabel("BlaXx Pontos, carregando")
    }
}
