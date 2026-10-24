//
//  BXBilhete.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Bilhete com canhoto (`.bx-bilhete`, fotos web 01-03/04, 13-06, 14b-02): miolo (padding 16/16/14,
//  gap 8) + picote vertical + canhoto de 56 pt. Superfície raio 18; borda de 2 pt tinta quando
//  selecionado (o canhoto vira neon e o selo ganha o visto neon sobre tinta).
//  Acessibilidade: um único elemento-botão, com `.isSelected` quando marcado.
//

import SwiftUI

struct BXBilhete<Miolo: View>: View {
    enum Canhoto {
        /// Selo redondo de 30 pt (seleção de pacote).
        case selo
        /// Ícone 30 no canhoto (categoria do benefício).
        case icone(BXIconeNome)
        /// Canhoto neon com seta (campanha).
        case seta
        /// Coração em quadrado neon 30 (favorito do parceiro), com ação própria.
        case favorito(Bool, alternar: () -> Void)
    }

    let selecionado: Bool
    let canhoto: Canhoto
    let acao: (() -> Void)?
    let miolo: Miolo

    init(selecionado: Bool = false, canhoto: Canhoto = .selo, acao: (() -> Void)? = nil,
         @ViewBuilder miolo: () -> Miolo) {
        self.selecionado = selecionado
        self.canhoto = canhoto
        self.acao = acao
        self.miolo = miolo()
    }

    private var canhotoNeon: Bool {
        switch canhoto {
        case .seta: return true
        case .selo: return selecionado
        default: return false
        }
    }

    private var favorito: (Bool, () -> Void)? {
        if case .favorito(let f, let a) = canhoto { return (f, a) }
        return nil
    }

    private var conteudo: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) { miolo }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
            BXPicote(.vertical)
            canhotoVista
                .frame(width: 56)
                .frame(maxHeight: .infinity)
                .background(canhotoNeon ? BXCor.neon : BXCor.superficie, in: Rectangle())
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(BXCor.tinta)
        .bxSuperficie(raio: BXRaio.lg, borda: selecionado ? BXCor.tinta : nil, larguraBorda: 2)
        .animation(BXMovimento.mola, value: selecionado)
    }

    @ViewBuilder private var canhotoVista: some View {
        switch canhoto {
        case .selo:
            BXSeloBilhete(marcado: selecionado)
        case .icone(let n):
            BXIcone(n, tamanho: .aba)
        case .seta:
            BXIcone(.seta, tamanho: .livre(lado: 34, raio: 10), contorno: true)
        case .favorito(let f, let alternar):
            Button(action: alternar) {
                BXIcone(.favorito, tamanho: .aba, preenchido: f)
                    .scaleEffect(f ? 1.08 : 1)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: f)
            .accessibilityLabel(f ? "Remover dos favoritos" : "Favoritar")
        }
    }

    var body: some View {
        if let fav = favorito {
            conteudo
                .contentShape(Rectangle())
                .onTapGesture { acao?() }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(acao != nil ? .isButton : [])
                .accessibilityAction(named: fav.0 ? "Remover dos favoritos" : "Favoritar") { fav.1() }
        } else if let acao {
            Button(action: acao) { conteudo }
                .buttonStyle(BXEstiloPressao())
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selecionado ? .isSelected : [])
                .sensoryFeedback(.selection, trigger: selecionado)
        } else {
            conteudo
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(selecionado ? .isSelected : [])
        }
    }
}

