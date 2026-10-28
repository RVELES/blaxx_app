//
//  BXChrome.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Chrome do celular (02-inventario §2.9, fotos web 90, 91, 92, 93):
//  - `BXTabBar`: barra preta de 5 colunas (Início, Carteira, Comprar, Resgates, Menu), ícone em quadrado
//    neon 30, rótulo mono 11 (ativo NEON sobre preto, inativo tintaApagada);
//  - `BXBarraUtilitaria`: faixa preta de 28 pt com "● Rede em expansão" em neon;
//  - `.bxBarraTopo(...)`: barra de navegação preta com o wordmark, sino e avatar (ou "Entrar" + hambúrguer);
//  - `BXGavetaConteiner` + itens: gaveta lateral com scrim 45 %;
//  - `BXCabecalhoPagina`, `BXSecao`, `BXCartaoClaro`, `BXRodapeRecibo`.
//

import SwiftUI

// MARK: - Abas

extension BXAba {
    var titulo: String {
        switch self {
        case .inicio: return "Início"
        case .carteira: return "Carteira"
        case .comprar: return "Comprar"
        case .resgates: return "Resgates"
        }
    }
    var icone: BXIconeNome {
        switch self {
        case .inicio: return .inicio
        case .carteira: return .carteira
        case .comprar: return .comprar
        case .resgates: return .resgates
        }
    }
}

struct BXTabBar: View {
    @Binding var selecionada: BXAba
    let aoTocarMenu: () -> Void
    let aoRetocar: (BXAba) -> Void

    init(selecionada: Binding<BXAba>, aoTocarMenu: @escaping () -> Void, aoRetocar: @escaping (BXAba) -> Void) {
        self._selecionada = selecionada
        self.aoTocarMenu = aoTocarMenu
        self.aoRetocar = aoRetocar
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BXAba.visiveis, id: \.self) { aba in
                item(aba.titulo, aba.icone, ativo: aba == selecionada) {
                    if aba == selecionada { aoRetocar(aba) } else { selecionada = aba }
                }
            }
            item("Menu", .menu, ativo: false, acao: aoTocarMenu)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(BXCor.tinta.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(BXCor.tinta2).frame(height: 1) }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .sensoryFeedback(.selection, trigger: selecionada)
    }

    private func item(_ titulo: String, _ icone: BXIconeNome, ativo: Bool, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            VStack(spacing: 4) {
                BXIcone(icone, tamanho: .aba)
                Group {
                    if ativo { Text(titulo).bxTextoNeon() } else { Text(titulo).foregroundStyle(BXCor.tintaApagada) }
                }
                .bxFonte(.rotuloAba)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, minHeight: BXToque.itemAba)
            .contentShape(RoundedRectangle(cornerRadius: BXRaio.xs))
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(ativo ? [.isButton, .isSelected] : .isButton)
        .accessibilityShowsLargeContentViewer {
            BXIcone(icone, tamanho: .aba)
            Text(titulo)
        }
    }
}

// MARK: - Barra utilitária

struct BXBarraUtilitaria: View {
    let texto: String
    init(texto: String = "Rede em expansão") { self.texto = texto }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(BXCor.neon).frame(width: 7, height: 7)
            Text(texto).font(BXFonte.fonte(.recibo, tamanho: 11)).bxTextoNeon()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BXEspaco.margem)
        .frame(height: 28)
        .background(BXCor.tinta, in: Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(BXCor.tinta2).frame(height: 1) }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Barra do topo

enum BXBarraTopoModo: Sendable { case raizLogado, empilhadaLogado, raizVisitante, empilhadaVisitante }

extension View {
    /// Barra preta do topo aplicada pela casca em toda tela: fundo tinta visível, `toolbarColorScheme(.dark)`
    /// (ícones da barra de status claros). Raiz: wordmark 114 × 22 à esquerda; empilhada: voltar do sistema +
    /// wordmark 96 × 18 no centro. Direita logado: `BXSino` + `BXAvatar`; visitante: "Entrar" + hambúrguer.
    func bxBarraTopo(_ modo: BXBarraTopoModo, naoLidas: Int, inicial: String?,
                     aoSino: @escaping () -> Void, aoAvatar: @escaping () -> Void,
                     aoEntrar: @escaping () -> Void, aoMenu: @escaping () -> Void) -> some View {
        modifier(BXBarraTopo(modo: modo, naoLidas: naoLidas, inicial: inicial,
                             aoSino: aoSino, aoAvatar: aoAvatar, aoEntrar: aoEntrar, aoMenu: aoMenu))
    }
}

private struct BXBarraTopo: ViewModifier {
    let modo: BXBarraTopoModo
    let naoLidas: Int
    let inicial: String?
    let aoSino: () -> Void
    let aoAvatar: () -> Void
    let aoEntrar: () -> Void
    let aoMenu: () -> Void

