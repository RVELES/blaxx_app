//
//  BXBoasVindasTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Boas-vindas do visitante (home-embarque.html, fotos web 01-01…10), na mesma ordem do web:
//  barra utilitária · cartão de embarque (letreiro, grade, canhoto, "Começar agora" / "Já tenho conta · Entrar") ·
//  rota "Como funciona" (4 escalas) · "Escolha o seu ponto de partida." com os pacotes da API em bilhetes +
//  recibo "EXTRATO DA SUA COMPRA" · painel de partidas com quadro preto · convite "Criar conta" ·
//  rodapé-recibo.
//  Diferenças de propósito: os 4 pacotes de GET /pix/packages (o web mostra 3), sem linha "Bônus" nem percentual
//  (D07); erro de pacotes vira estado de erro com "Tentar de novo" (nunca lista vazia muda nem número de exemplo).
//  Âncoras (`-BXAncora`): topo, rota, pacotes, recibo, painel, convite, rodape.
//

import SwiftUI

struct BXBoasVindasTela: View {
    @Environment(BXNavegacao.self) private var nav
    @Environment(BXFluxoAcesso.self) private var fluxo
    @Environment(\.accessibilityReduceMotion) private var reduzido
    @Environment(\.dynamicTypeSize) private var dts

    @State private var pacotes: BXCarga<[BXPacote]> = .carregando
    @State private var escolhido: String = "plus"
    @State private var cidade: String?

