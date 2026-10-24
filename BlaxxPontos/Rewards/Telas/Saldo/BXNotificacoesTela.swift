//
//  BXNotificacoesTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Notificações (central-notificacoes.html, fotos 35): "CENTRAL DE NOTIFICAÇÕES" / "Tudo que aconteceu na sua
//  conta." · pílulas Todas/Não lidas · "Marcar todas como lidas" · lista: ícone neon pelo TIPO (nunca o
//  `icon` do servidor), título seguro, tempo relativo, corpo filtrado (regras do dono), bolinha de não lida.
//  Toque marca como lida e abre o destino; deslizar marca como lida. Atualiza o sino (`BXSessao.naoLidas`).
//  É uma `List` (e não a página rolável comum) para ter `swipeActions`.
//

import SwiftUI

struct BXNotificacoesTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast
    @Environment(\.accessibilityReduceMotion) private var reduzido

    @State private var carga: BXCarga<[BXNotificacao]> = .carregando
    @State private var soNaoLidas = false
    @State private var marcandoTodas = false
    @State private var carregou = false
    @Namespace private var pilulas

    var body: some View {
        List {
            Group {
                cabecalho
                    .padding(.top, 24)
                acoes
                conteudo
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: BXEspaco.margem, bottom: 6, trailing: BXEspaco.margem))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BXCor.chao, in: Rectangle())
        .frame(maxWidth: BXEspaco.colunaMax)
        .frame(maxWidth: .infinity)
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await carregar() }
        .task {
            guard !carregou else { return }
            carregou = true
            await carregar()
        }
    }

    private func carregar() async {
        do {
            let r = try await BXAPI.shared.notificacoes()
            carga = r.itens.isEmpty ? .vazio : .pronto(r.itens.sorted { $0.criadaEm > $1.criadaEm })
            sessao.definirNaoLidas(r.naoLidas)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            carga = .erro(BXErro.de(error))
        }
    }

    // MARK: cabeçalho e ações

    private var cabecalho: some View {
        BXCabecalhoPagina(eyebrow: "Central de notificações", titulo: "Tudo que aconteceu na sua conta.")
            .padding(.bottom, 8)
    }

    private var naoLidas: Int { carga.valor?.filter { !$0.lida }.count ?? 0 }

    private var acoes: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BXPilula("Todas", ativa: !soNaoLidas, estilo: .conta, animacao: pilulas) {
                    withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) { soNaoLidas = false }
                }
                BXPilula("Não lidas", contador: carga.valor == nil ? nil : naoLidas, ativa: soNaoLidas, estilo: .conta, animacao: pilulas) {
                    withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) { soNaoLidas = true }
                }
            }
            BXBotao("Marcar todas como lidas", estilo: .secundario, carregando: marcandoTodas) {
                Task { await marcarTodas() }
            }
            .disabled(naoLidas == 0)
        }
        .padding(.bottom, 6)
    }

    // MARK: lista

    @ViewBuilder private var conteudo: some View {
        switch carga {
        case .ocioso, .carregando:
            ForEach(0..<5, id: \.self) { _ in BXEsqueleto(.linhaExtrato).padding(.horizontal, 14).bxSuperficie(raio: BXRaio.md) }
        case .vazio:
            BXEstadoVazio(icone: .notificacoes, titulo: "Nenhuma notificação ainda.",
                          texto: "Avisos de compras, envios, resgates e da sua conta aparecem aqui.")
        case .erro(let e):
            BXEstadoErro(e) { await carregar() }
        case .pronto(let itens):
            let visiveis = soNaoLidas ? itens.filter { !$0.lida } : itens
            if visiveis.isEmpty {
                BXEstadoVazio(icone: .check, titulo: "Nenhuma não lida.", texto: "Você está em dia.")
            } else {
                ForEach(visiveis) { n in
                    Button { Task { await abrir(n) } } label: { linha(n) }
                        .buttonStyle(BXEstiloPressao())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if !n.lida {
                                Button("Marcar como lida") { Task { await marcar(n) } }
                                    .tint(BXCor.tinta)
                            }
                        }
                        .accessibilityAction(named: "Marcar como lida") { Task { await marcar(n) } }
                }
            }
        }
    }

    private func linha(_ n: BXNotificacao) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BXIcone(n.icone, tamanho: .atalho)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(n.titulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Text(BXFormato.relativo(n.criadaEm)).font(BXFonte.fonte(.recibo, tamanho: 12)).foregroundStyle(BXCor.cinza)
                }
                if let corpo = n.corpoSeguro {
                    Text(corpo).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !n.lida {
                Circle().fill(BXCor.neon)
                    .overlay(Circle().strokeBorder(BXCor.tinta, lineWidth: 1.5))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bxSuperficie(raio: BXRaio.md, borda: n.lida ? BXCor.linha : BXCor.tinta)
        .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido), value: n.lida)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(n.lida ? "" : "Não lida. ")\(n.titulo). \(n.corpoSeguro ?? ""). \(BXFormato.relativo(n.criadaEm))")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: ações

    private func substituir(_ n: BXNotificacao) {
        guard var itens = carga.valor, let i = itens.firstIndex(where: { $0.id == n.id }) else { return }
        itens[i] = n.marcadaComoLida()
        carga = .pronto(itens)
        sessao.definirNaoLidas(itens.filter { !$0.lida }.count)
    }

    private func marcar(_ n: BXNotificacao) async {
        guard !n.lida else { return }
        withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) { substituir(n) }
        do { try await BXAPI.shared.marcarLida(id: n.id) } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            await carregar()
        }
    }

    private func abrir(_ n: BXNotificacao) async {
        if !n.lida { Task { await marcar(n) } }
        if let d = destino(n) { nav.ir(d) }
    }

    private func destino(_ n: BXNotificacao) -> BXDestino? {
        switch n.tipo {
        case "purchase", "transfer", "expiration": return .extrato()
        case "voucher": return n.referencia.map { .voucher(id: $0) } ?? .resgates(.meusResgates)
        case "redeem": return .resgates(.meusResgates)
        case "campaign": return BXRecursos.campanhas ? .campanhas : nil
        default: return nil
        }
    }

    private func marcarTodas() async {
        marcandoTodas = true
        defer { marcandoTodas = false }
        do {
            try await BXAPI.shared.marcarTodasLidas()
            if let itens = carga.valor {
                withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) {
                    carga = .pronto(itens.map { $0.lida ? $0 : $0.marcadaComoLida() })
                }
            }
            sessao.definirNaoLidas(0)
            BXHaptica.tocar(.sucesso)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            toast.mostrar(e.mensagemParaUsuario, .erro)
        }
    }
}
