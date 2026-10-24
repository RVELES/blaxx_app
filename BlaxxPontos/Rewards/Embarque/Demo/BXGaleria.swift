//
//  BXGaleria.swift
//  BlaxxPontos · Galeria do design system "Embarque" (SÓ DEBUG)
//
//  Abre com o argumento de lançamento `-BXGaleria` (ContentView). Cada página cabe numa tela do
//  iPhone 17 Pro para virar foto: `-BXGaleriaPagina <n>` abre direto a página n. Sem o número,
//  mostra o índice navegável. Zero rede: nada aqui chama a API (a não ser o `-BXTesteNucleo`,
//  que só fala com o backend local).
//  Textos de exemplo seguem as regras do dono (sem valor do ponto, sem PIX, sem parceiro inventado
//  com marca real); a lista de cidades é a do quadro da home do web.
//

#if DEBUG
import SwiftUI

struct BXGaleria: View {
    static let paginas: [(Int, String)] = [
        (1, "Cores e tipografia"),
        (2, "Ícones (57)"),
        (3, "Ícones ampliados"),
        (4, "Marca e chrome"),
        (5, "Cartão de embarque · miolo"),
        (6, "Cartão de embarque · canhoto"),
        (7, "Rota com escalas"),
        (8, "Bilhetes de pacote e campanha"),
        (9, "Bilhetes de benefício e parceiro"),
        (10, "Recibo"),
        (11, "Painel e quadro preto"),
        (12, "Rótulos, chips, pílulas, abas"),
        (13, "Botões e campos"),
        (14, "Estados"),
        (15, "Seções, cartões claros, números"),
        (16, "Rodapé-recibo"),
        (17, "Gaveta"),
        (18, "Tipografia embarcada (D16)")
    ]

    var body: some View {
        Group {
            if let n = BXDemo.galeriaPagina {
                BXGaleria.pagina(n)
            } else {
                NavigationStack {
                    List(BXGaleria.paginas, id: \.0) { p in
                        NavigationLink {
                            BXGaleria.pagina(p.0)
                        } label: {
                            HStack(spacing: 12) {
                                Text(String(format: "%02ld", p.0)).font(BXFonte.fonte(.recibo, tamanho: 13)).foregroundStyle(BXCor.cinza)
                                Text(p.1).bxFonte(.item).foregroundStyle(BXCor.tinta)
                            }
                        }
                    }
                    .navigationTitle("Galeria Embarque")
                }
            }
        }
        // Claro sem `.preferredColorScheme(.light)`: forçar o esquema da janela anula o
        // `.toolbarColorScheme(.dark)` da barra preta e deixa a barra de status escura sobre preto
        // (conferido no iOS 27). O ambiente claro mantém os controles do sistema claros.
        .environment(\.colorScheme, .light)
        .tint(BXCor.tinta)
        // `-BXTesteNucleo`: teste do núcleo contra o backend LOCAL (não roda sem o argumento).
        .task { await BXTesteNucleo.rodarSePedido() }
    }

    @ViewBuilder static func pagina(_ n: Int) -> some View {
        switch n {
        case 1: BXGPagina(n, "Cores e tipografia") { BXGCores() }
        case 2: BXGPagina(n, "Ícones · quadrado neon 44") { BXGIcones() }
        case 3: BXGPagina(n, "Ícones ampliados (comparar com o SVG do web)") { BXGIconesAmpliados() }
        case 4: BXGChrome()
        case 5: BXGPagina(n, "Cartão de embarque") { BXGCartaoHome() }
        case 6: BXGPagina(n, "Cartão de embarque", ancorarNoFim: true) { BXGCartaoHome() }
        case 7: BXGPagina(n, "Rota com escalas") { BXGRota() }
        case 8: BXGPagina(n, "Bilhetes") { BXGBilhetesPacote() }
        case 9: BXGPagina(n, "Bilhetes") { BXGBilhetesBeneficio() }
        case 10: BXGPagina(n, "Recibo") { BXGRecibo() }
        case 11: BXGPagina(n, "Painel de partidas") { BXGPainel() }
        case 12: BXGPagina(n, "Rótulos e seleção") { BXGRotulos() }
        case 13: BXGPagina(n, "Botões e campos") { BXGBotoesCampos() }
        case 14: BXGPagina(n, "Estados") { BXGEstados() }
        case 15: BXGPagina(n, "Seções e cartões") { BXGSecoes() }
        case 16: BXGRodape()
        case 17: BXGGaveta()
        case 18: BXGPagina(n, "Tipografia") { BXGTipos() }
        default: BXGPagina(n, "Página inexistente") { Text("Use 1 a \(paginas.count).") }
        }
    }
}

