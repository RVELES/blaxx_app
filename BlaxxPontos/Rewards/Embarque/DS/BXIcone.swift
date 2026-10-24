//
//  BXIcone.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Regra do dono: TODO ícone é um quadrado neon #59FD27 com desenho preto de traço.
//  Não há parâmetro de cor em `BXIcone`: a regra fica no tipo. Nada de emoji, nada de SF Symbol
//  como ícone de conteúdo.
//
//  - `BXIcone`: o ícone de conteúdo (quadrado neon; círculo só para o sino da barra).
//  - `BXGlifo`: glifos de CONTROLE do chrome ("×" e hambúrguer), com cor papel sobre tinta ou tinta sobre claro.
//  - `BXSino`: círculo neon 42 com sino e selo de contagem.
//  - `BXAvatar`: anel tinta2 + círculo neon com a inicial em tinta.
//

import SwiftUI

struct BXIcone: View {
    enum Tamanho: Sendable, Equatable {
        /// 30, raio 8, desenho 20 (barra de abas, canhoto do bilhete).
        case aba
        /// 28, raio 8, desenho 18 (lateral, quadro).
        case lateral
        /// 36, raio 10, desenho 20 (atalhos).
        case atalho
        /// 40, raio 12, desenho 22 (cartão de parceiro, lupa do campo).
        case cartao
        /// 44, raio 12, desenho 24,6 (56 %).
        case padrao
        /// 52, raio 14, desenho 29 (categoria no detalhe do parceiro).
        case marca
        case livre(lado: CGFloat, raio: CGFloat)

        var lado: CGFloat {
            switch self {
            case .aba: return 30
            case .lateral: return 28
            case .atalho: return 36
            case .cartao: return 40
            case .padrao: return 44
            case .marca: return 52
            case .livre(let l, _): return l
            }
        }
        var raio: CGFloat {
            switch self {
            case .aba, .lateral: return 8
            case .atalho: return 10
            case .cartao, .padrao: return 12
            case .marca: return 14
            case .livre(_, let r): return r
            }
        }
        var desenho: CGFloat {
            switch self {
            case .aba: return 20
            case .lateral: return 18
            case .atalho: return 20
            case .cartao: return 22
            case .padrao: return 24.6
            case .marca: return 29
            case .livre(let l, _): return (l * 0.56).rounded()
            }
        }
    }

    enum Forma: Sendable { case quadrado, circulo }

    let nome: BXIconeNome
    var tamanho: Tamanho = .padrao
    var forma: Forma = .quadrado
    /// Contorno tinta de 2 pt: use quando o ícone fica sobre uma superfície neon (canhoto, linha ativa do quadro),
    /// onde o quadrado neon sumiria no fundo.
    var contorno: Bool = false
    /// Preenche o desenho (ex.: coração do favorito marcado).
    var preenchido: Bool = false

    init(_ nome: BXIconeNome, tamanho: Tamanho = .padrao, forma: Forma = .quadrado,
         contorno: Bool = false, preenchido: Bool = false) {
        self.nome = nome
        self.tamanho = tamanho
        self.forma = forma
        self.contorno = contorno
        self.preenchido = preenchido
    }

    var body: some View {
        let fundo = forma == .circulo
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: tamanho.raio, style: .continuous))
        BXDesenhoIcone(nome, lado: tamanho.desenho, preenchido: preenchido)
            .frame(width: tamanho.lado, height: tamanho.lado)
            .background(BXCor.neon, in: fundo)
            .overlay {
                if contorno {
                    if forma == .circulo {
                        Circle().strokeBorder(BXCor.tinta, lineWidth: 2)
                    } else {
                        RoundedRectangle(cornerRadius: tamanho.raio, style: .continuous).strokeBorder(BXCor.tinta, lineWidth: 2)
                    }
                }
            }
            .accessibilityHidden(true)
    }
}

/// Só o desenho do ícone (sem o quadrado). Uso INTERNO do design system: o selo do bilhete,
/// o sino e o avatar sem inicial. Telas usam `BXIcone`.
struct BXDesenhoIcone: View {
    let nome: BXIconeNome
    let lado: CGFloat
    var cor: Color = BXCor.tinta
    var preenchido: Bool = false

