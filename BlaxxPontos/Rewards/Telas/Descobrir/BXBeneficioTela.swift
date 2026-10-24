//
//  BXBeneficioTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Detalhe do benefício → confirmar (sheet .medium) → resgate concluído, com dados reais
//  (`GET /benefits/<id>`, `POST /benefits/<id>/redeem` com Idempotency-Key). Fluxo das telas fixas do web
//  `beneficio-detalhe` → `confirmar-resgate` → `resgate-concluido` e o estado de `saldo-insuficiente`
//  (fotos web 16, 17, 18, 40), sem nada do conteúdo inventado delas (Netflix, e-mail de entrega, aceites).
//  O backend não pede senha no resgate de benefício: a confirmação é o toque em "Confirmar resgate".
//

import SwiftUI

struct BXBeneficioTela: View {
    let id: String

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    @State private var carga: BXCarga<BXBeneficio> = .carregando
    @State private var confirmando = false
    @State private var voucher: BXVoucher?
    @State private var aviso = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                BXColunaDescobrir {
                    BXFarelo(itens: [("Início", { nav.ir(.inicio) }), ("Resgates", { nav.ir(.resgates(.catalogo)) }),
                                     (carga.valor?.nome ?? "Benefício", nil)])
                        .padding(.bottom, 20)
                    if let voucher, let b = carga.valor {
                        BXResgateConcluidoVista(voucher: voucher, beneficio: b)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        switch carga {
                        case .ocioso, .carregando:
                            BXEsqueleto(.bloco(altura: 320)).padding(.bottom, 24)
                            BXEsqueleto(.bloco(altura: 220))
                        case .erro(let e) where e.tipo == .naoEncontrado:
                            BXEstadoVazio(icone: .resgates, titulo: "Benefício não encontrado.",
                                          texto: "Este benefício saiu do catálogo ou o endereço mudou.",
                                          acao: (titulo: "Ver catálogo", executar: { nav.ir(.resgates(.catalogo)) }))
                        case .erro(let e):
                            BXEstadoErro(e) { await carregar() }
                        case .vazio:
                            EmptyView()
                        case .pronto(let b):
                            conteudo(b)
                        }
                    }
                }
            }
            .modifier(BXAncoraDemo(pronto: carga.valor != nil, proxy: proxy))
        }
        .background(BXCor.chao, in: Rectangle())
        .animation(BXMovimento.ease, value: voucher?.id)
        .refreshable { if voucher == nil { await sessao.recarregarCarteira(); await carregar() } }
        .task { if carga.valor == nil { await carregar() } }
        .sheet(isPresented: $confirmando) {
            if let b = carga.valor {
                BXConfirmarResgateSheet(beneficio: b) { v in
                    confirmando = false
                    voucher = v
                }
            }
        }
        .sensoryFeedback(.warning, trigger: aviso)
        .modifier(BXZoomDestino(id: "beneficio-\(id)"))
    }

    // MARK: - Conteúdo

    @ViewBuilder private func conteudo(_ b: BXBeneficio) -> some View {
        let saldo = sessao.carteira?.saldo
        let faltam = saldo.map { b.faltam(saldo: $0) } ?? 0

        cartaoBeneficio(b)
            .padding(.bottom, 24)

        if b.esgotado {
            estadoEsgotado
        } else if !sessao.logado {
            visitante(b)
        } else if let saldo, faltam > 0 {
            insuficiente(b, saldo: saldo, faltam: faltam)
                .onAppear { aviso += 1 }
        } else {
            reciboResumo(b, saldo: saldo)
        }
    }

    private func cartaoBeneficio(_ b: BXBeneficio) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                BXCor.superficie2
                BXIcone(b.icone, tamanho: .livre(lado: 96, raio: 22))
            }
            .frame(height: 170)
            .overlay(alignment: .bottom) { Rectangle().fill(BXCor.linha).frame(height: 1) }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    BXChip(b.rotuloCategoria, .eyebrow)
                    if let tag = b.tag { BXChip(tag, .eyebrow) }
                    Spacer(minLength: 0)
                    if b.esgotado { BXStatus("Esgotado", .perigo) }
                }
                Text(b.nome).bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let d = b.descricaoSegura {
                    Text(d).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(BXFormato.pontos(b.custo)).bxFonte(.pontosBilhete)
                    Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Custo, \(BXFormato.pontosFalados(b.custo))")
                BXGradeDados(dadosGrade(b))
                if let pid = b.parceiroID, !b.daBlaxx {
                    BXLinkSeta("Ver \(b.nomeParceiro ?? "o parceiro")") { nav.ir(.parceiro(id: pid)) }
                }
            }
            .padding(EdgeInsets(top: 18, leading: 18, bottom: 22, trailing: 18))
        }
        .bxSuperficie(raio: BXRaio.xl, sombra: .padrao)
    }

    private func dadosGrade(_ b: BXBeneficio) -> [BXDado] {
        var d: [BXDado] = [BXDado("Parceiro", b.daBlaxx ? "BlaXx" : (b.nomeParceiro ?? "Parceiro selecionado"))]
        if let dias = b.validadeDias, dias > 0 {
            d.append(BXDado("Validade do voucher", "\(BXFormato.pontos(dias)) \(dias == 1 ? "dia" : "dias")"))
        }
        if b.esgotado { d.append(BXDado("Estoque", "Esgotado")) }
        else if b.estoqueIlimitado { d.append(BXDado("Estoque", "Disponível")) }
        else { d.append(BXDado("Estoque", "\(BXFormato.pontos(b.estoque)) \(b.estoque == 1 ? "restante" : "restantes")")) }
        d.append(BXDado("Confirmação", "No app"))
        return d
    }

    private func reciboResumo(_ b: BXBeneficio, saldo: Int?) -> some View {
        BXRecibo(cabeca: "Resumo do resgate",
                 acao: .init(titulo: "Resgatar agora →") { confirmando = true }) {
            BXReciboTracejo()
            BXReciboLinha("Benefício", b.nome)
            BXReciboLinha("Seu saldo", saldo.map { "\(BXFormato.pontos($0)) pts" } ?? "—")
            BXReciboLinha("Custo", "\(BXFormato.pontos(b.custo)) pts")
            BXReciboTracejo()
            BXReciboTotal("Saldo após", saldo.map { "\(BXFormato.pontos($0 - b.custo)) pts" } ?? "—")
            BXReciboFaixa("Pedido processado", "até 1 dia útil")
            BXReciboNota("O voucher aparece em Meus resgates logo depois da confirmação. Os pontos de cada benefício seguem a tabela de resgate publicada na plataforma.")
            BXReciboVia()
        }
    }

    private func insuficiente(_ b: BXBeneficio, saldo: Int, faltam: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            BXStatus("Saldo insuficiente", .aviso)
            Text("Faltam \(BXFormato.pontos(faltam)) pts para este benefício.")
                .bxFonte(.h2).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                BXProgresso(fracao: b.custo > 0 ? min(1, Double(saldo) / Double(b.custo)) : 0)
                HStack {
                    Text("Você tem \(BXFormato.pontos(saldo)) pts")
                    Spacer(minLength: 8)
                    Text("Custo \(BXFormato.pontos(b.custo)) pts")
                }
                .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            }
            .accessibilityElement(children: .combine)
            Text(BXRecursos.compraNoApp
                 ? "Compre pontos com cartão ou transferência e volte para resgatar. Pontos são créditos promocionais de uso restrito na plataforma."
                 : "Junte mais pontos e volte para resgatar. Pontos são créditos promocionais de uso restrito na plataforma.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
            if BXRecursos.compraNoApp { BXBotao("Comprar pontos") { nav.ir(.comprar()) } }
            BXBotao("Ver outros benefícios", estilo: .secundario) { nav.ir(.resgates(.catalogo)) }
        }
        .padding(18)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .id("insuficiente")
    }

    private var estadoEsgotado: some View {
        BXEstadoVazio(icone: .alerta, titulo: "Este benefício está esgotado no momento.",
                      texto: "O estoque depende da disponibilidade do parceiro. Veja outros benefícios do catálogo.",
                      acao: (titulo: "Ver outros benefícios", executar: { nav.ir(.resgates(.catalogo)) }))
    }

    private func visitante(_ b: BXBeneficio) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Entre na sua conta para resgatar.").bxFonte(.h2)
                .fixedSize(horizontal: false, vertical: true)
            Text("O resgate usa os pontos do seu saldo e o voucher fica guardado em Meus resgates.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
            BXBotao("Entrar para resgatar", estilo: .preto) { nav.pedirEntrada(depois: .beneficio(id: b.id)) }
            BXBotao("Criar conta", estilo: .secundario) { nav.ir(.cadastro) }
        }
        .padding(18)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
    }

    // MARK: - Carga

    private func carregar() async {
        do {
            let b = try await BXAPI.shared.beneficio(id: id)
            carga = .pronto(b)
            if sessao.logado && sessao.carteira == nil { await sessao.recarregarCarteira() }
            abrirSubtelaDemo(b)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = carga { return }
            carga = .erro(BXErro.de(error))
        }
    }

    /// `-BXSubtela confirmar|concluido` (só tem efeito em DEBUG com `-BXDemo`).
    private func abrirSubtelaDemo(_ b: BXBeneficio) {
        guard BXDemo.ativo, voucher == nil else { return }
        switch BXDemo.subtela {
        case "confirmar":
            Task { try? await Task.sleep(for: .milliseconds(500)); confirmando = true }
        case "concluido":
            Task {
                if let v = try? await BXAPI.shared.resgatarBeneficio(id: b.id, chave: BXChaveIdempotencia()) {
                    voucher = v
                    await sessao.recarregarCarteira()
                }
            }
        default: break
        }
    }
}