/// Moldura de página: chão, rótulo "GALERIA · NN", conteúdo com margem de 16.
struct BXGPagina<Conteudo: View>: View {
    let numero: Int
    let titulo: String
    let ancorarNoFim: Bool
    let conteudo: Conteudo

    init(_ numero: Int, _ titulo: String, ancorarNoFim: Bool = false, @ViewBuilder conteudo: () -> Conteudo) {
        self.numero = numero
        self.titulo = titulo
        self.ancorarNoFim = ancorarNoFim
        self.conteudo = conteudo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Galeria · \(String(format: "%02ld", numero)) · \(titulo)")
                    .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                conteudo
            }
            .padding(.horizontal, BXEspaco.margem)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(ancorarNoFim ? .bottom : .top)
        .scrollIndicators(.hidden)
        .background(BXCor.chao.ignoresSafeArea())
    }
}

// MARK: - 1 · cores e tipografia

private struct BXGCores: View {
    let cores: [(String, Color)] = [
        ("chao", BXCor.chao), ("superficie", BXCor.superficie), ("superficie2", BXCor.superficie2),
        ("linha", BXCor.linha), ("pontilhado", BXCor.pontilhado), ("cinza", BXCor.cinza),
        ("tinta", BXCor.tinta), ("tinta2", BXCor.tinta2), ("tinta3", BXCor.tinta3),
        ("apagada", BXCor.tintaApagada), ("barraTexto", BXCor.barraTexto), ("papel", BXCor.papel),
        ("neon", BXCor.neon), ("neonPress.", BXCor.neonPressionado), ("neonProf.", BXCor.neonProfundo),
        ("limaSuave", BXCor.limaSuave), ("okFundo", BXCor.okFundo), ("okTexto", BXCor.okTexto),
        ("avisoFundo", BXCor.avisoFundo), ("avisoTexto", BXCor.avisoTexto), ("perigoFundo", BXCor.perigoFundo),
        ("perigoTexto", BXCor.perigoTexto), ("infoFundo", BXCor.infoFundo), ("infoTexto", BXCor.infoTexto)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(cores, id: \.0) { c in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8).fill(c.1)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(BXCor.linha, lineWidth: 1))
                            .frame(height: 40)
                        Text(c.0).font(BXFonte.fonte(.recibo, tamanho: 8)).foregroundStyle(BXCor.cinza)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                }
            }
            BXGTiposResumo()
        }
    }
}

private struct BXGTiposResumo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modo: \(BXFonte.modo == .sistema ? "sistema (SF Pro + SF Mono)" : "embarcada (Archivo + Space Mono)")")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
            BXTituloCapa(linhas: ["Seus pontos."], marcadas: ["Compre. Ganhe."])
            Text("Título de página.").bxFonte(.tituloPagina)
            Text("Título de seção.").bxFonte(.tituloSecao)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("32.480").bxFonte(.numeroGrande)
                Text("R$ 470,00").bxFonte(.totalRecibo)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 14) {
                Text("Rótulo mono 11").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text("Recibo mono 13").bxFonte(.recibo)
            }
            Text("Corpo 15 em cinza: benefícios em parceiros selecionados.").bxFonte(.corpo).foregroundStyle(BXCor.cinza)
        }
        .foregroundStyle(BXCor.tinta)
    }
}

