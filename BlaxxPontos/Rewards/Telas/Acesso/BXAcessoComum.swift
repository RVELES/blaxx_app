//
//  BXAcessoComum.swift
//  BlaxxPontos · Redesenho "Embarque" · G1 (Acesso)
//
//  Peças comuns das telas de acesso (login.html, cadastro.html, recuperar-senha.html):
//  - `BXCartaoAcesso`: cartão único (superfície, raio 18, padding 24/20, sombra);
//  - `BXPaginaAcesso`: rolagem com o cartão, a linha "© 2026 BlaXx · TERMOS · PRIVACIDADE · AJUDA"
//    e o rodapé-recibo, como no web;
//  - `BXBotaoGoogle`: botão branco com o "G" do Google (padrão de marca do Google para login);
//  - `BXDivisorOu`, `BXErroFormulario`;
//  - `BXFluxoAcesso`: estado curto compartilhado entre telas de acesso (ex.: código de e-mail já enviado
//    pelo cadastro), injetado pela casca.
//

import SwiftUI
import Observation

/// Estado compartilhado entre as telas de acesso. A raiz (`BXRaiz`) cria uma instância.
@MainActor @Observable final class BXFluxoAcesso {
    /// O cadastro acabou de criar a conta: o backend já mandou o código de verificação por e-mail.
    var codigoEmailJaEnviado = false
    /// Pedido para a boas-vindas rolar até uma âncora ("rota", "pacotes", …) — usado pela gaveta do visitante.
    var rolarBoasVindasPara: String?
    init() {}
}

// MARK: - Cartão e página

struct BXCartaoAcesso<Conteudo: View>: View {
    let conteudo: Conteudo
    init(@ViewBuilder conteudo: () -> Conteudo) { self.conteudo = conteudo() }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) { conteudo }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bxSuperficie(raio: BXRaio.lg, borda: BXCor.linha, sombra: .padrao)
    }
}

/// Título + subtítulo do cartão de acesso ("Bem-vindo de volta." / "Entre para acessar…").
struct BXTituloAcesso: View {
    let titulo: String
    let sub: String?
    let passo: String?

    init(_ titulo: String, sub: String? = nil, passo: String? = nil) {
        self.titulo = titulo
        self.sub = sub
        self.passo = passo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let passo {
                Text(passo).bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                    .accessibilityLabel(passo.lowercased())
            }
            Text(titulo).bxFonte(.tituloPagina).foregroundStyle(BXCor.tinta)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let sub {
                Text(sub).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rolagem das telas de acesso: cartão centralizado (máx. 560), linha de links e rodapé-recibo.
struct BXPaginaAcesso<Conteudo: View>: View {
    @Environment(BXNavegacao.self) private var nav
    let conteudo: Conteudo

    init(@ViewBuilder conteudo: () -> Conteudo) { self.conteudo = conteudo() }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 22) {
                    conteudo
                    BXLinksLegais()
                }
                .padding(.horizontal, BXEspaco.margem)
                .padding(.top, 16)
                .padding(.bottom, 56)
                .frame(maxWidth: BXEspaco.colunaMax)
                .frame(maxWidth: .infinity)
                BXRodapeRecibo()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            VStack(spacing: 0) { BXCor.chao; BXCor.tinta }.ignoresSafeArea()
        }
    }
}

/// "© 2026 BlaXx · TERMOS · PRIVACIDADE · AJUDA" (auth-foot do web). Termos e privacidade abrem o site.
struct BXLinksLegais: View {
    @Environment(BXNavegacao.self) private var nav

    var body: some View {
        HStack(spacing: 8) {
            Text("© 2026 BlaXx").foregroundStyle(BXCor.cinza)
            Text("·").foregroundStyle(BXCor.cinza).accessibilityHidden(true)
            link("Termos") { nav.abrirSite("termos.html") }
            Text("·").foregroundStyle(BXCor.cinza).accessibilityHidden(true)
            link("Privacidade") { nav.abrirSite("privacidade.html") }
            Text("·").foregroundStyle(BXCor.cinza).accessibilityHidden(true)
            link("Ajuda") { nav.ir(.ajuda) }
        }
        .font(BXFonte.fonte(.rotulo, tamanho: 11))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: .infinity)
    }

    private func link(_ titulo: String, acao: @escaping () -> Void) -> some View {
        Button(action: acao) {
            Text(titulo.uppercased())
                .underline()
                .foregroundStyle(BXCor.cinza)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(titulo)
    }
}

// MARK: - Google

/// Botão do Google igual ao do web (login.html/cadastro.html): fundo superfície, borda, "G" colorido.
/// O "G" segue a marca do Google para botões de login (exceção à regra de ícone neon: é marca de terceiro
/// exigida pelo Google, não ícone do app).
struct BXBotaoGoogle: View {
    let titulo: String
    let carregando: Bool
    let acao: () -> Void

