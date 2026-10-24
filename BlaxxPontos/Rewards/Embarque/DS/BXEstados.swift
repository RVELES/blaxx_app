//
//  BXEstados.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Estados padrão (02-inventario §2.9): esqueleto (blocos superficie2 com brilho), vazio (cartão
//  tracejado com texto cinza centralizado), erro com "Tentar de novo" (ícone de alerta no quadrado
//  neon), carregando, faixa offline e toasts. Regra do dono: quando a API falha aparece estado de
//  erro, nunca número de demonstração.
//

import SwiftUI

// MARK: - Carga

enum BXCarga<Valor> {
    case ocioso, carregando, pronto(Valor), vazio, erro(BXErro)

    var valor: Valor? {
        if case .pronto(let v) = self { return v }
        return nil
    }
}

/// Resolve a carga em esqueleto, vazio, erro ou conteúdo pronto.
struct BXConteudo<Valor, Pronto: View, Esqueleto: View>: View {
    let carga: BXCarga<Valor>
    let vazio: BXEstadoVazio
    let tentarDeNovo: () async -> Void
    let esqueleto: Esqueleto
    let pronto: (Valor) -> Pronto

    init(_ carga: BXCarga<Valor>,
         vazio: BXEstadoVazio,
         tentarDeNovo: @escaping () async -> Void,
         @ViewBuilder esqueleto: () -> Esqueleto,
         @ViewBuilder pronto: @escaping (Valor) -> Pronto) {
        self.carga = carga
        self.vazio = vazio
        self.tentarDeNovo = tentarDeNovo
        self.esqueleto = esqueleto()
        self.pronto = pronto
    }

    var body: some View {
        switch carga {
        case .ocioso, .carregando:
            esqueleto
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Carregando")
        case .pronto(let v):
            pronto(v)
        case .vazio:
            vazio
        case .erro(let e):
            BXEstadoErro(e, tentarDeNovo: tentarDeNovo)
        }
    }
}

// MARK: - Esqueleto

struct BXEsqueleto: View {
    enum Forma: Sendable {
        case linha(largura: CGFloat)
        case bloco(altura: CGFloat)
        case cartaoParceiro
        case bilhete
        case linhaExtrato
        case cartaoEmbarque
    }

    let forma: Forma
    init(_ forma: Forma) { self.forma = forma }

    var body: some View {
        Group {
            switch forma {
            case .linha(let largura):
                BXBlocoEsqueleto(raio: 6).frame(width: largura, height: 14)
            case .bloco(let altura):
                BXBlocoEsqueleto(raio: BXRaio.lg).frame(height: altura)
            case .cartaoParceiro:
                HStack(spacing: 14) {
                    BXBlocoEsqueleto(raio: BXRaio.sm).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        BXBlocoEsqueleto(raio: 6).frame(width: 140, height: 16)
                        BXBlocoEsqueleto(raio: 6).frame(width: 90, height: 10)
                    }
                    Spacer(minLength: 0)
                    BXBlocoEsqueleto(raio: BXRaio.xxs).frame(width: 30, height: 30)
                }
                .padding(14)
                .frame(minHeight: 69)
                .bxSuperficie(raio: BXRaio.lg)
            case .bilhete:
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        BXBlocoEsqueleto(raio: 6).frame(width: 90, height: 10)
                        BXBlocoEsqueleto(raio: 8).frame(width: 150, height: 30)
                        BXBlocoEsqueleto(raio: 6).frame(width: 110, height: 18)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    BXPicote(.vertical)
                    Color.clear.frame(width: 56)
                }
                .fixedSize(horizontal: false, vertical: true)
                .bxSuperficie(raio: BXRaio.lg)
            case .linhaExtrato:
                HStack(spacing: 12) {
                    BXBlocoEsqueleto(raio: BXRaio.xs).frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 6) {
                        BXBlocoEsqueleto(raio: 6).frame(width: 150, height: 14)
                        BXBlocoEsqueleto(raio: 6).frame(width: 60, height: 10)
                    }
                    Spacer(minLength: 0)
                    BXBlocoEsqueleto(raio: 6).frame(width: 64, height: 16)
                }
                .padding(.vertical, 10)
            case .cartaoEmbarque:
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        BXBlocoEsqueleto(raio: 6).frame(width: 200, height: 10)
                        BXBlocoEsqueleto(raio: 10).frame(width: 220, height: 44)
                        BXBlocoEsqueleto(raio: 10).frame(width: 160, height: 44)
                        HStack(spacing: 14) {
                            BXBlocoEsqueleto(raio: 6).frame(height: 30)
                            BXBlocoEsqueleto(raio: 6).frame(height: 30)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(EdgeInsets(top: 22, leading: 16, bottom: 24, trailing: 16))
                    BXPicote(.horizontal)
                    VStack(spacing: 14) {
                        BXBlocoEsqueleto(raio: BXRaio.sm).frame(height: 49)
                        BXBlocoEsqueleto(raio: 4).frame(height: 36)
                    }
                    .padding(20)
                }
                .bxSuperficie(raio: BXRaio.xl, sombra: .padrao)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Carregando")
    }
}

/// Bloco superficie2 com um brilho que corre da esquerda para a direita (parado com "Reduzir movimento").
struct BXBlocoEsqueleto: View {
    var raio: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduzido
    @State private var fase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: raio, style: .continuous)
            .fill(BXCor.superficie2)
            .overlay {
                if !reduzido && !BXDemo.congelar {
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Color.white.opacity(0.65), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.6)
                            .offset(x: fase * g.size.width * 1.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: raio, style: .continuous))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: raio, style: .continuous).strokeBorder(BXCor.linha.opacity(0.6), lineWidth: 1))
            .onAppear {
                guard !reduzido, !BXDemo.congelar else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { fase = 1 }
            }
    }
}