private struct BXGTipos: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modo: \(BXFonte.modo == .sistema ? "sistema (SF Pro + SF Mono)" : "embarcada (Archivo + Space Mono)") · Archivo no bundle: \(BXFonte.familiaEmbarcadaDisponivel ? "sim" : "não")")
                .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
            BXTituloCapa(linhas: ["Seus pontos."], marcadas: ["Compre. Ganhe."])
            Text("Título de página.").bxFonte(.tituloPagina)
            Text("Título de seção.").bxFonte(.tituloSecao)
            Text("Título h2 das páginas de conta").bxFonte(.h2)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("32.480").bxFonte(.numeroGrande)
                Text("5.500").bxFonte(.pontosBilhete)
            }
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("27").bxFonte(.numeroDestaque).padding(.horizontal, 3).background(BXCor.neon, in: Rectangle())
                Text("R$ 470,00").bxFonte(.totalRecibo)
            }
            Text("32.480").bxFonte(.saldoMono).bxTextoNeon()
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: 12))
            Text("Bilhete · nome 19/800").bxFonte(.tituloBilhete)
            Text("Corpo 15: compre pontos, envie para quem você quiser e troque por benefícios em parceiros selecionados.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            HStack(spacing: 14) {
                Text("Rótulo mono 11").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text("Seção mono 13").bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
            }
            Text("Recibo mono 13 · PACOTE ……… 5.500").bxFonte(.recibo)
        }
        .foregroundStyle(BXCor.tinta)
    }
}

// MARK: - 2 e 3 · ícones

private struct BXGIcones: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(BXIconeNome.allCases, id: \.self) { n in
                VStack(spacing: 3) {
                    BXIcone(n)
                    Text(n.rawValue).font(BXFonte.fonte(.recibo, tamanho: 8)).foregroundStyle(BXCor.cinza)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(BXCor.superficie, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private struct BXGIconesAmpliados: View {
    let nomes: [BXIconeNome] = [.voucher, .favorito, .sair, .comprar, .ajuda, .anexo]
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(nomes, id: \.self) { n in
                VStack(spacing: 8) {
                    BXIcone(n, tamanho: .livre(lado: 150, raio: 40))
                    Text(n.rawValue).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(BXCor.superficie, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - 4 · marca e chrome

private struct BXGChrome: View {
    @State private var aba: BXAba = .inicio
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    BXBarraUtilitaria()
                        .padding(.horizontal, -BXEspaco.margem)
                    Text("Galeria · 04 · Marca e chrome").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    HStack(spacing: 16) {
                        BXWordmark(.barra, altura: 22)
                        BXWordmark(.barra, altura: 30)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: 14))
                    HStack(spacing: 16) {
                        BXWordmark(.claro, altura: 28)
                        Spacer()
                        BXSino(naoLidas: 0)
                        BXSino(naoLidas: 3)
                        BXAvatar(inicial: "C")
                            .background(BXCor.tinta, in: Circle())
                        BXAvatar(inicial: nil)
                            .background(BXCor.tinta, in: Circle())
                    }
                    HStack(alignment: .bottom, spacing: 16) {
                        BXWordmark(.logoCompleto, altura: 80)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Barra do visitante").bxFonte(.rotulo).foregroundStyle(BXCor.barraTexto)
                                .lineLimit(1).minimumScaleFactor(0.5)
                            HStack(spacing: 10) {
                                BXWordmark(.barra, altura: 18)
                                Spacer()
                                Text("Entrar").bxFonte(.botao).foregroundStyle(BXCor.papel)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                BXGlifo(.menu, cor: BXCor.papel, lado: 18)
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(BXCor.tinta2, lineWidth: 1))
                            }
                        }
                    }
                    .padding(14)
                    .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: 14))
                    BXCabecalhoPagina(eyebrow: "Extrato", titulo: "Cada ponto, rastreado.",
                                      lead: "A barra preta do topo é a do sistema (NavigationStack) com o wordmark, o sino e o avatar.")
                }
                .padding(.horizontal, BXEspaco.margem)
                .padding(.bottom, 24)
            }
            .background(BXCor.chao.ignoresSafeArea())
            .bxBarraTopo(.raizLogado, naoLidas: 2, inicial: "Cliente",
                         aoSino: {}, aoAvatar: {}, aoEntrar: {}, aoMenu: {})
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BXTabBar(selecionada: $aba, aoTocarMenu: {}, aoRetocar: { _ in })
            }
        }
    }
}

// MARK: - 5 e 6 · cartão de embarque