/// Selo redondo do canhoto: borda 2 tinta; marcado = tinta com visto neon (neon sobre tinta é permitido).
struct BXSeloBilhete: View {
    let marcado: Bool
    var body: some View {
        ZStack {
            Circle().fill(marcado ? BXCor.tinta : Color.clear)
            Circle().strokeBorder(BXCor.tinta, lineWidth: 2)
            if marcado {
                Path { p in
                    p.move(to: CGPoint(x: 9.8, y: 14.8))
                    p.addLine(to: CGPoint(x: 13.4, y: 18.4))
                    p.addLine(to: CGPoint(x: 20.4, y: 11.2))
                }
                .stroke(BXCor.neon, style: StrokeStyle(lineWidth: 2.5, lineCap: .square, lineJoin: .miter))
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// Leve afundamento ao pressionar (cartões e bilhetes tocáveis).
struct BXEstiloPressao: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Bilhete de pacote

/// Pacote da vitrine (G1 visitante e G3 Comprar): "BX · PLUS", pontos 34/800 + "pts", "TARIFA" + preço 22/700.
/// Sem linha de bônus enquanto `BXRecursos.percentualBonusPacote == false` (D07).
struct BXBilhetePacote: View {
    let pacote: BXPacote
    let selecionado: Bool
    let mostrarBonus: Bool
    let acao: () -> Void

    init(pacote: BXPacote, selecionado: Bool, mostrarBonus: Bool = BXRecursos.percentualBonusPacote,
         acao: @escaping () -> Void) {
        self.pacote = pacote
        self.selecionado = selecionado
        self.mostrarBonus = mostrarBonus
        self.acao = acao
    }

    var body: some View {
        BXBilhete(selecionado: selecionado, canhoto: .selo, acao: acao) {
            // D07: nenhum percentual de bônus é desenhado aqui até o dono decidir o texto.
            Text("BX · \(pacote.rotulo)")
                .bxFonte(.rotulo)
                .foregroundStyle(BXCor.cinza)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(BXFormato.pontos(pacote.pontos)).bxFonte(.pontosBilhete)
                    .contentTransition(.numericText(value: Double(pacote.pontos)))
                Text("pts").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tarifa").bxFonte(.rotulo).foregroundStyle(BXCor.cinza)
                Text(BXFormato.dinheiro(pacote.preco)).bxFonte(.tarifa)
            }
        }
        .accessibilityLabel("Pacote \(pacote.rotulo), \(BXFormato.pontosFalados(pacote.pontos)), tarifa \(BXFormato.dinheiro(pacote.preco))")
    }
}

// MARK: - Bilhete de campanha

/// Campanha ativa (G2 Início, G4 Parceiros e Campanhas): "BX · CAMPANHA ATIVA" · "01 de 03" · ícone + nome ·
/// "+N pts ao concluir" · descrição segura · canhoto neon com seta.
struct BXBilheteCampanha: View {
    let nome: String
    let descricao: String?
    let pontos: Int
    let indice: Int
    let total: Int
    let acao: () -> Void

    init(campanha: BXCampanha, indice: Int, total: Int, acao: @escaping () -> Void) {
        self.init(nome: campanha.nomeSeguro, descricao: campanha.descricaoSegura,
                  pontos: campanha.pontosRecompensa, indice: indice, total: total, acao: acao)
    }

    /// Variante com valores já sanitizados.
    init(nome: String, descricao: String?, pontos: Int, indice: Int, total: Int, acao: @escaping () -> Void) {
        self.nome = nome
        self.descricao = descricao
        self.pontos = pontos
        self.indice = indice
        self.total = total
        self.acao = acao
    }

    var body: some View {
        BXBilhete(canhoto: .seta, acao: acao) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BX · Campanha ativa")
                Text(String(format: "%02ld de %02ld", indice, max(total, indice)))
            }
            .bxFonte(.rotulo)
            .foregroundStyle(BXCor.cinza)
            HStack(spacing: 12) {
                BXIcone(.campanhas, tamanho: .atalho)
                Text(nome).bxFonte(.tituloBilhete)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("+\(BXFormato.pontos(pontos))").bxFonte(.pontosBilhete)
                Text("pts ao concluir").bxFonte(.sufixoPontos).foregroundStyle(BXCor.cinza)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if let descricao {
                Text(descricao).bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityLabel("Campanha \(indice) de \(total). \(nome). Mais \(BXFormato.pontosFalados(pontos)) ao concluir. \(descricao ?? "")")
    }
}
