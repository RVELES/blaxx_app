//
//  BXInicioTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G2 (Saldo)
//
//  Início = painel do web no celular (dashboard.html, fotos 10-01…07), sem o que lá é inventado:
//  saudação · faixa de e-mail · cartão de embarque do SALDO EM PONTOS (nunca R$) com nível real de /card/
//  · atalhos · campanhas (D04: só quando `BXRecursos.campanhas`) · últimas movimentações em recibo ·
//  resgates populares (só se a API marcar) · parceiros por categoria · rodapé-recibo.
//  Nada de "Plano Plus/Prime", meta 100.000, "+20 % de bônus", "Próx. expirar" ou campanhas fixas.
//
//  Âncoras de demonstração (-BXAncora): atalhos, campanhas, movimentacoes, populares, categorias.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BXInicioTela: View {
    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.dynamicTypeSize) private var dts
    @Environment(\.accessibilityReduceMotion) private var reduzido

    @State private var cartao: BXCarga<BXCartaoEstado> = .carregando
    @State private var recentes: BXCarga<[BXLancamento]> = .carregando
    @State private var campanhas: BXCarga<[BXCampanha]> = .carregando
    @State private var populares: [BXBeneficio] = []
    @State private var detalhe: BXLancamento?
    @State private var carregouUmaVez = false

    var body: some View {
        BXPaginaSaldo(aba: .inicio, atualizar: { await carregar(recarregarSaldo: true) }) {
            saudacao
            if sessao.usuario != nil && !sessao.emailVerificado {
                faixaEmail
                    .padding(.top, 18)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            }
            cartaoSaldo.padding(.top, 24)
            if sessao.carteira == nil, let e = sessao.erroCarteira {
                BXEstadoErro(e) { await sessao.recarregarCarteira() }
                    .padding(.top, 16)
            }
            atalhos.padding(.top, BXEspaco.secao).id("atalhos")
            if BXRecursos.campanhas {
                secaoCampanhas.id("campanhas")
            }
            secaoMovimentacoes.id("movimentacoes")
            if !populares.isEmpty {
                secaoPopulares.id("populares")
            }
            secaoCategorias.id("categorias")
        } rodape: {
            BXRodapeRecibo()
        }
        .animation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzido), value: sessao.emailVerificado)
        .bxSheetLancamento($detalhe) { await carregar(recarregarSaldo: false) }
        .task {
            guard !carregouUmaVez else { return }
            carregouUmaVez = true
            await carregar(recarregarSaldo: false)
            #if DEBUG
            if BXDemo.subtela == "lancamento", let l = recentes.valor?.first { detalhe = l }
            #endif
        }
    }

    // MARK: - Carga

    private func carregar(recarregarSaldo: Bool) async {
        async let s: Void = recarregarSaldo ? sessao.recarregarCarteira() : ()
        async let c: Void = carregarCartao()
        async let r: Void = carregarRecentes()
        async let k: Void = carregarCampanhas()
        async let p: Void = carregarPopulares()
        _ = await (s, c, r, k, p)
    }

    private func carregarCartao() async {
        do { cartao = .pronto(try await BXAPI.shared.cartao()) } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            cartao = .erro(BXErro.de(error))
        }
    }

    private func carregarRecentes() async {
        do {
            let itens = try await BXAPI.shared.lancamentos(limite: 5)
            recentes = itens.isEmpty ? .vazio : .pronto(Array(itens.sorted { $0.criadoEm > $1.criadoEm }.prefix(5)))
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            recentes = .erro(BXErro.de(error))
        }
    }

    private func carregarCampanhas() async {
        guard BXRecursos.campanhas else { return }
        do {
            let ativas = try await BXAPI.shared.campanhas().filter { !$0.concluida }
            campanhas = ativas.isEmpty ? .vazio : .pronto(ativas)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            campanhas = .erro(BXErro.de(error))
        }
    }

    /// Só o que a API marca como popular; sem marca ou com erro, a seção não aparece (nada inventado).
    private func carregarPopulares() async {
        guard let lista = try? await BXAPI.shared.beneficios() else { return }
        populares = Array(lista.filter { ($0.tag ?? "").lowercased().contains("popular") && !$0.esgotado }.prefix(3))
    }

    // MARK: - Saudação

    private var saudacao: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXChip(sessao.usuario?.primeiroNome.map { "Olá, \($0)" } ?? "Olá", .saudacao)
            Text("Bom te ver de volta.")
                .bxFonte(.tituloPagina)
                .foregroundStyle(BXCor.tinta)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var faixaEmail: some View {
        Button { nav.exigirVerificacaoEmail() } label: {
            HStack(spacing: 12) {
                BXIcone(.email, tamanho: .atalho)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirme seu e-mail para enviar e resgatar pontos")
                        .bxFonte(.botao).foregroundStyle(BXCor.avisoTexto)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Toque para receber o código.").bxFonte(.legenda).foregroundStyle(BXCor.avisoTexto)
                }
                Spacer(minLength: 0)
                Text("→").bxFonte(.botao).foregroundStyle(BXCor.avisoTexto)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BXCor.avisoFundo, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre a verificação de e-mail")
    }

    // MARK: - Cartão de embarque do saldo

    private var cartaoEstado: BXCartaoEstado? { cartao.valor }

    private var cartaoSaldo: some View {
        let numero = sessao.cartaoID.map(BXFormato.cartao) ?? cartaoEstado?.cartaoFormatado
        let topoEsq = "Cartão BlaXx" + (numero.map { " · \($0)" } ?? "")
        let topoDir = cartaoEstado?.nivel.map { "Nível \($0.nome)" } ?? "Nível —"
        return BXCartaoEmbarque(topo: (topoEsq, topoDir)) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    BXRotulo("Saldo de pontos")
                    if sessao.carteiraDoCache {
                        BXStatus("Saldo do último acesso", .info, ponto: false)
                    }
                }
                BXNumeroAnimado(sessao.carteira?.saldo, estilo: .numeroGrande, sufixo: "pontos",
                                contarNaEntrada: !sessao.carteiraDoCache, corSufixo: BXCor.cinza)
                    .foregroundStyle(BXCor.tinta)
            }
            .accessibilityElement(children: .combine)
            BXGradeDados([
                BXDado("Em processamento", emProcessamento),
                BXDado("Nível", BXTextoNivel.nome(cartaoEstado)),
                BXDado("Próximo nível", cartaoEstado.map { $0.proximoNivel?.nome ?? "Nível máximo" } ?? "—"),
                BXDado("Progresso", BXTextoNivel.progresso(cartaoEstado)),
            ])
            if let c = cartaoEstado {
                VStack(alignment: .leading, spacing: 8) {
                    BXProgresso(fracao: c.fracaoProgresso, altura: 10)
                    if let f = BXTextoNivel.faltam(c) {
                        Text(f).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                    }
                }
            } else if case .erro = cartao {
                Text("Nível indisponível agora.").bxFonte(.legenda).foregroundStyle(BXCor.cinza)
            }
        } canhoto: {
            BXDadosCanhoto([
                BXDado("Passageiro", sessao.usuario?.primeiroNome ?? "Você"),
                BXDado("Destino", "Benefícios"),
            ])
            VStack(spacing: 10) {
                if BXRecursos.compraNoApp { BXBotao("+ Comprar pontos", estilo: .cartao) { nav.ir(.comprar()) } }
                let botoes = dts.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                botoes {
                    BXBotao("Enviar pontos", estilo: .secundario) { nav.ir(.enviar()) }
                    BXBotao("Resgatar →", estilo: .secundario) { nav.ir(.resgates(.catalogo)) }
                }
            }
        }
        .contextMenu {
            if let id = sessao.cartaoID {
                Button("Copiar número do Cartão BlaXx") { BXCopiaSilenciosa.copiar(BXFormato.cartao(id)) }
            }
        }
    }

    private var emProcessamento: String {
        guard let c = sessao.carteira else { return "—" }
        return c.emProcessamento > 0 ? BXFormato.pontosComUnidade(c.emProcessamento) : "Nada pendente"
    }

    // MARK: - Atalhos

    private var atalhos: some View {
        BXSecao(rotulo: "Atalhos") {
            let colunas = dts.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: BXEspaco.grade), GridItem(.flexible(), spacing: BXEspaco.grade)]
            LazyVGrid(columns: colunas, alignment: .leading, spacing: BXEspaco.grade) {
                BXCartaoClaro(icone: .extrato, titulo: "Extrato", texto: "Veja todos os movimentos.") { nav.ir(.extrato()) }
                BXCartaoClaro(icone: .enviar, titulo: "Enviar pontos", texto: "Para quem você quiser, entre contas BlaXx.") { nav.ir(.enviar()) }
                BXCartaoClaro(icone: .receber, titulo: "Receber pontos", texto: "Mostre o seu Cartão BlaXx.") { nav.ir(.receber) }
                BXCartaoClaro(icone: .voucher, titulo: "Meus resgates", texto: "Seus vouchers e códigos.") { nav.ir(.resgates(.meusResgates)) }
            }
        }
    }

    // MARK: - Campanhas (D04)

    private var secaoCampanhas: some View {
        BXSecao(rotulo: "Campanhas ativas", titulo: "Metas que valem pontos.", link: ("Ver todas", { nav.ir(.campanhas) })) {
            switch campanhas {
            case .ocioso, .carregando:
                BXEsqueleto(.bilhete)
            case .vazio:
                BXEstadoVazio(icone: .campanhas, titulo: "Nenhuma campanha ativa no momento.")
            case .erro(let e):
                BXEstadoErro(e) { await carregarCampanhas() }
            case .pronto(let lista):
                ScrollView(.horizontal) {
                    LazyHStack(spacing: BXEspaco.grade) {
                        ForEach(Array(lista.enumerated()), id: \.element.id) { i, c in
                            BXBilheteCampanha(campanha: c, indice: i + 1, total: lista.count) { nav.ir(.campanhas) }
                                .containerRelativeFrame(.horizontal) { w, _ in lista.count > 1 ? w * 0.88 : w }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 6)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Últimas movimentações

    private var secaoMovimentacoes: some View {
        BXSecao(rotulo: "Últimas movimentações", titulo: "Extrato recente.") {
            VStack(alignment: .leading, spacing: 18) {
                switch recentes {
                case .ocioso, .carregando:
                    VStack(spacing: 0) { ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.linhaExtrato) } }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
                case .vazio:
                    BXEstadoVazio(icone: .extrato, titulo: "Nenhuma movimentação ainda.",
                                  texto: BXRecursos.compraNoApp
                                      ? "Compre pontos ou peça para alguém enviar para o seu Cartão BlaXx."
                                      : "Peça para alguém enviar pontos para o seu Cartão BlaXx.",
                                  acao: BXRecursos.compraNoApp
                                      ? (titulo: "Comprar pontos", executar: { nav.ir(.comprar()) })
                                      : (titulo: "Receber pontos", executar: { nav.ir(.receber) }))
                case .erro(let e):
                    BXEstadoErro(e) { await carregarRecentes() }
                case .pronto(let itens):
                    BXRecibo(cabeca: "Extrato recente") {
                        ForEach(Array(itens.enumerated()), id: \.element.id) { i, l in
                            Button { detalhe = l } label: { linhaRecibo(l) }
                                .buttonStyle(BXEstiloPressao())
                            if i < itens.count - 1 { BXTracejado(cor: BXCor.linha) }
                        }
                    }
                }
                BXLinkSeta("Ver extrato completo") { nav.ir(.extrato()) }
            }
        }
    }

    private func linhaRecibo(_ l: BXLancamento) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(BXFormato.dataHora(l.criadoEm)).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                HStack(spacing: 6) {
                    Text(l.rotulo).bxFonte(.recibo).foregroundStyle(BXCor.tinta)
                    if l.status == .pendente { BXStatus("Em processamento", .aviso, ponto: false) }
                }
            }
            Spacer(minLength: 8)
            Text(BXFormato.pontosSinal(l.pontos))
                .font(BXFonte.fonte(.recibo, tamanho: 15).weight(.bold))
                .foregroundStyle(l.ehEntrada ? BXCor.okTexto : BXCor.perigoTexto)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BXLinhaLancamento.falado(l, comData: true))
        .accessibilityHint("Abre o comprovante")
    }

    // MARK: - Resgates populares (só da API)

    private var secaoPopulares: some View {
        BXSecao(rotulo: "Resgates populares", titulo: "Benefícios em parceiros selecionados.",
                link: ("Ver todos", { nav.ir(.resgates(.catalogo)) })) {
            VStack(spacing: BXEspaco.grade) {
                ForEach(populares) { b in
                    BXBilhete(canhoto: .icone(b.icone), acao: { nav.ir(.beneficio(id: b.id)) }) {
                        Text("BX · \(b.rotuloCategoria)").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        Text(b.nome).bxFonte(.tituloBilhete).foregroundStyle(BXCor.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                        if let p = b.nomeParceiro, !b.daBlaxx {
                            Text(p).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(BXFormato.pontos(b.custo)).bxFonte(.pontosBilhete)
                            Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
                        }
                    }
                    .accessibilityLabel("\(b.nome), \(BXFormato.pontosFalados(b.custo))")
                }
            }
        }
    }

    // MARK: - Parceiros por categoria

    private var secaoCategorias: some View {
        BXSecao(rotulo: "Parceiros por categoria", titulo: "Rede em expansão.",
                link: ("Ver todos", { nav.ir(.parceiros()) })) {
            VStack(spacing: BXEspaco.grade) {
                linhaCategoria(.supermercado, "Supermercados", "Compras do dia a dia")
                linhaCategoria(.posto, "Postos", "Combustível e conveniência")
                linhaCategoria(.farmacia, "Farmácias", "Saúde e bem-estar")
            }
        }
    }

    private func linhaCategoria(_ icone: BXIconeNome, _ titulo: String, _ texto: String) -> some View {
        Button { nav.ir(.parceiros(busca: titulo)) } label: {
            HStack(spacing: 14) {
                BXIcone(icone, tamanho: .cartao)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo).bxFonte(.nomeParceiro).foregroundStyle(BXCor.tinta)
                    Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                }
                Spacer(minLength: 0)
                Text("→").bxFonte(.botao).foregroundStyle(BXCor.tinta)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 69, alignment: .leading)
            .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Mostra os parceiros desta categoria")
    }
}

/// Copiar sem toast (menu de contexto: o sistema já dá retorno visual).
enum BXCopiaSilenciosa {
    static func copiar(_ s: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = s
        #endif
        BXHaptica.tocar(.leve)
    }
}