private struct BXGCartaoHome: View {
    var body: some View {
        BXCartaoEmbarque(topo: ("Cartão de embarque · BlaXx Pontos", "Brasil · 2026")) {
            BXTituloCapa(linhas: ["Seus pontos."],
                         marcadas: ["Compre. Ganhe.", "Envie. Troque."],
                         letreiro: ["Novos sonhos.", "Novos destinos.", "Novas aventuras."],
                         intervaloLetreiro: BXDemo.congelar ? 100_000 : 2.6)
            BXGradeDados([BXDado("De", "Pontos"), BXDado("Para", "Benefícios"),
                          BXDado("Pagamento", "Cartão ou transferência"), BXDado("Mensalidade", "Nenhuma")])
            Text("Compre pontos, envie para quem você quiser e troque por benefícios em parceiros selecionados. O que você vê é o que você paga.")
                .bxFonte(.lead).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
        } canhoto: {
            BXDadosCanhoto([BXDado("Passageiro", "Você"), BXDado("Portão", "Cadastro"), BXDado("Assento", "Livre")])
            VStack(spacing: 12) {
                BXBotao("Começar agora", estilo: .cartao) {}
                BXLinkCanhoto(prefixo: "Já tenho conta", titulo: "Entrar") {}
            }
        }
    }
}

// MARK: - 7 · rota

private struct BXGRota: View {
    var body: some View {
        BXSecao(rotulo: "Rota · Como funciona") {
            BXRotaEscalas([
                BXEscala(id: 1, rotulo: "Escala 01 · Comprar", palavra: "Compre", texto: "Pacotes ou valor livre. Pagamento com cartão ou transferência."),
                BXEscala(id: 2, rotulo: "Escala 02 · Ganhar", palavra: "Ganhe", texto: "Pontos extras nas campanhas."),
                BXEscala(id: 3, rotulo: "Escala 03 · Enviar", palavra: "Envie", texto: "Mande pontos para quem você quiser, entre contas BlaXx."),
                BXEscala(id: 4, rotulo: "Escala 04 · Trocar", palavra: "Troque", texto: "Benefícios e experiências em parceiros selecionados.")
            ])
        }
    }
}

// MARK: - 8 e 9 · bilhetes

private struct BXGBilhetesPacote: View {
    @State private var escolhido = "plus"
    let pacotes = [BXPacote(chave: "start", rotulo: "Start", pontos: 2000, preco: 180),
                   BXPacote(chave: "plus", rotulo: "Plus", pontos: 5500, preco: 470)]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Escolha o seu ponto de partida.").bxFonte(.tituloSecao)
                BXLinkSeta("Valor livre") {}
            }
            .padding(.bottom, 10)
            ForEach(pacotes) { p in
                BXBilhetePacote(pacote: p, selecionado: escolhido == p.chave) {
                    escolhido = p.chave
                }
            }
            BXBilheteCampanha(nome: "Boas-vindas BlaXx", descricao: "Conclua o cadastro e faça a primeira compra.",
                              pontos: 500, indice: 1, total: 3) {}
        }
    }
}

private struct BXGBilhetesBeneficio: View {
    @State private var favoritos: Set<String> = ["b"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BXBilhete(canhoto: .icone(.voucher), acao: {}) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BX · Voucher")
                    Text("Popular")
                }
                .bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text("Café expresso duplo").bxFonte(.tituloBilhete)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("353").bxFonte(.pontosBilhete)
                    Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Validade do voucher").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text("90 dias").bxFonte(.valorDado)
                }
                Text("Ver benefício →").bxFonte(.corpo)
                    .padding(.bottom, 2)
                    .overlay(alignment: .bottom) { Rectangle().fill(BXCor.tinta).frame(height: 2) }
            }
            Text("Cartões de parceiro (favorito no canhoto)").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                .padding(.top, 6)
            ForEach([("a", "Mercado Aurora", "Supermercado", BXIconeNome.supermercado),
                     ("b", "Posto Rota Sul", "Combustível", BXIconeNome.posto),
                     ("c", "Hotel Vila Serena", "Viagens", BXIconeNome.hotel)], id: \.0) { p in
                BXBilhete(canhoto: .favorito(favoritos.contains(p.0), alternar: {
                    if favoritos.contains(p.0) { favoritos.remove(p.0) } else { favoritos.insert(p.0) }
                }), acao: {}) {
                    HStack(spacing: 14) {
                        BXIcone(p.3, tamanho: .cartao)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.1).bxFonte(.nomeParceiro)
                            Text(p.2).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                        }
                    }
                    .padding(.vertical, -2)
                }
            }
            BXEsqueleto(.bilhete)
        }
    }
}