// MARK: - Confirmar resgate (sheet .medium)

struct BXConfirmarResgateSheet: View {
    let beneficio: BXBeneficio
    let concluido: (BXVoucher) -> Void

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.dismiss) private var fechar

    /// Uma chave por intenção: repetida em "Tentar de novo", trocada só depois de resposta definitiva.
    @State private var chave = BXChaveIdempotencia()
    @State private var enviando = false
    @State private var erro: String?
    @State private var falhou = 0

    var body: some View {
        let b = beneficio
        let saldo = sessao.carteira?.saldo
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirmar resgate").bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                    Text(b.nome).bxFonte(.h2).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                VStack(spacing: 12) {
                    BXReciboLinha("Parceiro", b.daBlaxx ? "BlaXx" : (b.nomeParceiro ?? "Parceiro selecionado"))
                    BXReciboLinha("Seu saldo", saldo.map { "\(BXFormato.pontos($0)) pts" } ?? "—")
                    BXReciboLinha("Custo", "\(BXFormato.pontos(b.custo)) pts")
                    BXTracejado(cor: BXCor.tinta)
                    BXReciboTotal("Saldo após", saldo.map { "\(BXFormato.pontos($0 - b.custo)) pts" } ?? "—")
                }
                Text("Os pontos saem do seu saldo agora e o voucher fica em Meus resgates.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
                if let erro {
                    HStack(alignment: .top, spacing: 10) {
                        BXIcone(.alerta, tamanho: .aba)
                        Text(erro).bxFonte(.corpo).foregroundStyle(BXCor.perigoTexto)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(BXCor.perigoFundo, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
                BXBotao("Confirmar resgate", estilo: .preto, carregando: enviando) { Task { await resgatar() } }
                    .disabled(enviando)
                BXBotao("Cancelar", estilo: .secundario) { fechar() }
                    .disabled(enviando)
            }
            .padding(EdgeInsets(top: 28, leading: 20, bottom: 20, trailing: 20))
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
        .presentationBackground(BXCor.superficie)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(enviando)
        .environment(\.colorScheme, .light)
        .sensoryFeedback(.error, trigger: falhou)
    }

    private func resgatar() async {
        enviando = true
        erro = nil
        defer { enviando = false }
        do {
            let v = try await BXAPI.shared.resgatarBeneficio(id: beneficio.id, chave: chave)
            chave = BXChaveIdempotencia()
            BXHaptica.tocar(.sucesso)
            await sessao.recarregarCarteira()
            concluido(v)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            let e = BXErro.de(error)
            switch e.tipo {
            case .semConexao, .tempoEsgotado:
                // Mesma chave no "Tentar de novo": o servidor devolve o mesmo voucher se já tiver emitido.
                erro = "Sem resposta da BlaXx. Confira a conexão e toque de novo em Confirmar resgate."
            case .saldoInsuficiente:
                chave = BXChaveIdempotencia()
                erro = "Saldo insuficiente para este benefício."
                await sessao.recarregarCarteira()
            case .semEstoque:
                chave = BXChaveIdempotencia()
                erro = "Este benefício esgotou agora há pouco."
            case .emailNaoVerificado:
                chave = BXChaveIdempotencia()
                fechar()
                nav.exigirVerificacaoEmail()
                return
            case .sessaoExpirada:
                fechar()
                return
            default:
                chave = BXChaveIdempotencia()
                erro = e.mensagemParaUsuario
            }
            falhou += 1
        }
    }
}

// MARK: - Resgate concluído

struct BXResgateConcluidoVista: View {
    let voucher: BXVoucher
    let beneficio: BXBeneficio

    @Environment(BXNavegacao.self) private var nav
    @Environment(BXToastCentral.self) private var toast

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                BXStatus("Resgate confirmado", .ok)
                Text("Seu voucher está pronto.").bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            BXRecibo(cabeca: "Voucher") {
                BXReciboTracejo()
                VStack(alignment: .leading, spacing: 8) {
                    Text("CÓDIGO").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(voucher.codigo.isEmpty ? "—" : voucher.codigo)
                        .bxFonte(.saldoMono)
                        .foregroundStyle(BXCor.tinta)
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .textSelection(.enabled)
                        .accessibilityLabel("Código \(voucher.codigo.map { String($0) }.joined(separator: " "))")
                    if !voucher.codigo.isEmpty {
                        BXBotao("Copiar código", estilo: .secundario, icone: .documento) {
                            BXCopiar.copiar(voucher.codigo, aviso: "Código copiado.", toast: toast)
                        }
                    }
                }
                BXReciboTracejo()
                BXReciboLinha("Benefício", voucher.nomeBeneficio)
                BXReciboLinha("Parceiro", beneficio.daBlaxx ? "BlaXx" : (beneficio.nomeParceiro ?? "Parceiro selecionado"))
                if let e = voucher.expiraEm { BXReciboLinha("Válido até", BXFormato.data(e)) }
                BXReciboLinha("Status", "ativo")
                BXReciboFaixa("Pontos usados", "\(BXFormato.pontos(voucher.pontosGastos)) pts")
                BXReciboNota("Apresente o código ao parceiro conforme as condições do benefício. O voucher fica guardado em Meus resgates.")
                BXReciboVia()
            }
            VStack(spacing: 12) {
                BXBotao("Ver meus resgates") { nav.ir(.resgates(.meusResgates)) }
                BXBotao("Voltar ao catálogo", estilo: .secundario) { nav.ir(.resgates(.catalogo)) }
            }
        }
        .id("concluido")
    }
}
