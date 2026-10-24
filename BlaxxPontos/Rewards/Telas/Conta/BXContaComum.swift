//
//  BXContaComum.swift
//  BlaxxPontos · Redesenho "Embarque" · G5 (Conta e ajuda)
//
//  Peças comuns às telas de conta (perfil.html, seguranca.html, central-ajuda.html do web mobile):
//  página com rolagem e âncora de demonstração, cartão branco com título (`.bx-card` das páginas de
//  conta), linha de dado (rótulo mono + valor), linha de ação (ícone neon + título + texto + botão),
//  separador, folha (sheet) padrão e informações do app para o chamado.
//

import SwiftUI

// MARK: - Página

/// Página das telas de conta: chão bege, coluna central de até 560 pt, margem 16, rolagem com
/// teclado interativo, puxar para atualizar opcional e âncora de demonstração (`-BXAncora`).
struct BXPaginaConta<Conteudo: View>: View {
    let atualizar: (() async -> Void)?
    let rodape: Bool
    let conteudo: Conteudo

    init(rodape: Bool = false, atualizar: (() async -> Void)? = nil, @ViewBuilder conteudo: () -> Conteudo) {
        self.rodape = rodape
        self.atualizar = atualizar
        self.conteudo = conteudo()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) { conteudo }
                        .padding(.horizontal, BXEspaco.margem)
                        .padding(.top, 28)
                        .padding(.bottom, BXEspaco.secao)
                        .frame(maxWidth: BXEspaco.colunaMax)
                        .frame(maxWidth: .infinity)
                    if rodape { BXRodapeRecibo() }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BXCor.chao, in: Rectangle())
            .modifier(BXAtualizavelConta(atualizar: atualizar))
            .task {
                guard let ancora = BXDemo.ancora else { return }
                try? await Task.sleep(for: .milliseconds(700))
                proxy.scrollTo(ancora, anchor: .top)
            }
        }
    }
}

private struct BXAtualizavelConta: ViewModifier {
    let atualizar: (() async -> Void)?
    func body(content: Content) -> some View {
        if let atualizar {
            content.refreshable { await atualizar() }
        } else {
            content
        }
    }
}

// MARK: - Cartão

/// Cartão branco das páginas de conta: título 22/800, subtítulo cinza, conteúdo; raio 18, borda linha,
/// sombra leve. `perigo` = "Zona de risco" (borda e título perigoTexto).
struct BXCartaoConta<Conteudo: View>: View {
    let titulo: String?
    let subtitulo: String?
    let perigo: Bool
    let conteudo: Conteudo

    init(_ titulo: String? = nil, subtitulo: String? = nil, perigo: Bool = false,
         @ViewBuilder conteudo: () -> Conteudo) {
        self.titulo = titulo
        self.subtitulo = subtitulo
        self.perigo = perigo
        self.conteudo = conteudo()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if titulo != nil || subtitulo != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let titulo {
                        Text(titulo).bxFonte(.h2)
                            .foregroundStyle(perigo ? BXCor.perigoTexto : BXCor.tinta)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let subtitulo {
                        Text(subtitulo).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            conteudo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BXEspaco.cartao)
        .bxSuperficie(raio: BXRaio.lg, borda: perigo ? BXCor.perigoTexto : BXCor.linha, sombra: .leve)
    }
}

/// Linha divisória fina entre itens de um cartão.
struct BXDivisorConta: View {
    var body: some View {
        Rectangle().fill(BXCor.linha).frame(height: 1).accessibilityHidden(true)
    }
}

// MARK: - Linhas

/// Dado pessoal: rótulo mono MAIÚSC cinza em cima, valor 16/700 tinta embaixo (perfil.html "Dados pessoais").
struct BXLinhaDadoConta<Extra: View>: View {
    let rotulo: String
    let valor: String
    let extra: Extra

    init(_ rotulo: String, _ valor: String, @ViewBuilder extra: () -> Extra) {
        self.rotulo = rotulo
        self.valor = valor
        self.extra = extra()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rotulo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Text(valor).bxFonte(.item).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            extra
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rotulo.capitalized), \(valor)")
    }
}

extension BXLinhaDadoConta where Extra == EmptyView {
    init(_ rotulo: String, _ valor: String) {
        self.init(rotulo, valor) { EmptyView() }
    }
}