// MARK: - 10 · recibo

private struct BXGRecibo: View {
    var body: some View {
        BXRecibo(cabeca: "Extrato da sua compra",
                 acao: .init(titulo: "Comprar 5.500 pts →", executar: {})) {
            BXReciboTracejo()
            BXReciboLinha("Pacote", "Plus")
            BXReciboLinha("Pontos", "5.500")
            BXReciboLinha("Pagamento", "cartão ou transferência")
            BXReciboLinha("Mensalidade", "nenhuma")
            BXReciboTracejo()
            BXReciboTotal("Total", "R$ 470,00")
            BXReciboFaixa("Pontos na conta", "5.500")
            BXReciboNota("Os pontos do pacote já incluem o bônus. Pontos são créditos promocionais de uso restrito na plataforma.")
            BXReciboVia()
        }
    }
}

// MARK: - 11 · painel e quadro

private struct BXGPainel: View {
    @State private var cidade: String? = "nova-york"
    let linhas = [
        BXQuadroLinha(id: "sao-paulo", destino: "São Paulo", pais: "Brasil", ativa: true),
        BXQuadroLinha(id: "rio", destino: "Rio de Janeiro", pais: "Brasil", ativa: true),
        BXQuadroLinha(id: "nova-york", destino: "Nova York", pais: "Estados Unidos", ativa: false),
        BXQuadroLinha(id: "los-angeles", destino: "Los Angeles", pais: "Estados Unidos", ativa: false),
        BXQuadroLinha(id: "miami", destino: "Miami", pais: "Estados Unidos", ativa: false),
        BXQuadroLinha(id: "toronto", destino: "Toronto", pais: "Canadá", ativa: false),
        BXQuadroLinha(id: "cdmx", destino: "Cidade do México", pais: "México", ativa: false),
        BXQuadroLinha(id: "bogota", destino: "Bogotá", pais: "Colômbia", ativa: false)
    ]
    var body: some View {
        BXPainel(rotulo: "Painel de partidas · Mapa", titulo: "Seus pontos, o mundo inteiro.") {
            VStack(alignment: .leading, spacing: 14) {
                BXNumeroDestaque("27", legenda: "cidades no mapa")
                HStack(spacing: 16) {
                    BXLegendaCor(BXCor.neon, "Em implantação")
                    BXLegendaCor(BXCor.tinta, "Rede em expansão")
                }
            }
            BXTracejado(cor: BXCor.linha)
            BXQuadroPreto(linhas: linhas, selecionada: $cidade, alturaMaxima: 230) { l in
                if let l {
                    BXQuadroInfo(titulo: l.destino,
                                 texto: l.ativa ? "Rede em implantação nesta cidade." : "Rede em expansão: ainda não há parceiros nesta cidade.",
                                 link: l.ativa ? (titulo: "Ver parceiros", acao: {}) : nil)
                } else {
                    BXQuadroInfo(titulo: "Escolha uma cidade", texto: "Toque numa cidade da lista para ver os serviços disponíveis.")
                }
            }
        }
    }
}

// MARK: - 12 · rótulos