// MARK: - Vazio

struct BXEstadoVazio: View {
    let icone: BXIconeNome
    let titulo: String
    let texto: String?
    let acao: (titulo: String, executar: () -> Void)?

    init(icone: BXIconeNome, titulo: String, texto: String? = nil, acao: (titulo: String, executar: () -> Void)? = nil) {
        self.icone = icone
        self.titulo = titulo
        self.texto = texto
        self.acao = acao
    }

    var body: some View {
        let forma = RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous)
        VStack(spacing: 12) {
            BXIcone(icone, tamanho: .atalho)
            Text(titulo).bxFonte(.botao).foregroundStyle(BXCor.tinta)
            if let texto {
                Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
            }
            if let acao {
                BXBotao(acao.titulo, estilo: .secundario, larguraTotal: false, acao: acao.executar)
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(BXCor.superficie, in: forma)
        .overlay(forma.strokeBorder(BXCor.pontilhado, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Erro

struct BXEstadoErro: View {
    let erro: BXErro
    let tentarDeNovo: () async -> Void
    @State private var tentando = false

    init(_ erro: BXErro, tentarDeNovo: @escaping () async -> Void) {
        self.erro = erro
        self.tentarDeNovo = tentarDeNovo
    }

    var body: some View {
        VStack(spacing: 12) {
            BXIcone(.alerta, tamanho: .padrao)
            Text("Não foi possível carregar.").bxFonte(.h2).foregroundStyle(BXCor.tinta)
            Text(erro.mensagemParaUsuario).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .fixedSize(horizontal: false, vertical: true)
            BXBotao("Tentar de novo", estilo: .secundario, carregando: tentando, larguraTotal: false) {
                Task {
                    tentando = true
                    await tentarDeNovo()
                    tentando = false
                }
            }
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Carregando

struct BXCarregando: View {
    let texto: String
    init(_ texto: String = "Carregando…") { self.texto = texto }
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(BXCor.tinta)
            Text(texto).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Faixa offline

/// Faixa "Conexão instável" (foto web 94): fundo aviso, raio 12, 12 pt das bordas, acima da barra de abas.
struct BXFaixaOffline: View {
    let verificando: Bool
    let verificar: () -> Void

    init(verificando: Bool, verificar: @escaping () -> Void) {
        self.verificando = verificando
        self.verificar = verificar
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            BXIcone(.alerta, tamanho: .livre(lado: 26, raio: 7))
            Text("Conexão instável com o servidor. Tentando reconectar…")
                .font(BXFonte.fonte(.botao, tamanho: 14))
                .foregroundStyle(BXCor.avisoTexto)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: verificar) {
                Group {
                    if verificando {
                        ProgressView().tint(BXCor.papel)
                    } else {
                        Text("Verificar agora").font(BXFonte.fonte(.botao, tamanho: 13))
                    }
                }
                .foregroundStyle(BXCor.papel)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(BXCor.avisoTexto, in: Capsule())
            }
            .buttonStyle(BXEstiloPressao())
            .disabled(verificando)
        }
        .padding(12)
        .background(BXCor.avisoFundo, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
        .bxSombra(.leve)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Toast

@MainActor @Observable final class BXToastCentral {
    enum Tipo: Sendable { case sucesso, info, aviso, erro }

    struct Aviso: Identifiable, Equatable {
        let id = UUID()
        let texto: String
        let tipo: Tipo
    }

    private(set) var atual: Aviso?
    private var tarefa: Task<Void, Never>?

    init() {}

    /// Mostra por 4 s. Erro: anúncio do VoiceOver + háptica de erro.
    func mostrar(_ texto: String, _ tipo: Tipo = .sucesso) {
        let aviso = Aviso(texto: texto, tipo: tipo)
        atual = aviso
        if tipo == .erro { BXHaptica.tocar(.erro) }
        AccessibilityNotification.Announcement(texto).post()
        tarefa?.cancel()
        tarefa = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            if self?.atual?.id == aviso.id { self?.atual = nil }
        }
    }

    func fechar() { atual = nil }
}

extension View {
    /// Instala os toasts: cápsula no topo, sob a barra preta, raio 14, 14/600, cores de status.
    func bxToastHost(_ central: BXToastCentral) -> some View {
        modifier(BXToastHost(central: central))
    }
}

private struct BXToastHost: ViewModifier {
    let central: BXToastCentral
    @Environment(\.accessibilityReduceMotion) private var reduzido

    private func cores(_ t: BXToastCentral.Tipo) -> (Color, Color) {
        switch t {
        case .sucesso: return (BXCor.okFundo, BXCor.okTexto)
        case .info: return (BXCor.infoFundo, BXCor.infoTexto)
        case .aviso: return (BXCor.avisoFundo, BXCor.avisoTexto)
        case .erro: return (BXCor.perigoFundo, BXCor.perigoTexto)
        }
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let a = central.atual {
                let c = cores(a.tipo)
                Text(a.texto)
                    .font(BXFonte.fonte(.botao, tamanho: 14))
                    .foregroundStyle(c.1)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .background(c.0, in: RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: BXRaio.md, style: .continuous).strokeBorder(c.1.opacity(0.18), lineWidth: 1))
                    .bxSombra(.leve)
                    .padding(.horizontal, BXEspaco.margem)
                    .padding(.top, 8)
                    .transition(reduzido ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .onTapGesture { central.fechar() }
                    .accessibilityAddTraits(.isStaticText)
                    .id(a.id)
            }
        }
        .animation(BXMovimento.ou(BXMovimento.mola, reduzido: reduzido) ?? .default, value: central.atual)
    }
}
