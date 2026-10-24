//
//  BXParceirosTela.swift
//  BlaxxPontos · Redesenho "Embarque" · G4 (Descobrir e resgatar)
//
//  Parceiros, igual ao `blaxx/parceiros.html` (fotos web 13-01…09): cartão de embarque com a busca e o
//  botão de favoritos, canhoto de visitante ou de quem entrou (saldo, nível e progresso reais), lista
//  completa com pílulas de categoria canônica, aviso de cidade ("rede em expansão"), cartões com o ícone
//  da categoria e o coração no canhoto, carga contínua de 20 em 20, campanhas (D04) + recibo "RESUMO DA
//  LISTA" e a rota "Busque · Filtre · Favorite · Confira".
//  Nunca mostra `description`, `accrual_rule` nem `logo_emoji` (o DTO nem decodifica os dois últimos).
//

import SwiftUI

/// Filtro ativo da lista.
private enum BXFiltroParceiros: Hashable {
    case todos, favoritos
    case categoria(String)
}

/// Namespace compartilhado para o zoom cartão → detalhe (a casca monta o destino; a tela de origem
/// guarda aqui o namespace para o destino aplicar `.navigationTransition(.zoom…)`).
@MainActor enum BXZoomDescobrir {
    static var ns: Namespace.ID?
}

struct BXZoomDestino: ViewModifier {
    let id: String
    @Environment(\.accessibilityReduceMotion) private var reduzir
    /// Namespace da tela de origem, capturado UMA vez (a própria tela depois guarda o seu para os filhos).
    @State private var ns: Namespace.ID? = BXZoomDescobrir.ns
    func body(content: Content) -> some View {
        if let ns, !reduzir {
            content.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            content
        }
    }
}

struct BXParceirosTela: View {
    let buscaInicial: String?

    @Environment(BXSessao.self) private var sessao
    @Environment(BXNavegacao.self) private var nav
    @Environment(\.accessibilityReduceMotion) private var reduzir
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    @State private var carga: BXCarga<[BXParceiro]> = .carregando
    @State private var cartao: BXCartaoEstado?
    @State private var cartaoFalhou = false
    @State private var campanhas: BXCarga<[BXCampanha]> = .carregando
    @State private var busca = ""
    @State private var buscaEfetiva = ""
    @State private var filtro: BXFiltroParceiros = .todos
    @State private var limite = 20
    @State private var maisCategorias = false
    @State private var slide = 0
    @Namespace private var pilulas
    @Namespace private var zoom

    private var favoritos: BXFavoritos { BXFavoritos.shared }

    init(busca: String?) { self.buscaInicial = busca }

    // MARK: - Dados

    private var todos: [BXParceiro] { carga.valor ?? [] }

    /// Categorias canônicas presentes na lista, com a contagem.
    private var categorias: [(nome: String, n: Int)] {
        var c: [String: Int] = [:]
        for p in todos { c[p.categoriaCanonica, default: 0] += 1 }
        return c.map { ($0.key, $0.value) }.sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
    }

    private var principais: [String] { BXSanitizador.categoriasPrincipais }
    private var outrasCategorias: [(nome: String, n: Int)] { categorias.filter { !principais.contains($0.nome) } }

    private var cidade: String? { BXSanitizador.cidade(daBusca: buscaEfetiva) }

    private var filtrados: [BXParceiro] {
        var lista = todos
        switch filtro {
        case .todos: break
        case .favoritos: lista = lista.filter { favoritos.contem($0.id) }
        case .categoria(let c): lista = lista.filter { $0.categoriaCanonica == c }
        }
        let q = BXSanitizador.normalizar(buscaEfetiva)
        // Cidade na busca: a lista ainda não separa parceiros por cidade; mostra todos e avisa.
        if !q.isEmpty && cidade == nil {
            lista = lista.filter { $0.textoBusca.contains(q) }
        }
        return lista
    }