private struct BXGRotulos: View {
    @State private var filtro = "todos"
    @State private var aba = 0
    @State private var aba2 = 0
    @Namespace private var pilulas
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                BXRotulo("Rótulo de dado")
                BXRotulo("Rótulo de seção", .secao)
            }
            FlowLinha {
                BXChip("Carteira BlaXx", .eyebrow)
                BXChip("Olá, Cliente", .saudacao)
                BXChip("Em processamento", .preto)
                BXChip("+5.000 pts", .neon)
            }
            FlowLinha {
                BXStatus("Ativa", .ok)
                BXStatus("12 dias", .aviso)
                BXStatus("Esgotado", .perigo)
                BXStatus("Novo", .info, ponto: false)
            }
            FlowLinha {
                BXPilula("Todos", contador: 266, ativa: filtro == "todos", animacao: pilulas) { withAnimation(BXMovimento.mola) { filtro = "todos" } }
                BXPilula("Favoritos", contador: 0, ativa: filtro == "fav", animacao: pilulas) { withAnimation(BXMovimento.mola) { filtro = "fav" } }
                BXPilula("Postos", contador: 1, ativa: filtro == "postos", animacao: pilulas) { withAnimation(BXMovimento.mola) { filtro = "postos" } }
                BXPilula("Mais categorias", contador: 30, ativa: false, tracejada: true) {}
            }
            FlowLinha {
                BXPilula("Todos", ativa: true, estilo: .conta) {}
                BXPilula("Não lidas", ativa: false, estilo: .conta) {}
            }
            BXAbas(selecao: $aba, opcoes: [(0, "Tudo"), (1, "Entradas"), (2, "Saídas")])
            BXAbas(selecao: $aba2, opcoes: [(0, "Catálogo"), (1, "Meus resgates")], ativo: .neon)
            VStack(alignment: .leading, spacing: 8) {
                BXRotulo("Progresso 49 %")
                BXProgresso(fracao: 0.49)
            }
        }
    }
}

/// Quebra simples em linhas (para a galeria).
private struct FlowLinha<C: View>: View {
    @ViewBuilder let c: () -> C
    var body: some View {
        BXFluxo(espaco: 8) { c() }
    }
}

/// Layout de fluxo: itens lado a lado, quebrando linha quando não cabem.
nonisolated struct BXFluxo: Layout {
    var espaco: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, linha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > 0 && x + t.width > w { x = 0; y += linha + espaco; linha = 0 }
            x += t.width + espaco
            linha = max(linha, t.height)
        }
        return CGSize(width: w, height: y + linha)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, linha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + t.width > bounds.maxX { x = bounds.minX; y += linha + espaco; linha = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espaco
            linha = max(linha, t.height)
        }
    }
}

// MARK: - 13 · botões e campos

private struct BXGBotoesCampos: View {
    @State private var email = "cliente@exemplo.test"
    @State private var cpf = "00000000191"
    @State private var senha = ""
    @State private var busca = ""
    @State private var codigo = "4821"
    @State private var ligado = true
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BXBotao("+ Comprar pontos") {}
            HStack(spacing: 10) {
                BXBotao("Entrar →", estilo: .preto) {}
                BXBotao("Resgatar →", estilo: .secundario) {}
            }
            HStack(spacing: 10) {
                BXBotao("Desabilitado") {}.disabled(true)
                BXBotao("Enviar", carregando: true) {}
            }
            HStack(spacing: 10) {
                BXBotao("Receber", estilo: .vazadoSobrePreto, icone: .receber) {}
                    .padding(8).background(BXCor.tinta, in: RoundedRectangle(cornerRadius: 16))
                BXBotao("Excluir conta", estilo: .perigo) {}
            }
            HStack {
                BXLinkSeta("Ver extrato completo") {}
                Spacer()
                Toggle("Avisos", isOn: $ligado).toggleStyle(BXInterruptorEstilo()).frame(width: 130)
                    .bxFonte(.botao)
            }
            BXCampo("E-mail ou CPF", texto: $email, tipo: .emailOuCPF)
            HStack(alignment: .top, spacing: 10) {
                BXCampo("CPF", texto: $cpf, tipo: .cpf)
                BXCampo("Senha", texto: $senha, tipo: .senha, placeholder: "Sua senha", erro: "Senha incorreta.")
            }
            BXCampoBusca(texto: $busca, placeholder: "Buscar parceiro ou loja")
            BXCampoCodigo(codigo: $codigo)
        }
    }
}

// MARK: - 14 · estados

private struct BXGEstados: View {
    @State private var toast = BXToastCentral()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Color.clear.frame(height: 52)
            BXEsqueleto(.cartaoParceiro)
            BXEsqueleto(.linhaExtrato)
            BXEstadoVazio(icone: .extrato, titulo: "Nenhum movimento ainda.",
                          acao: (titulo: "Comprar pontos", executar: {}))
            BXEstadoErro(.semConexao) {}
            BXFaixaOffline(verificando: false) {}
                .padding(.horizontal, -12)
            HStack {
                BXCarregando()
                Spacer()
                BXBotao("Mostrar toast", estilo: .secundario, larguraTotal: false) { toast.mostrar("Código copiado.") }
            }
        }
        .bxToastHost(toast)
        .onAppear { toast.mostrar("Pontos enviados. Você pode desfazer em 60 s.", .sucesso) }
    }
}