    private var raiz: Bool { modo == .raizLogado || modo == .raizVisitante }
    private var logado: Bool { modo == .raizLogado || modo == .empilhadaLogado }

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(BXCor.tinta, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if raiz {
                    ToolbarItem(placement: .topBarLeading) {
                        BXWordmark(.barra, altura: 22)
                    }
                    .bxSemFundoCompartilhado()
                } else {
                    ToolbarItem(placement: .principal) {
                        BXWordmark(.barra, altura: 18)
                    }
                    .bxSemFundoCompartilhado()
                }
                if logado {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: aoSino) { BXSino(naoLidas: naoLidas) }
                            .buttonStyle(BXEstiloPressao())
                    }
                    .bxSemFundoCompartilhado()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: aoAvatar) { BXAvatar(inicial: inicial) }
                            .buttonStyle(BXEstiloPressao())
                    }
                    .bxSemFundoCompartilhado()
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: aoEntrar) {
                            Text("Entrar").bxFonte(.botao).foregroundStyle(BXCor.papel)
                                .lineLimit(1)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(BXEstiloPressao())
                    }
                    .bxSemFundoCompartilhado()
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: aoMenu) {
                            BXGlifo(.menu, cor: BXCor.papel, lado: 20)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().strokeBorder(BXCor.tinta2, lineWidth: 1))
                        }
                        .buttonStyle(BXEstiloPressao())
                        .accessibilityLabel("Menu")
                    }
                    .bxSemFundoCompartilhado()
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        #else
        content
        #endif
    }
}

// MARK: - Gaveta

struct BXGavetaConteiner<Conteudo: View>: View {
    enum Lado: Sendable {
        /// Logado: abre pela esquerda.
        case esquerda
        /// Visitante: abre pela direita.
        case direita
    }

    @Binding var aberta: Bool
    let lado: Lado
    let conteudo: Conteudo
    @State private var arrasto: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduzido

    init(aberta: Binding<Bool>, lado: Lado, @ViewBuilder conteudo: () -> Conteudo) {
        self._aberta = aberta
        self.lado = lado
        self.conteudo = conteudo()
    }

    private func fechar() {
        withAnimation(BXMovimento.ou(BXMovimento.gaveta, reduzido: reduzido)) { aberta = false }
        arrasto = 0
    }

    var body: some View {
        GeometryReader { g in
            let largura = min(g.size.width * 0.88, 360)
            let progresso = max(0, 1 - abs(arrasto) / largura)
            ZStack(alignment: lado == .esquerda ? .leading : .trailing) {
                if aberta {
                    BXCor.scrim
                        .opacity(progresso)
                        .ignoresSafeArea()
                        .onTapGesture(perform: fechar)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    painel
                        .frame(width: largura)
                        .frame(maxHeight: .infinity)
                        .background(BXCor.superficie.ignoresSafeArea())
                        .offset(x: arrasto)
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onChanged { v in
                                    let dx = v.translation.width
                                    arrasto = lado == .esquerda ? min(0, dx) : max(0, dx)
                                }
                                .onEnded { v in
                                    let dx = abs(v.predictedEndTranslation.width)
                                    if dx > largura * 0.35 { fechar() } else { withAnimation(BXMovimento.mola) { arrasto = 0 } }
                                }
                        )
                        .transition(reduzido ? .opacity : .move(edge: lado == .esquerda ? .leading : .trailing))
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape, fechar)
                }
            }
            .frame(width: g.size.width, height: g.size.height, alignment: lado == .esquerda ? .leading : .trailing)
            .animation(BXMovimento.ou(BXMovimento.gaveta, reduzido: reduzido), value: aberta)
        }
    }

    private var painel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Button(action: fechar) {
                    BXGlifo(.fechar, cor: BXCor.tinta, lado: 16)
                        .frame(width: 44, height: 44)
                        .background(BXCor.superficie, in: Circle())
                        .overlay(Circle().strokeBorder(BXCor.linha, lineWidth: 1))
                }
                .buttonStyle(BXEstiloPressao())
                .accessibilityLabel("Fechar menu")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) { conteudo }
                    .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }
}