    private var textoStatus: String {
        guard case .pronto = carga else { return "" }
        let n = filtrados.count
        var t: String
        switch filtro {
        case .favoritos: t = "\(BXFormato.pontos(n)) favorito\(n == 1 ? "" : "s")"
        case .categoria(let c): t = "\(c) · \(BXFormato.pontos(n)) parceiro\(n == 1 ? "" : "s")"
        case .todos: t = "\(BXFormato.pontos(n)) parceiro\(n == 1 ? "" : "s")"
        }
        let q = buscaEfetiva.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty && cidade == nil { t += " · busca “\(q)”" }
        if n > limite { t += " · mostrando \(BXFormato.pontos(limite))" }
        return t
    }

    private var campanhasAtivas: [BXCampanha] { (campanhas.valor ?? []).filter { !$0.concluida } }

    // MARK: - Corpo

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                BXColunaDescobrir {
                    cartaoTopo
                        .padding(.bottom, BXEspaco.secao)
                    secaoLista.id("lista")
                    if BXRecursos.campanhas {
                        secaoCampanhas.id("campanhas")
                    } else {
                        reciboResumo.padding(.bottom, BXEspaco.secao).id("campanhas")
                    }
                    secaoRota.id("rota")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(BXAncoraDemo(pronto: carga.valor != nil, proxy: proxy))
        }
        .background(BXCor.chao, in: Rectangle())
        .refreshable { await carregar(recarga: true) }
        .task { await primeiraCarga() }
        .task(id: busca) {
            if busca.isEmpty { buscaEfetiva = ""; return }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            buscaEfetiva = busca
            limite = 20
        }
        .onChange(of: filtro) { _, _ in limite = 20 }
        .sheet(isPresented: $maisCategorias) { folhaCategorias }
        .onAppear { BXZoomDescobrir.ns = zoom }
    }

    // MARK: - Cartão de embarque

    private var cartaoTopo: some View {
        BXCartaoEmbarque(topo: ("Painel de partidas · Parceiros", "Rede em expansão · 2026")) {
            BXTituloCapa(linhas: ["Parceiros", "BlaXx."], marcadas: ["Escolha o seu destino."])
            VStack(alignment: .leading, spacing: 12) {
                Rectangle().fill(BXCor.linha).frame(height: 1).padding(.bottom, 8)
                BXRotulo("Destino · nome da marca ou categoria")
                BXCampoBusca(texto: $busca, placeholder: "Buscar parceiro ou loja")
                botaoFavoritos
            }
            Text("Busque pela marca ou pela categoria e abra o parceiro para ver os detalhes. A rede está em expansão: novos parceiros entram aos poucos.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        } canhoto: {
            if sessao.logado { canhotoLogado } else { canhotoVisitante }
        }
    }

    private var botaoFavoritos: some View {
        let ativo = filtro == .favoritos
        let n = favoritos.contagem(em: todos)
        let forma = RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous)
        return Button {
            withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) { filtro = ativo ? .todos : .favoritos }
        } label: {
            HStack(spacing: 10) {
                BXIcone(.favorito, tamanho: .cartao, preenchido: ativo)
                Text("Meus favoritos").bxFonte(.item)
                Text("\(n)").font(BXFonte.fonte(.recibo, tamanho: 12))
                    .foregroundStyle(ativo ? BXCor.tintaApagada : BXCor.cinza)
                    .contentTransition(.numericText(value: Double(n)))
                Spacer(minLength: 0)
            }
            .foregroundStyle(ativo ? BXCor.papel : BXCor.tinta)
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .frame(minHeight: 56)
            .background(ativo ? BXCor.tinta : BXCor.superficie, in: forma)
            .overlay(forma.strokeBorder(ativo ? BXCor.tinta : BXCor.linha, lineWidth: 1))
            .contentShape(forma)
        }
        .buttonStyle(BXEstiloPressao())
        .sensoryFeedback(.selection, trigger: ativo)
        .accessibilityLabel("Meus favoritos, \(n)")
        .accessibilityAddTraits(ativo ? .isSelected : [])
    }

    private var canhotoVisitante: some View {
        VStack(spacing: 18) {
            BXDadosCanhoto([BXDado("Passageiro", "Você"), BXDado("Portão", "Parceiros"), BXDado("Lista", "Aberta")])
            VStack(spacing: 12) {
                BXBotao("Criar conta", estilo: .cartao) { nav.ir(.cadastro) }
                BXLinkCanhoto(prefixo: "Já tenho conta", titulo: "Entrar") { nav.ir(.entrar) }
            }
        }
    }

    @ViewBuilder private var canhotoLogado: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let carteira = sessao.carteira {
                Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 16) {
                    GridRow {
                        dadoCanhoto("Seus pontos", BXFormato.pontosComUnidade(carteira.saldo), dica: nil)
                        dadoCanhoto("Em processamento", BXFormato.pontosComUnidade(carteira.emProcessamento),
                                    dica: carteira.emProcessamento > 0 ? "Envios dos últimos 60 s" : "Nada pendente")
                    }
                    if let c = cartao {
                        GridRow {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nível atual").bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
                                Text((c.nivel?.nome ?? "—").uppercased())
                                    .bxFonte(.monoForte)
                                    .foregroundStyle(BXCor.papel)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .accessibilityElement(children: .combine)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Progresso").bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
                                Text("\(Int(c.progresso.rounded()))%").bxFonte(.valorDado)
                                BXProgresso(fracao: c.fracaoProgresso, altura: 8)
                                Text(c.proximoNivel.map { "Faltam \(BXFormato.pontos(c.faltam)) pts para \($0.nome)" } ?? "Nível máximo")
                                    .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                dadoCanhoto("Seus pontos", "Indisponível agora", dica: nil)
            }
            VStack(spacing: 12) {
                BXBotao("Ver carteira", estilo: .secundario) { nav.ir(.carteira) }
                BXBotao("Resgatar pontos →", estilo: .cartao) { nav.ir(.resgates(.catalogo)) }
            }
        }
    }

    private func dadoCanhoto(_ rotulo: String, _ valor: String, dica: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
            Text(valor).bxFonte(.valorDado).foregroundStyle(BXCor.tinta)
            if let dica { Text(dica).bxFonte(.legenda).foregroundStyle(BXCor.cinza) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lista completa

    private var secaoLista: some View {
        BXSecao(rotulo: "Painel de partidas · Lista completa", titulo: "Todos os parceiros.") {
            VStack(alignment: .leading, spacing: 18) {
                if case .pronto = carga {
                    BXNumeroDestaque(BXFormato.pontos(todos.count), legenda: "parceiros na lista")
                } else {
                    BXBlocoEsqueleto(raio: 6).frame(width: 220, height: 40)
                }
                BXTracejado()
                if case .pronto = carga { linhaPilulas }
                if !textoStatus.isEmpty {
                    Text(textoStatus).bxFonte(.rotuloMedio).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
                if let cidade, case .pronto = carga { avisoCidade(cidade) }
                listaParceiros
            }
        }
    }

    private var linhaPilulas: some View {
        BXFluxoDescobrir(espaco: 8, espacoLinha: 8) {
            BXPilula("Todos", contador: todos.count, ativa: filtro == .todos, animacao: pilulas) { escolher(.todos) }
            BXPilula("Favoritos", contador: favoritos.contagem(em: todos), ativa: filtro == .favoritos, animacao: pilulas) { escolher(.favoritos) }
            ForEach(principais, id: \.self) { c in
                BXPilula(c, ativa: filtro == .categoria(c), animacao: pilulas) { escolher(.categoria(c)) }
            }
            if case .categoria(let c) = filtro, !principais.contains(c) {
                BXPilula(c, ativa: true, animacao: pilulas) { escolher(.todos) }
            }
            if !outrasCategorias.isEmpty {
                BXPilula("Mais categorias", contador: outrasCategorias.count, ativa: false, tracejada: true) {
                    maisCategorias = true
                }
                .accessibilityLabel("Mais categorias, \(outrasCategorias.count)")
            }
        }
    }

    private func escolher(_ f: BXFiltroParceiros) {
        withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) { filtro = f }
    }

    private func avisoCidade(_ c: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            BXIcone(.local, tamanho: .cartao)
            VStack(alignment: .leading, spacing: 6) {
                Text(c).bxFonte(.tituloBilhete).foregroundStyle(BXCor.papel)
                HStack(spacing: 8) {
                    Circle().fill(BXCor.neon).frame(width: 8, height: 8)
                    Text("Rede em expansão nesta cidade").bxFonte(.rotulo).bxTextoNeon()
                }
                Text("A lista ainda não separa parceiros por cidade, então mostramos todos abaixo.")
                    .bxFonte(.legenda).foregroundStyle(BXCor.tintaApagada)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(c). Rede em expansão nesta cidade. A lista ainda não separa parceiros por cidade, então mostramos todos abaixo.")
    }

    @ViewBuilder private var listaParceiros: some View {
        switch carga {
        case .ocioso, .carregando:
            VStack(spacing: 12) { ForEach(0..<8, id: \.self) { _ in BXEsqueleto(.cartaoParceiro) } }
        case .erro(let e):
            BXEstadoErro(e) { await carregar(recarga: false) }
        case .vazio:
            BXEstadoVazio(icone: .parceiros, titulo: "A lista de parceiros está vazia agora.",
                          texto: "A rede está em expansão: novos parceiros entram aos poucos.")
        case .pronto:
            let lista = filtrados
            if lista.isEmpty {
                vazioDoFiltro
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(lista.prefix(limite)) { p in
                        cartaoParceiro(p)
                            .onAppear {
                                if !voiceOver, p.id == lista.prefix(limite).last?.id, lista.count > limite {
                                    limite += 20
                                }
                            }
                    }
                }
                let resto = lista.count - limite
                if resto > 0 {
                    BXBotao("Mostrar mais parceiros  +\(BXFormato.pontos(min(resto, 20))) de \(BXFormato.pontos(resto))", estilo: .preto) {
                        limite += 20
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder private var vazioDoFiltro: some View {
        let q = buscaEfetiva.trimmingCharacters(in: .whitespaces)
        if filtro == .favoritos && q.isEmpty {
            BXEstadoVazio(icone: .favorito, titulo: "Nenhum favorito ainda.",
                          texto: "Toque no coração do canhoto de um parceiro para guardar aqui.")
        } else if !q.isEmpty && cidade == nil {
            let dica: String = {
                if case .categoria = filtro { return "A busca vale só para a categoria escolhida. Tente em Todos." }
                if filtro == .favoritos { return "A busca vale só para os seus favoritos. Tente em Todos." }
                return "Confira a grafia ou busque pela categoria."
            }()
            BXEstadoVazio(icone: .busca, titulo: "Nenhum parceiro encontrado para “\(q)”.", texto: dica,
                          acao: (titulo: "Limpar busca", executar: { busca = ""; buscaEfetiva = "" }))
        } else if case .categoria(let c) = filtro {
            BXEstadoVazio(icone: .parceiros, titulo: "Ainda não há parceiros de \(c) na lista.",
                          texto: "A rede está em expansão: novos parceiros entram aos poucos.")
        } else {
            BXEstadoVazio(icone: .parceiros, titulo: "A lista de parceiros está vazia agora.",
                          texto: "A rede está em expansão: novos parceiros entram aos poucos.")
        }
    }

    private func cartaoParceiro(_ p: BXParceiro) -> some View {
        let fav = favoritos.contem(p.id)
        return BXBilhete(canhoto: .favorito(fav, alternar: { alternarFavorito(p) }),
                         acao: { nav.ir(.parceiro(id: p.id)) }) {
            HStack(spacing: 14) {
                BXIcone(p.icone, tamanho: .cartao)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.nome).bxFonte(.nomeParceiro)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(p.categoria.isEmpty ? "Parceiro" : p.categoria)
                        .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    if let c = p.cidade {
                        Text(c).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    }
                }
            }
            .padding(.vertical, -2)
        }
        .matchedTransitionSource(id: "parceiro-\(p.id)", in: zoom)
        .contextMenu {
            Button(fav ? "Remover dos favoritos" : "Favoritar") { alternarFavorito(p) }
            Button("Ver benefícios") { nav.ir(.parceiro(id: p.id)) }
        }
        .accessibilityLabel("\(p.nome), \(p.categoria)\(fav ? ", favorito" : "")")
        .accessibilityHint("Abre o parceiro")
    }

    private func alternarFavorito(_ p: BXParceiro) {
        withAnimation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzir)) { favoritos.alternar(p.id) }
        BXHaptica.tocar(.leve)
    }

    // MARK: - Mais categorias

    private var folhaCategorias: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Todas as categorias da lista, já juntando as irmãs (Farmácia e Farmácias, por exemplo).")
                        .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                    BXFluxoDescobrir(espaco: 8, espacoLinha: 8) {
                        ForEach(categorias, id: \.nome) { c in
                            BXPilula(c.nome, contador: c.n, ativa: filtro == .categoria(c.nome)) {
                                escolher(.categoria(c.nome))
                                maisCategorias = false
                            }
                        }
                    }
                }
                .padding(BXEspaco.margem)
            }
            .navigationTitle("Categorias")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { maisCategorias = false }.foregroundStyle(BXCor.tinta)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
        .presentationBackground(BXCor.superficie)
        .presentationDragIndicator(.visible)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Campanhas + resumo

    @ViewBuilder private var secaoCampanhas: some View {
        BXSecao(rotulo: "Embarque extra · Campanhas", titulo: "Campanhas ativas.",
                link: ("Ver campanhas", { nav.ir(.campanhas) })) {
            VStack(alignment: .leading, spacing: 28) {
                switch campanhas {
                case .ocioso, .carregando:
                    BXEsqueleto(.bilhete)
                case .erro(let e):
                    BXEstadoErro(e) { await carregarCampanhas() }
                case .vazio:
                    BXEstadoVazio(icone: .campanhas, titulo: "Nenhuma campanha ativa no momento.")
                case .pronto:
                    if campanhasAtivas.isEmpty {
                        BXEstadoVazio(icone: .campanhas, titulo: "Nenhuma campanha ativa no momento.")
                    } else {
                        carrosselCampanhas
                    }
                }
                reciboResumo
            }
        }
    }

    private var carrosselCampanhas: some View {
        let lista = campanhasAtivas
        let i = min(slide, max(0, lista.count - 1))
        return VStack(alignment: .leading, spacing: 14) {
            ZStack {
                BXBilheteCampanha(campanha: lista[i], indice: i + 1, total: lista.count) { nav.ir(.campanhas) }
                    .id(lista[i].id)
                    .transition(reduzir ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                                 removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .clipped()
            if lista.count > 1 {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(0..<lista.count, id: \.self) { k in
                            Capsule().fill(k == i ? BXCor.tinta : BXCor.pontilhado)
                                .frame(width: k == i ? 28 : 10, height: 10)
                        }
                    }
                    .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    botaoSeta(.esquerda) { mudarSlide(-1, total: lista.count) }
                    botaoSeta(.direita) { mudarSlide(1, total: lista.count) }
                }
            }
        }
        .task(id: lista.count) {
            guard lista.count > 1, !reduzir, !BXDemo.congelar else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                mudarSlide(1, total: lista.count)
            }
        }
    }

    private enum Lado { case esquerda, direita }

    private func botaoSeta(_ lado: Lado, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            BXIcone(.seta, tamanho: .padrao)
                .rotationEffect(.degrees(lado == .esquerda ? 180 : 0))
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityLabel(lado == .esquerda ? "Campanha anterior" : "Próxima campanha")
    }

    private func mudarSlide(_ d: Int, total: Int) {
        guard total > 0 else { return }
        withAnimation(BXMovimento.ou(BXMovimento.ease, reduzido: reduzir)) { slide = (slide + d + total) % total }
    }

    private var reciboResumo: some View {
        let nCat = categorias.count
        let nFav = favoritos.contagem(em: todos)
        let pronto: Bool = { if case .pronto = carga { return true }; return false }()
        return BXRecibo(cabeca: "Resumo da lista",
                        acao: .init(titulo: "Ver a lista →") { filtro = .todos; busca = "" }) {
            BXReciboTracejo()
            BXReciboLinha("Parceiros", pronto ? BXFormato.pontos(todos.count) : "—")
            BXReciboLinha("Categorias", pronto ? BXFormato.pontos(nCat) : "—")
            if BXRecursos.campanhas {
                BXReciboLinha("Campanhas ativas", campanhas.valor != nil ? BXFormato.pontos(campanhasAtivas.count) : "—")
            }
            BXReciboLinha("Seus favoritos", BXFormato.pontos(nFav))
            BXReciboTracejo()
            BXReciboTotal("Na lista", pronto ? BXFormato.pontos(filtrados.count) : "—")
            BXReciboFaixa("Rede", "em expansão")
            BXReciboNota("Números da lista atual. Os favoritos ficam salvos só neste aparelho.")
            BXReciboVia()
        }
    }

    // MARK: - Rota

    private var secaoRota: some View {
        BXSecao(rotulo: "Rota · Como usar a lista") {
            BXRotaEscalas([
                BXEscala(id: 1, rotulo: "Escala 01 · Buscar", palavra: "Busque",
                         texto: "Pelo nome da marca ou pela categoria, no campo do cartão."),
                BXEscala(id: 2, rotulo: "Escala 02 · Filtrar", palavra: "Filtre",
                         texto: "As categorias separam a lista: postos, supermercados, farmácias e o resto."),
                BXEscala(id: 3, rotulo: "Escala 03 · Guardar", palavra: "Favorite",
                         texto: "O coração do canhoto guarda o parceiro nos seus favoritos, neste aparelho."),
                BXEscala(id: 4, rotulo: "Escala 04 · Conferir", palavra: "Confira",
                         texto: "Abra o parceiro para ver os detalhes antes de sair de casa."),
            ])
        }
    }

    // MARK: - Carga

    private func primeiraCarga() async {
        if carga.valor == nil {
            aplicarBuscaInicial()
            if BXDemo.subtela == "maisCategorias" { Task { try? await Task.sleep(for: .milliseconds(700)); maisCategorias = true } }
        }
        await carregar(recarga: false)
    }

    private func aplicarBuscaInicial() {
        guard let b = buscaInicial?.trimmingCharacters(in: .whitespaces), !b.isEmpty else { return }
        let n = BXSanitizador.normalizar(b)
        // "?q=postos|supermercado|farmácia" liga a pílula, como no web.
        let casa: (String) -> Bool = { c in
            let alvo = BXSanitizador.normalizar(c)
            return alvo == n || String(alvo.dropLast()) == n || (n.count >= 4 && alvo.hasPrefix(n))
        }
        if let c = principais.first(where: casa) {
            filtro = .categoria(c)
        } else {
            busca = b
            buscaEfetiva = b
        }
    }

    private func carregar(recarga: Bool) async {
        if !recarga && carga.valor == nil { carga = .carregando }
        async let parceirosTask: Void = carregarParceiros(recarga: recarga)
        async let cartaoTask: Void = carregarCartao()
        async let campanhasTask: Void = BXRecursos.campanhas ? carregarCampanhas() : ()
        _ = await (parceirosTask, cartaoTask, campanhasTask)
    }

    private func carregarParceiros(recarga: Bool) async {
        do {
            let lista = try await BXAPI.shared.parceiros()
                .sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
            BXCatalogo.parceiros = lista
            carga = lista.isEmpty ? .vazio : .pronto(lista)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            if recarga, carga.valor != nil { return }       // mantém a lista ao falhar a recarga
            carga = .erro(BXErro.de(error))
        }
    }

    private func carregarCartao() async {
        guard sessao.logado else { return }
        if sessao.carteira == nil { await sessao.recarregarCarteira() }
        do { cartao = try await BXAPI.shared.cartao() } catch { cartaoFalhou = true }
    }

    private func carregarCampanhas() async {
        do {
            let l = try await BXAPI.shared.campanhas()
            campanhas = l.isEmpty ? .vazio : .pronto(l)
        } catch {
            guard !BXErro.ehCancelamento(error) else { return }
            campanhas = .erro(BXErro.de(error))
        }
    }
}