    init(_ nome: BXIconeNome, lado: CGFloat, cor: Color = BXCor.tinta, preenchido: Bool = false) {
        self.nome = nome
        self.lado = lado
        self.cor = cor
        self.preenchido = preenchido
    }

    var body: some View {
        BXSVGVista(elementos: BXIconesDados.elementos[nome] ?? [],
                   caixa: BXIconesDados.caixa,
                   corAtual: cor,
                   tracoPadrao: BXIconesDados.traco(nome),
                   preencherTracos: preenchido)
            .frame(width: lado, height: lado)
    }
}

/// Glifos de CONTROLE do chrome (não são ícones de conteúdo): fechar "×" e hambúrguer.
/// Cor papel sobre tinta ou tinta sobre claro.
struct BXGlifo: View {
    enum Tipo: Sendable { case fechar, menu }
    let tipo: Tipo
    let cor: Color
    var lado: CGFloat = 20

    init(_ tipo: Tipo, cor: Color, lado: CGFloat = 20) {
        self.tipo = tipo
        self.cor = cor
        self.lado = lado
    }

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let w = size.width, h = size.height
            switch tipo {
            case .fechar:
                let m = w * 0.18
                p.move(to: CGPoint(x: m, y: m)); p.addLine(to: CGPoint(x: w - m, y: h - m))
                p.move(to: CGPoint(x: w - m, y: m)); p.addLine(to: CGPoint(x: m, y: h - m))
            case .menu:
                for f in [0.25, 0.5, 0.75] as [CGFloat] {
                    p.move(to: CGPoint(x: 0, y: h * f)); p.addLine(to: CGPoint(x: w, y: h * f))
                }
            }
            ctx.stroke(p, with: .color(cor), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .frame(width: lado, height: lado)
        .accessibilityHidden(true)
    }
}

/// Sino da barra preta: círculo neon 42 com o sino em tinta e selo de não lidas (tinta, texto papel).
struct BXSino: View {
    let naoLidas: Int
    init(naoLidas: Int) { self.naoLidas = naoLidas }

    var body: some View {
        BXDesenhoIcone(.notificacoes, lado: 19)
            .frame(width: 42, height: 42)
            .background(BXCor.neon, in: Circle())
            .overlay(alignment: .topTrailing) {
                if naoLidas > 0 {
                    Text(naoLidas > 9 ? "9+" : "\(naoLidas)")
                        .font(BXFonte.fonte(.monoForte, tamanho: 10))
                        .foregroundStyle(BXCor.papel)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(BXCor.tinta, in: Capsule())
                        .overlay(Capsule().strokeBorder(BXCor.neon, lineWidth: 1.5))
                        .offset(x: 4, y: -3)
                        .contentTransition(.numericText(value: Double(naoLidas)))
                }
            }
            .animation(.snappy, value: naoLidas)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(naoLidas == 0 ? "Notificações" : "Notificações, \(naoLidas) não \(naoLidas == 1 ? "lida" : "lidas")")
    }
}

/// Avatar do usuário: anel tinta2 (barra preta) + círculo neon com a inicial em tinta.
/// Sem inicial (usuário ainda não carregado), mostra o desenho de perfil, nunca uma letra inventada.
struct BXAvatar: View {
    let inicial: String?
    var tamanho: CGFloat = 42
    /// Anel tinta2 de 1 pt (como o chip do usuário no topo). Desligue em superfícies claras grandes (perfil).
    var anel: Bool = true

    init(inicial: String?, tamanho: CGFloat = 42, anel: Bool = true) {
        self.inicial = inicial
        self.tamanho = tamanho
        self.anel = anel
    }

    var body: some View {
        let miolo = anel ? tamanho * 32 / 42 : tamanho
        ZStack {
            if anel { Circle().strokeBorder(BXCor.tinta2, lineWidth: 1) }
            Circle().fill(BXCor.neon).frame(width: miolo, height: miolo)
            if let i = inicial?.trimmingCharacters(in: .whitespaces).first {
                Text(String(i).uppercased())
                    .font(BXFonte.fonte(.numeroGrande, tamanho: miolo * 0.44))
                    .foregroundStyle(BXCor.tinta)
            } else {
                BXDesenhoIcone(.perfil, lado: miolo * 0.56)
            }
        }
        .frame(width: tamanho, height: tamanho)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Perfil")
    }
}