    var body: some View {
        ScrollViewReader { leitor in
            ScrollView {
                VStack(spacing: 0) {
                    BXBarraUtilitaria()
                        .id("topo")
                    VStack(alignment: .leading, spacing: 0) {
                        cartaoEmbarque
                            .padding(.top, 16)
                            .padding(.bottom, BXEspaco.secao)
                        rota
                            .id("rota")
                        if BXRecursos.compraNoApp {
                            secaoPacotes
                                .id("pacotes")
                        }
                        painel
                            .id("painel")
                            .padding(.bottom, BXEspaco.secao)
                        convite
                            .id("convite")
                    }
                    .padding(.horizontal, BXEspaco.margem)
                    .frame(maxWidth: BXEspaco.colunaMax)
                    .frame(maxWidth: .infinity)
                    // O fundo dividido (chão em cima, tinta embaixo) fica fixo na tela e só
                    // deve aparecer no repuxo da rolagem; sem este chão próprio, o conteúdo
                    // que passava pela metade de baixo ficava tinta sobre tinta, ilegível.
                    .background(BXCor.chao)
                    BXRodapeRecibo()
                        .id("rodape")
                }
            }
            .background {
                VStack(spacing: 0) { BXCor.chao; BXCor.tinta }.ignoresSafeArea()
            }
            .refreshable { if BXRecursos.compraNoApp { await carregarPacotes() } }
            .task {
                guard BXRecursos.compraNoApp else { return }
                if case .pronto = pacotes { return }
                await carregarPacotes()
                if let a = BXDemo.ancora {
                    try? await Task.sleep(for: .milliseconds(150))
                    leitor.scrollTo(a, anchor: .top)
                }
            }
            .onChange(of: fluxo.rolarBoasVindasPara) { _, alvo in
                guard let alvo else { return }
                withAnimation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzido)) { leitor.scrollTo(alvo, anchor: .top) }
                fluxo.rolarBoasVindasPara = nil
            }
            .onAppear {
                if let alvo = fluxo.rolarBoasVindasPara {
                    leitor.scrollTo(alvo, anchor: .top)
                    fluxo.rolarBoasVindasPara = nil
                }
            }
        }
    }

    // MARK: - Cartão de embarque

    private var cartaoEmbarque: some View {
        BXCartaoEmbarque(topo: ("Cartão de embarque · BlaXx Pontos", "Brasil · 2026")) {
            BXTituloCapa(linhas: ["Seus pontos."],
                         marcadas: [BXRecursos.compraNoApp ? "Compre. Ganhe." : "Ganhe. Receba.", "Envie. Troque."],
                         letreiro: ["Novos destinos.", "Novos sonhos.", "Novas aventuras."],
                         intervaloLetreiro: BXDemo.congelar ? 100_000 : 2.6)
            BXGradeDados(BXRecursos.compraNoApp
                         ? [BXDado("De", "Pontos"), BXDado("Para", "Benefícios"),
                            BXDado("Pagamento", "Cartão ou transferência"), BXDado("Mensalidade", "Nenhuma")]
                         : [BXDado("De", "Pontos"), BXDado("Para", "Benefícios"),
                            BXDado("Cadastro", "Gratuito"), BXDado("Mensalidade", "Nenhuma")])
            Text(BXRecursos.compraNoApp
                 ? "Compre pontos, envie para quem você quiser e troque por benefícios em parceiros selecionados. O que você vê é o que você paga."
                 : "Junte pontos, envie para quem você quiser e troque por benefícios. Sem mensalidade.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        } canhoto: {
            BXDadosCanhoto([BXDado("Passageiro", "Você"), BXDado("Portão", "Cadastro"), BXDado("Assento", "Livre")])
            VStack(spacing: 12) {
                BXBotao("Começar agora", estilo: .cartao) { nav.ir(.cadastro) }
                BXLinkCanhoto(prefixo: "Já tenho conta", titulo: "Entrar") { nav.ir(.entrar) }
            }
        }
    }

    // MARK: - Rota

    private var rota: some View {
        BXSecao(rotulo: "Rota · Como funciona") {
            BXRotaEscalas(BXRecursos.compraNoApp ? [
                BXEscala(id: 1, rotulo: "Escala 01 · Comprar", palavra: "Compre",
                         texto: "Pacotes ou valor livre. Pagamento com cartão ou transferência."),
                BXEscala(id: 2, rotulo: "Escala 02 · Ganhar", palavra: "Ganhe",
                         texto: "Bônus nos pacotes maiores e pontos extras nas campanhas."),
                BXEscala(id: 3, rotulo: "Escala 03 · Enviar", palavra: "Envie",
                         texto: "Mande pontos para quem você quiser, entre contas BlaXx."),
                BXEscala(id: 4, rotulo: "Escala 04 · Trocar", palavra: "Troque",
                         texto: "Benefícios e experiências em parceiros selecionados.")
            ] : [
                BXEscala(id: 1, rotulo: "Escala 01 · Ganhar", palavra: "Ganhe",
                         texto: "Pontos em ações da BlaXx ou enviados por outras contas BlaXx."),
                BXEscala(id: 2, rotulo: "Escala 02 · Enviar", palavra: "Envie",
                         texto: "Mande pontos para quem você quiser, entre contas BlaXx."),
                BXEscala(id: 3, rotulo: "Escala 03 · Trocar", palavra: "Troque",
                         texto: "Benefícios e experiências da BlaXx e da rede em expansão.")
            ])
        }
    }

    // MARK: - Pacotes + recibo

    private var secaoPacotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Escolha o seu ponto de partida.").bxFonte(.tituloSecao).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                BXLinkSeta("Valor livre") { nav.pedirEntrada(depois: .comprar(pacote: nil)) }
            }
            .padding(.bottom, 10)

            BXConteudo(pacotes,
                       vazio: BXEstadoVazio(icone: .comprar, titulo: "Nenhum pacote disponível agora.",
                                            texto: "Tente de novo em alguns minutos."),
                       tentarDeNovo: { await carregarPacotes() }) {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in BXEsqueleto(.bilhete) }
                    BXEsqueleto(.bloco(altura: 420))
                }
            } pronto: { lista in
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lista) { p in
                        BXBilhetePacote(pacote: p, selecionado: p.chave == escolhido) {
                            withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido)) { escolhido = p.chave }
                        }
                    }
                    if let p = lista.first(where: { $0.chave == escolhido }) ?? lista.first {
                        recibo(p)
                            .padding(.top, 16)
                            .id("recibo")
                    }
                }
                .sensoryFeedback(.selection, trigger: escolhido)
            }
        }
        .padding(.bottom, BXEspaco.secao)
    }

    private func recibo(_ p: BXPacote) -> some View {
        BXRecibo(cabeca: "Extrato da sua compra",
                 acao: .init(titulo: "Comprar \(BXFormato.pontos(p.pontos)) pts →") {
                     nav.pedirEntrada(depois: .comprar(pacote: p.chave))
                 }) {
            BXReciboTracejo()
            BXReciboLinha("Pacote", p.rotulo)
            BXReciboLinha("Pontos", BXFormato.pontos(p.pontos))
            BXReciboLinha("Pagamento", "cartão ou transferência")
            BXReciboLinha("Mensalidade", "nenhuma")
            BXReciboTracejo()
            BXReciboTotal("Total", BXFormato.dinheiro(p.preco))
            BXReciboFaixa("Pontos na conta", BXFormato.pontos(p.pontos))
            BXReciboNota("Os pontos do pacote já incluem o bônus. Pontos são créditos promocionais de uso restrito na plataforma.")
            BXReciboVia()
        }
        .contentTransition(.numericText())
        .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido), value: p.chave)
    }

    private func carregarPacotes() async {
        do {
            let lista = try await BXAPI.shared.pacotes()
            pacotes = lista.isEmpty ? .vazio : .pronto(lista)
            if !lista.contains(where: { $0.chave == escolhido }), let meio = lista.dropFirst().first ?? lista.first {
                escolhido = meio.chave
            }
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = pacotes { return }      // recarga falhou: mantém o que já tinha
            pacotes = .erro(BXErro.de(error))
        }
    }

    // MARK: - Painel de partidas

    private var painel: some View {
        BXPainel(rotulo: "Painel de partidas · Mapa", titulo: "Seus pontos, o mundo inteiro.") {
            VStack(alignment: .leading, spacing: 14) {
                BXNumeroDestaque("\(BXPainelPartidasDados.cidades.count)", legenda: "cidades no mapa")
                FlowLegenda {
                    ForEach(BXPainelPartidasDados.verticaisPresentes, id: \.self) { v in
                        BXLegendaCor(v.cor, v.nome)
                    }
                    BXLegendaCor(BXCor.tinta, "Rede em expansão")
                }
            }
            BXTracejado(cor: BXCor.linha)
            BXQuadroPreto(linhas: BXPainelPartidasDados.cidades.map(\.linha), selecionada: $cidade) { l in
                if let c = BXPainelPartidasDados.cidade(id: l?.id) {
                    if c.ativa {
                        BXQuadroInfo(titulo: "\(c.nome) · \(c.pais)",
                                     texto: "Rede em implantação: \(c.verticais.map(\.nome).joined(separator: ", ")).",
                                     link: (titulo: "Ver parceiros", acao: {
                                         nav.ir(.parceiros(busca: c.verticais.first?.busca))
                                     }))
                    } else {
                        BXQuadroInfo(titulo: "\(c.nome) · \(c.pais)",
                                     texto: "Rede em expansão: ainda não há parceiros nesta cidade.")
                    }
                } else {
                    BXQuadroInfo(titulo: "Escolha uma cidade",
                                 texto: "Toque numa cidade da lista para ver os serviços disponíveis.")
                }
            }
            .sensoryFeedback(.selection, trigger: cidade)
        }
    }

    // MARK: - Convite

    private var convite: some View {
        BXSecao(rotulo: "Criar conta · Sem mensalidade", titulo: "Inicie sua aventura com a BlaXx.") {
            VStack(alignment: .leading, spacing: 12) {
                Text(BXRecursos.compraNoApp
                     ? "Abra sua conta em poucos minutos e comece a comprar, enviar e trocar pontos."
                     : "Abra sua conta em poucos minutos e comece a juntar, enviar e trocar pontos.")
                    .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -8)
                    .padding(.bottom, 8)
                LazyVGrid(columns: colunasConvite, alignment: .leading, spacing: 12) {
                    BXCartaoClaro(icone: .usuarioMais, titulo: "Cadastro em minutos",
                                  texto: BXRecursos.loginGoogle
                                      ? "Crie sua conta com e-mail ou com o Google. O cadastro é gratuito."
                                      : "Crie sua conta com seu e-mail. O cadastro é gratuito.",
                                  tamanhoIcone: .padrao)
                    BXCartaoClaro(icone: .semMensalidade, titulo: "Sem mensalidade",
                                  texto: "Nenhum valor fixo por mês para manter a conta.",
                                  tamanhoIcone: .padrao)
                    BXCartaoClaro(icone: .enviar, titulo: "Envie para quem quiser",
                                  texto: "Mande pontos para outras contas BlaXx, com registro no extrato.",
                                  tamanhoIcone: .padrao)
                    BXCartaoClaro(icone: .resgates, titulo: "Troque por benefícios",
                                  texto: "Benefícios e experiências em parceiros selecionados.",
                                  tamanhoIcone: .padrao)
                }
                prontoParaEmbarcar
                    .padding(.top, 4)
            }
        }
    }

    private var colunasConvite: [GridItem] {
        dts.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 260), spacing: 12, alignment: .top)]
    }

    private var prontoParaEmbarcar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pronto para embarcar?").bxFonte(.tituloConvite).foregroundStyle(BXCor.papel)
                .accessibilityAddTraits(.isHeader)
            Text("Sua conta BlaXx fica pronta em poucos minutos.").bxFonte(.corpo).foregroundStyle(BXCor.tintaApagada)
                .fixedSize(horizontal: false, vertical: true)
            BXBotao("Criar conta →") { nav.ir(.cadastro) }
            Button { nav.ir(.entrar) } label: {
                Text("Já tenho conta · Entrar").bxFonte(.botao).foregroundStyle(BXCor.papel)
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
    }
}

/// Legenda que quebra linha (Postos · Supermercados · Rede em expansão).
private struct FlowLegenda<Conteudo: View>: View {
    let conteudo: Conteudo
    init(@ViewBuilder conteudo: () -> Conteudo) { self.conteudo = conteudo() }
    var body: some View {
        BXFluxoLinhas(espaco: 16, entreLinhas: 8) { conteudo }
    }
}

/// Layout simples que quebra os itens em linhas.
nonisolated struct BXFluxoLinhas: Layout {
    var espaco: CGFloat = 12
    var entreLinhas: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaLinha: CGFloat = 0, maior: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > 0, x + t.width > largura { x = 0; y += alturaLinha + entreLinhas; alturaLinha = 0 }
            x += t.width + espaco
            maior = max(maior, x - espaco)
            alturaLinha = max(alturaLinha, t.height)
        }
        return CGSize(width: min(maior, largura), height: y + alturaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaLinha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x + t.width > bounds.maxX { x = bounds.minX; y += alturaLinha + entreLinhas; alturaLinha = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espaco
            alturaLinha = max(alturaLinha, t.height)
        }
    }
}