// MARK: - 15 · seções e cartões

private struct BXGSecoes: View {
    @State private var saldo: Int? = 32480
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BXCabecalhoPagina(eyebrow: "Carteira BlaXx", titulo: "Sua carteira.", lead: "Tudo que entra e sai, em um lugar só.")
                .padding(.bottom, 20)
            VStack(alignment: .leading, spacing: 10) {
                Text("Saldo").bxFonte(.rotulo).foregroundStyle(BXCor.tintaApagada)
                BXNumeroAnimado(saldo, estilo: .saldoMono, sufixo: "pts", corSufixo: BXCor.tintaApagada)
                    .bxTextoNeon()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
            .onTapGesture { saldo = (saldo ?? 0) + 1500 }
            .padding(.bottom, 20)
            BXSecao(rotulo: "Criar conta · Sem mensalidade", titulo: "Inicie sua aventura.") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    BXCartaoClaro(icone: .usuarioMais, titulo: "Cadastro em minutos", texto: "Crie sua conta com e-mail.", tamanhoIcone: .padrao)
                    BXCartaoClaro(icone: .semMensalidade, titulo: "Sem mensalidade", texto: "Sem cobrança fixa por mês.", tamanhoIcone: .padrao)
                }
            }
            HStack(alignment: .top, spacing: 16) {
                BXQRCode("blaxxpontos://enviar?para=DE0A11C2", lado: 120)
                    .padding(10)
                    .background(BXCor.superficie, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cartão BlaXx").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    Text(BXFormato.cartao("de0a11c2-0000")).bxFonte(.saldoMono).minimumScaleFactor(0.5).lineLimit(1)
                    Text("\(BXFormato.dataHora(.now)) · \(BXFormato.relativo(.now.addingTimeInterval(-300)))")
                        .bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                }
            }
        }
    }
}

// MARK: - 16 · rodapé

private struct BXGRodape: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Galeria · 16 · Rodapé-recibo").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BXEspaco.margem)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Pronto para embarcar?").bxFonte(.tituloConvite).foregroundStyle(BXCor.papel)
                    Text("Sua conta BlaXx fica pronta em poucos minutos.").bxFonte(.corpo).foregroundStyle(BXCor.tintaApagada)
                    BXBotao("Criar conta →") {}
                }
                .padding(20)
                .background(BXCor.tinta, in: RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous))
                .padding(.horizontal, BXEspaco.margem)
                .padding(.bottom, BXEspaco.secao)
                BXRodapeRecibo()
            }
        }
        .defaultScrollAnchor(.bottom)
        .background {
            VStack(spacing: 0) { BXCor.chao; BXCor.tinta }.ignoresSafeArea()
        }
    }
}

// MARK: - 17 · gaveta

private struct BXGGaveta: View {
    @State private var aberta = true
    var body: some View {
        ZStack {
            BXGPagina(17, "Gaveta (toque em Abrir)") {
                BXBotao("Abrir gaveta", estilo: .preto) { aberta = true }
                BXEsqueleto(.cartaoEmbarque)
            }
            BXGavetaConteiner(aberta: $aberta, lado: .esquerda) {
                BXGavetaGrupo("Conta")
                BXGavetaItem("Início", atual: true) {}
                BXGavetaItem("Carteira") {}
                BXGavetaItem("Extrato") {}
                BXGavetaItem("Cartão BlaXx") {}
                BXGavetaItem("Perfil") {}
                BXGavetaGrupo("Pontos")
                BXGavetaItem("Comprar pontos") {}
                BXGavetaItem("Enviar pontos") {}
                BXGavetaItem("Receber pontos") {}
                BXGavetaItem("Resgatar benefícios") {}
                BXGavetaGrupo("Descobrir")
                BXGavetaItem("Parceiros") {}
                BXBotao("Sair", estilo: .primario) {}
                    .padding(.top, 18)
            }
        }
    }
}
#endif