/// Linha de ação (seguranca.html "Autenticação"): quadrado neon com o desenho, título 16/700, texto
/// cinza e, embaixo à direita, o controle (botão ou selo).
struct BXLinhaAcaoConta<Controle: View>: View {
    let icone: BXIconeNome
    let titulo: String
    let texto: String?
    let controle: Controle

    init(icone: BXIconeNome, titulo: String, texto: String? = nil, @ViewBuilder controle: () -> Controle) {
        self.icone = icone
        self.titulo = titulo
        self.texto = texto
        self.controle = controle()
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                BXIcone(icone, tamanho: .cartao)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(titulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if let texto {
                        Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            controle
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Item de lista que navega: ícone neon, título, texto opcional e seta (links do Perfil, temas da ajuda).
struct BXLinhaLinkConta: View {
    let icone: BXIconeNome
    let titulo: String
    let texto: String?
    let acao: () -> Void

    init(icone: BXIconeNome, titulo: String, texto: String? = nil, acao: @escaping () -> Void) {
        self.icone = icone
        self.titulo = titulo
        self.texto = texto
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            HStack(spacing: 14) {
                BXIcone(icone, tamanho: .cartao)
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo).bxFonte(.item).foregroundStyle(BXCor.tinta)
                        .fixedSize(horizontal: false, vertical: true)
                    if let texto {
                        Text(texto).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("→").bxFonte(.botao).foregroundStyle(BXCor.tinta)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: BXToque.botao)
            .contentShape(Rectangle())
        }
        .buttonStyle(BXEstiloPressao())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Número do cartão do usuário (perfil.html: Pontos · Pendentes · Disponíveis → aqui Saldo · Em processamento · Nível).
struct BXNumeroConta: View {
    let valor: String
    let rotulo: String
    var falado: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            Text(valor).bxFonte(.tituloBilhete).foregroundStyle(BXCor.tinta)
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(rotulo).bxFonte(.rotuloGrade).foregroundStyle(BXCor.cinza)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rotulo.capitalized), \(falado ?? valor)")
    }
}

// MARK: - Folha (sheet)

/// Cabeçalho das folhas do grupo: rótulo mono, título 22/800 e botão fechar.
struct BXCabecalhoFolhaConta: View {
    let rotulo: String
    let titulo: String
    let fechar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(rotulo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text(titulo).bxFonte(.h2).foregroundStyle(BXCor.tinta)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: fechar) {
                BXGlifo(.fechar, cor: BXCor.tinta, lado: 18)
                    .frame(width: 44, height: 44)
                    .background(BXCor.superficie2, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar")
        }
    }
}

/// Corpo rolável das folhas: margem 20, coluna de 560 pt, teclado interativo.
struct BXCorpoFolhaConta<Conteudo: View>: View {
    let conteudo: Conteudo
    init(@ViewBuilder conteudo: () -> Conteudo) { self.conteudo = conteudo() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { conteudo }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 32)
                .frame(maxWidth: BXEspaco.colunaMax)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BXCor.superficie, in: Rectangle())
    }
}

extension View {
    /// Apresentação padrão das folhas do grupo (§3.1.6): detents, canto 24, fundo superfície, alça visível.
    func bxFolhaConta(_ detents: Set<PresentationDetent> = [.large]) -> some View {
        self
            .environment(\.colorScheme, .light)
            .tint(BXCor.tinta)
            .presentationDetents(detents)
            .presentationCornerRadius(24)
            .presentationBackground(BXCor.superficie)
            .presentationDragIndicator(.visible)
    }
}

/// Aviso de erro dentro de folha/cartão (fundo perigo claro, texto perigo).
struct BXAvisoErroConta: View {
    let texto: String
    var body: some View {
        Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.perigoTexto)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BXCor.perigoFundo, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
            .accessibilityLabel("Erro: \(texto)")
    }
}

/// Nota informativa (fundo superfície2, texto cinza).
struct BXNotaConta: View {
    let texto: String
    var body: some View {
        Text(texto).bxFonte(.legenda).foregroundStyle(BXCor.cinza)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(BXCor.superficie2, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
    }
}

// MARK: - Informações do app

nonisolated enum BXInfoAppConta {
    /// "1.4 (27)"
    static var versao: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "—"
        let b = info?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    @MainActor static var sistema: String {
        #if os(iOS)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }
}
