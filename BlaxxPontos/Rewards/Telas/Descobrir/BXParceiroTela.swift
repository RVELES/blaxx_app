//
//  BXParceiroTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Detalhe do parceiro, igual ao `blaxx/detalhe-parceiro.html` (fotos web 14 e 14b): farelo mono, cartão do
//  parceiro (ícone da categoria, nome que encolhe, "Troque seus pontos." ou "Rede em expansão.", grade
//  De/Para/Disponíveis/A partir de), bilhetes dos benefícios ordenados por pontos (ou bilhete "Sem bilhete"),
//  recibo "FICHA DO PARCEIRO" e a rota "Tenha · Escolha · Confirme · Troque".
//  Diferença honesta do web: o backend não pede senha no resgate de benefício, então a ficha diz
//  "Confirmação · no app" e a escala 03 não fala em senha. Parceiro de exemplo → "não encontrado".
//

import SwiftUI

struct BXParceiroTela: View {
    let id: String

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav

    @State private var carga: BXCarga<BXParceiroDetalhe> = .carregando
    @Namespace private var zoom

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                BXColunaDescobrir {
                    BXFarelo(itens: [("Início", { nav.ir(.inicio) }), ("Parceiros", { nav.ir(.parceiros()) }),
                                     (nomeFarelo, nil)])
                        .padding(.bottom, 20)
                    switch carga {
                    case .ocioso, .carregando:
                        BXEsqueleto(.cartaoEmbarque).padding(.bottom, BXEspaco.secao)
                        VStack(spacing: 12) { BXEsqueleto(.bilhete); BXEsqueleto(.bilhete) }
                    case .erro(let e) where e.tipo == .naoEncontrado:
                        naoEncontrado
                    case .erro(let e):
                        cartaoErro(e)
                    case .vazio:
                        naoEncontrado
                    case .pronto(let d):
                        conteudo(d, proxy: proxy)
                    }
                }
            }
            .modifier(BXAncoraDemo(pronto: carga.valor != nil, proxy: proxy))
        }
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await carregar() }
        .task { if carga.valor == nil { await carregar() } }
        .modifier(BXZoomDestino(id: "parceiro-\(id)"))
        .onAppear { BXZoomDescobrir.ns = zoom }
    }

    private var nomeFarelo: String {
        if let d = carga.valor { return d.parceiro.nome }
        if case .erro = carga { return "Parceiro" }
        return BXCatalogo.parceiro(id: id)?.nome ?? "Carregando…"
    }

    // MARK: - Conteúdo

    @ViewBuilder private func conteudo(_ d: BXParceiroDetalhe, proxy: ScrollViewProxy) -> some View {
        let p = d.parceiro
        let n = d.beneficios.count
        let minimo = d.aPartirDe.map { "\(BXFormato.pontos($0)) pts" }
        let categoria = p.categoria.isEmpty ? "Parceiro" : p.categoria

        BXCartaoEmbarque(topo: ("Cartão do parceiro · BlaXx", "Brasil · 2026")) {
            HStack(spacing: 16) {
                BXIcone(p.icone, tamanho: .livre(lado: 64, raio: BXRaio.md))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categoria").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(categoria).bxFonte(.item).foregroundStyle(BXCor.tinta)
                }
            }
            .accessibilityElement(children: .combine)
            BXTituloCapa(linhas: [p.nome], marcadas: [n > 0 ? "Troque seus pontos." : "Rede em expansão."])
            BXGradeDados([BXDado("De", "Seus pontos"), BXDado("Para", "Benefícios"),
                          BXDado("Disponíveis", n == 0 ? "Nenhum agora" : "\(n) \(n == 1 ? "benefício" : "benefícios")"),
                          BXDado(n > 0 ? "A partir de" : "Resgate", minimo ?? "Indisponível")])
            Text(n > 0
                 ? "Benefícios de \(p.nome) para trocar com seus pontos, conforme a disponibilidade de cada um. Escolha um bilhete para ver as condições."
                 : "\(p.nome) ainda não tem benefício disponível para troca. Os benefícios de cada parceiro dependem da disponibilidade dele.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        } canhoto: {
            BXDadosCanhoto([BXDado("Passageiro", "Você"), BXDado("Destino", p.nome)])
            VStack(spacing: 12) {
                if n > 0 {
                    BXBotao("Ver benefícios", estilo: .cartao) {
                        withAnimation(BXMovimento.ease) { proxy.scrollTo("beneficios", anchor: .top) }
                    }
                } else {
                    BXBotao("Ver todos os resgates", estilo: .cartao) { nav.ir(.resgates(.catalogo)) }
                }
                BXLinkCanhoto(prefixo: "Outros destinos", titulo: "Parceiros") { nav.ir(.parceiros()) }
            }
        }
        .padding(.bottom, BXEspaco.secao)

        BXSecao(rotulo: "Bilhetes · Benefícios do parceiro",
                titulo: n > 0 ? "Troque seus pontos aqui." : "Benefícios do parceiro.",
                link: n > 0 ? ("Todos os resgates", { nav.ir(.resgates(.catalogo)) }) : nil) {
            VStack(spacing: 12) {
                if n > 0 {
                    ForEach(d.beneficios) { b in bilhete(b, parceiro: p) }
                } else {
                    bilheteVazio(p)
                }
            }
        }
        .id("beneficios")

        if n > 0 {
            ficha(p, n: n, minimo: minimo ?? "—")
                .padding(.bottom, BXEspaco.secao)
                .id("ficha")
        }

        BXSecao(rotulo: "Rota · Como usar seus pontos", titulo: "Do saldo ao benefício.") {
            VStack(alignment: .leading, spacing: 16) {
                BXRotaEscalas([
                    BXEscala(id: 1, rotulo: "Escala 01 · Saldo", palavra: "Tenha",
                             texto: BXRecursos.compraNoApp
                                 ? "Compre pontos com cartão ou transferência, ou ganhe em campanhas. A compra é creditada após a confirmação do pagamento."
                                 : "Ganhe pontos em campanhas ou receba de outras contas BlaXx."),
                    BXEscala(id: 2, rotulo: "Escala 02 · Escolher", palavra: "Escolha",
                             texto: "Escolha um benefício. Os pontos de cada um seguem a tabela de resgate publicada na plataforma."),
                    BXEscala(id: 3, rotulo: "Escala 03 · Confirmar", palavra: "Confirme",
                             texto: "O resgate exige conta ativa e e-mail verificado. Você confirma no app antes de trocar."),
                    BXEscala(id: 4, rotulo: "Escala 04 · Trocar", palavra: "Troque",
                             texto: "O pedido é processado em até 1 dia útil, conforme a disponibilidade do parceiro."),
                ])
                Button { nav.abrirSite("regulamento.html") } label: {
                    Text("Fonte: Regulamento, §03 Acúmulo, §05 Resgate e §07 Tabela de resgate.")
                        .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                        .underline(true, color: BXCor.pontilhado)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        }
        .id("rota")
    }

    private func bilhete(_ b: BXBeneficio, parceiro p: BXParceiro) -> some View {
        BXBilhete(canhoto: .icone(b.icone), acao: { nav.ir(.beneficio(id: b.id)) }) {
            HStack(alignment: .firstTextBaseline) {
                Text("BX · \(b.rotuloCategoria)")
                Spacer(minLength: 8)
                Text(b.tag ?? p.nome).lineLimit(1)
            }
            .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(b.nome).bxFonte(.tituloBilhete)
                .fixedSize(horizontal: false, vertical: true)
            if let desc = b.descricaoSegura {
                Text(desc).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(BXFormato.pontos(b.custo)).bxFonte(.pontosBilhete)
                Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(alignment: .top, spacing: 20) {
                if let dias = b.validadeDias, dias > 0 {
                    dado("Validade do voucher", "\(BXFormato.pontos(dias)) \(dias == 1 ? "dia" : "dias")")
                }
                if b.esgotado {
                    dado("Estoque", "Esgotado")
                } else if b.estoque > 0 {
                    dado("Estoque", "\(BXFormato.pontos(b.estoque)) \(b.estoque == 1 ? "restante" : "restantes")")
                }
            }
            Text("Ver benefício →").bxFonte(.corpo)
                .padding(.bottom, 2)
                .overlay(alignment: .bottom) { Rectangle().fill(BXCor.tinta).frame(height: 2) }
        }
        .matchedTransitionSource(id: "beneficio-\(b.id)", in: zoom)
        .accessibilityLabel("\(b.rotuloCategoria). \(b.nome). \(BXFormato.pontosFalados(b.custo))\(b.esgotado ? ". Esgotado" : "")")
        .accessibilityHint("Abre o benefício")
    }

    private func dado(_ r: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(r).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(v).bxFonte(.valorDado)
        }
    }

    private func bilheteVazio(_ p: BXParceiro) -> some View {
        BXBilhete(canhoto: .icone(.relogio)) {
            HStack(alignment: .firstTextBaseline) {
                Text("BX · Sem bilhete")
                Spacer(minLength: 8)
                Text(p.nome).lineLimit(1)
            }
            .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text("Nenhum benefício disponível agora.").bxFonte(.tituloBilhete)
                .fixedSize(horizontal: false, vertical: true)
            Text("Os benefícios de cada parceiro dependem da disponibilidade dele. Enquanto isso, veja os resgates de toda a rede.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                BXLinkSeta("Ver todos os resgates") { nav.ir(.resgates(.catalogo)) }
                BXLinkSeta("Outros parceiros") { nav.ir(.parceiros()) }
            }
            .padding(.top, 4)
        }
    }

    private func ficha(_ p: BXParceiro, n: Int, minimo: String) -> some View {
        BXRecibo(cabeca: "Ficha do parceiro",
                 acao: .init(titulo: "Ver todos os resgates →") { nav.ir(.resgates(.catalogo)) }) {
            BXReciboTracejo()
            BXReciboLinha("Parceiro", p.nome)
            BXReciboLinha("Categoria", p.categoria.isEmpty ? "Parceiro" : p.categoria)
            BXReciboLinha("Benefícios", "\(n)")
            BXReciboLinha("Conta", sessao.logado ? "ativa" : "visitante")
            if sessao.logado {
                BXReciboLinha("E-mail", sessao.emailVerificado ? "verificado" : "não verificado")
            }
            BXReciboLinha("Confirmação", "no app")
            BXReciboTracejo()
            BXReciboTotal("A partir de", minimo)
            BXReciboFaixa("Pedido processado", "até 1 dia útil")
            BXReciboNota("Os pontos de cada benefício seguem a tabela de resgate publicada na plataforma, conforme a disponibilidade do parceiro (Regulamento, §05 e §07).")
            BXReciboVia()
        }
    }

    // MARK: - Estados

    private var naoEncontrado: some View {
        VStack(alignment: .leading, spacing: BXEspaco.secao) {
            BXCartaoEmbarque(topo: ("Cartão do parceiro · BlaXx", "Não encontrado")) {
                HStack(spacing: 16) {
                    BXIcone(.parceiros, tamanho: .livre(lado: 64, raio: BXRaio.md))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parceiro").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        Text("Não encontrado").bxFonte(.item)
                    }
                }
                BXTituloCapa(linhas: ["Parceiro não encontrado."], marcadas: ["Escolha outro destino."])
                Text("Este parceiro não está na rede ou o endereço mudou. A lista completa está em Parceiros.")
                    .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            } canhoto: {
                BXBotao("Ver todos os parceiros", estilo: .cartao) { nav.ir(.parceiros()) }
                BXLinkCanhoto(prefixo: "Rede em expansão", titulo: "Parceiros") { nav.ir(.parceiros()) }
            }
        }
    }

    private func cartaoErro(_ e: BXErro) -> some View {
        let semRede = e.tipo == .semConexao || e.tipo == .tempoEsgotado
        return BXCartaoEmbarque(topo: ("Cartão do parceiro · BlaXx", semRede ? "Sem conexão" : "Sem resposta")) {
            BXTituloCapa(linhas: ["Não deu para carregar."], marcadas: ["Tente de novo."])
            Text(semRede
                 ? "A conexão com a BlaXx falhou antes de trazer este parceiro. Verifique a internet e tente de novo."
                 : "A BlaXx não conseguiu trazer este parceiro agora. Tente de novo em instantes.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        } canhoto: {
            BXBotao("Tentar de novo", estilo: .cartao) { Task { carga = .carregando; await carregar() } }
            BXLinkCanhoto(prefixo: "Rede em expansão", titulo: "Parceiros") { nav.ir(.parceiros()) }
        }
    }

    private func carregar() async {
        do {
            carga = .pronto(try await BXAPI.shared.parceiro(id: id))
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if case .pronto = carga { return }
            carga = .erro(BXErro.de(error))
        }
    }
}