/// Rótulo de grupo da gaveta (mono 11 MAIÚSC cinza).
struct BXGavetaGrupo: View {
    let titulo: String
    init(_ titulo: String) { self.titulo = titulo }
    var body: some View {
        Text(titulo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Item da gaveta: 48 pt, raio 10, 16/600; atual = fundo tinta com texto superfície.
struct BXGavetaItem: View {
    let titulo: String
    let atual: Bool
    let acao: () -> Void

    init(_ titulo: String, atual: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.atual = atual
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            Text(titulo).bxFonte(.item)
                .foregroundStyle(atual ? BXCor.superficie : BXCor.tinta)
                .frame(maxWidth: .infinity, minHeight: BXToque.itemGaveta, alignment: .leading)
                .padding(.horizontal, 14)
                .background(atual ? BXCor.tinta : Color.clear, in: RoundedRectangle(cornerRadius: BXRaio.xs, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityAddTraits(atual ? .isSelected : [])
    }
}

// MARK: - Cabeçalho e seção

/// Cabeçalho das páginas de conta: chip eyebrow + título de página + lead.
struct BXCabecalhoPagina: View {
    let eyebrow: String
    let titulo: String
    let lead: String?

    init(eyebrow: String, titulo: String, lead: String? = nil) {
        self.eyebrow = eyebrow
        self.titulo = titulo
        self.lead = lead
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXChip(eyebrow, .eyebrow)
            VStack(alignment: .leading, spacing: 8) {
                Text(titulo).bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let lead {
                    Text(lead).bxFonte(.lead).foregroundStyle(BXCor.cinza)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Seção do kit: rótulo mono ("ROTA · COMO FUNCIONA"), título 32/800, link opcional e conteúdo; 40 pt abaixo.
struct BXSecao<Conteudo: View>: View {
    let rotulo: String
    let titulo: String?
    let link: (String, () -> Void)?
    let conteudo: Conteudo

    init(rotulo: String, titulo: String? = nil, link: (String, () -> Void)? = nil,
         @ViewBuilder conteudo: () -> Conteudo) {
        self.rotulo = rotulo
        self.titulo = titulo
        self.link = link
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BXEspaco.cabecalhoSecao) {
            VStack(alignment: .leading, spacing: 14) {
                Text(rotulo).bxFonte(.rotuloSecao).foregroundStyle(BXCor.cinza)
                if let titulo {
                    Text(titulo).bxFonte(.tituloSecao).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                if let link {
                    BXLinkSeta(link.0, acao: link.1)
                }
            }
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, BXEspaco.secao)
    }
}

/// Cartão claro com ícone (atalhos, convite): superfície, borda 1 linha, raio 18, padding 18.
struct BXCartaoClaro: View {
    let icone: BXIconeNome
    let titulo: String
    let texto: String
    let acao: (() -> Void)?
    var tamanhoIcone: BXIcone.Tamanho = .atalho

    init(icone: BXIconeNome, titulo: String, texto: String, acao: (() -> Void)? = nil,
         tamanhoIcone: BXIcone.Tamanho = .atalho) {
        self.icone = icone
        self.titulo = titulo
        self.texto = texto
        self.acao = acao
        self.tamanhoIcone = tamanhoIcone
    }

    private var conteudo: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXIcone(icone, tamanho: tamanhoIcone)
            VStack(alignment: .leading, spacing: 6) {
                Text(titulo).bxFonte(.tituloBilhete).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BXEspaco.cartao)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        if let acao {
            Button(action: acao) { conteudo }.buttonStyle(BXEstiloPressao())
        } else {
            conteudo
        }
    }
}

// MARK: - Rodapé-recibo

/// Rodapé preto de borda a borda: logo completo (80), frase da marca, "© 2026 BlaXx Pontos",
/// código de barras papel 200 × 28 e aviso legal.
struct BXRodapeRecibo: View {
    init() {}

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            BXWordmark(.logoCompleto, altura: 80)
            Text(BXRecursos.compraNoApp
                 ? "Um programa de recompensas simples: compre pontos, envie para quem quiser e troque por benefícios em parceiros selecionados. Sem letra miúda."
                 : "Um programa de recompensas simples: receba e envie pontos entre contas BlaXx e troque por benefícios. Sem letra miúda.")
                .bxFonte(.corpo)
                .foregroundStyle(BXCor.tintaApagada)
                .fixedSize(horizontal: false, vertical: true)
            BXTracejado(cor: BXCor.tinta3)
            Text("© 2026 BlaXx Pontos")
                .font(BXFonte.fonte(.recibo, tamanho: 12))
                .foregroundStyle(BXCor.papel)
            BXCodigoBarras(altura: 28, cor: BXCor.papel)
                .frame(width: 200)
            Text("Os pontos BlaXx não são moeda, depósito, investimento, valor mobiliário ou criptoativo. São créditos promocionais de uso restrito dentro da plataforma BlaXx.")
                .bxFonte(.legenda)
                .foregroundStyle(BXCor.tintaApagada)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Conteúdo alinhado à coluna das telas (iPad/paisagem); o fundo preto segue de ponta a ponta.
        .frame(maxWidth: BXEspaco.colunaMax)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, BXEspaco.margem)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .background(BXCor.tinta, in: Rectangle())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Compatibilidade iOS 18

#if os(iOS)
extension ToolbarContent {
    /// `sharedBackgroundVisibility` só existe no iOS 26 (Liquid Glass); antes
    /// dele a barra não desenha o fundo compartilhado, então não há o que esconder.
    @ToolbarContentBuilder
    func bxSemFundoCompartilhado() -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
#endif