    init(_ titulo: String = "Fazer Login com o Google", carregando: Bool = false, acao: @escaping () -> Void) {
        self.titulo = titulo
        self.carregando = carregando
        self.acao = acao
    }

    var body: some View {
        Button(action: acao) {
            ZStack {
                HStack {
                    BXLogoGoogle().frame(width: 20, height: 20)
                    Spacer(minLength: 0)
                }
                Text(titulo)
                    .font(BXFonte.fonte(.campo, tamanho: 15))
                    .foregroundStyle(BXCor.tinta)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(carregando ? 0 : 1)
                if carregando { ProgressView().tint(BXCor.tinta) }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 2)
            .background(BXCor.superficie, in: Capsule())
            .overlay(Capsule().strokeBorder(BXCor.linha, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(BXEstiloPressao())
        .allowsHitTesting(!carregando)
        .accessibilityLabel(carregando ? "\(titulo), carregando" : titulo)
    }
}

/// "G" do Google em 4 cores (paths 18 × 18 do botão oficial).
struct BXLogoGoogle: View {
    private static let partes: [(String, Color)] = [
        ("M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92c1.7-1.57 2.68-3.88 2.68-6.62z", Color(bxHex: 0x4285F4)),
        ("M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26c-.8.54-1.84.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18z", Color(bxHex: 0x34A853)),
        ("M3.97 10.72A5.4 5.4 0 0 1 3.68 9c0-.6.1-1.18.29-1.72V4.95H.96A9 9 0 0 0 0 9c0 1.45.35 2.83.96 4.05l3.01-2.33z", Color(bxHex: 0xFBBC05)),
        ("M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.95l3.01 2.33C4.68 5.16 6.66 3.58 9 3.58z", Color(bxHex: 0xEA4335))
    ]
    private static let paths: [(Path, Color)] = partes.map { (BXSVG.path($0.0), $0.1) }

    var body: some View {
        Canvas { ctx, size in
            let e = min(size.width, size.height) / 18
            let t = CGAffineTransform(scaleX: e, y: e)
            for (p, cor) in Self.paths { ctx.fill(p.applying(t), with: .color(cor)) }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Divisor e erro

/// Linha — OU — linha.
struct BXDivisorOu: View {
    var body: some View {
        HStack(spacing: 14) {
            Rectangle().fill(BXCor.linha).frame(height: 1)
            Text("ou").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
            Rectangle().fill(BXCor.linha).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Erro do formulário (inline, fundo perigo), anunciado pelo VoiceOver.
struct BXErroFormulario: View {
    let texto: String
    init(_ texto: String) { self.texto = texto }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BXIcone(.alerta, tamanho: .lateral)
            Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.perigoTexto)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BXCor.perigoFundo, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { AccessibilityNotification.Announcement(texto).post() }
    }
}

/// Aviso positivo inline (ex.: "Se este e-mail estiver cadastrado…").
struct BXAvisoFormulario: View {
    let texto: String
    init(_ texto: String) { self.texto = texto }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BXIcone(.check, tamanho: .lateral)
            Text(texto).bxFonte(.corpo).foregroundStyle(BXCor.okTexto)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(BXCor.okFundo, in: RoundedRectangle(cornerRadius: BXRaio.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .onAppear { AccessibilityNotification.Announcement(texto).post() }
    }
}

// MARK: - Validações locais (as mesmas do web)

nonisolated enum BXValidaAcesso {
    /// Nome e sobrenome (duas palavras com ao menos 2 letras).
    static func nomeCompleto(_ s: String) -> Bool {
        s.split(whereSeparator: \.isWhitespace).filter { $0.count >= 2 }.count >= 2
    }

    static func email(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let arroba = t.firstIndex(of: "@") else { return false }
        let dominio = t[t.index(after: arroba)...]
        return arroba != t.startIndex && dominio.contains(".") && !dominio.hasSuffix(".") && !t.contains(" ")
    }

    /// CPF com dígito verificador (11 dígitos, não repetidos).
    static func cpf(_ s: String) -> Bool {
        let d = s.compactMap { $0.wholeNumberValue }
        guard d.count == 11, Set(d).count > 1 else { return false }
        func dv(_ n: Int) -> Int {
            var soma = 0
            for i in 0..<n { soma += d[i] * (n + 1 - i) }
            let r = (soma * 10) % 11
            return r == 10 ? 0 : r
        }
        return dv(9) == d[9] && dv(10) == d[10]
    }

    /// Política mínima do web (≥ 7). A política completa vem do servidor em `issues`.
    static func senha(_ s: String) -> Bool { s.count >= 7 }
}
