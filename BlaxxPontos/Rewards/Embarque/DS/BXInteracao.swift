//
//  BXInteracao.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Háptica, número animado, copiar, QR Code nítido, imagem compartilhável e o ÚNICO jeito de
//  pintar texto neon (`.bxTextoNeon()`, só sobre `BXCor.tinta`).
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Háptica

/// Háptica para resultados assíncronos. Em gestos, prefira `.sensoryFeedback`.
enum BXHaptica: Sendable {
    case selecao, sucesso, aviso, erro, leve

    static func tocar(_ h: BXHaptica) {
        #if os(iOS)
        switch h {
        case .selecao: UISelectionFeedbackGenerator().selectionChanged()
        case .sucesso: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .aviso: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .erro: UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .leve: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

// MARK: - Texto neon

extension View {
    /// ÚNICA forma de pintar texto neon. Só usar sobre `BXCor.tinta` (regra do dono: neon nunca é
    /// cor de texto sobre fundo claro).
    func bxTextoNeon() -> some View {
        foregroundStyle(BXCor.neon)
    }
}

// MARK: - Número animado

/// Pontos com `numericText`; na primeira aparição conta de 0 até o valor em 0,6 s (sem "Reduzir movimento"
/// e só se `contarNaEntrada`, que deve ser `false` quando o valor veio do cache). `nil` mostra "—".
/// VoiceOver lê "32.480 pontos" (nunca "pts").
struct BXNumeroAnimado: View {
    let valor: Int?
    let estilo: BXFonte.Estilo
    let sufixo: String?
    var contarNaEntrada: Bool = true
    var corSufixo: Color? = nil

    @Environment(\.accessibilityReduceMotion) private var reduzido
    @State private var exibido: Int?
    @State private var jaApareceu = false

    init(_ valor: Int?, estilo: BXFonte.Estilo, sufixo: String? = nil,
         contarNaEntrada: Bool = true, corSufixo: Color? = nil) {
        self.valor = valor
        self.estilo = estilo
        self.sufixo = sufixo
        self.contarNaEntrada = contarNaEntrada
        self.corSufixo = corSufixo
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(exibido.map(BXFormato.pontos) ?? "—")
                .bxFonte(estilo)
                .contentTransition(.numericText(value: Double(exibido ?? 0)))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if let sufixo {
                Group {
                    if let corSufixo { Text(sufixo).foregroundStyle(corSufixo) } else { Text(sufixo).foregroundStyle(.secondary) }
                }
                .bxFonte(.corpo)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(valor.map(BXFormato.pontosFalados) ?? "Indisponível")
        .onAppear {
            guard !jaApareceu else { return }
            jaApareceu = true
            guard let v = valor, contarNaEntrada, !reduzido, v > 0 else { exibido = valor; return }
            exibido = 0
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.6)) { exibido = v }
            }
        }
        .onChange(of: valor) { _, novo in
            withAnimation(.snappy) { exibido = novo }
        }
    }
}

// MARK: - Copiar

enum BXCopiar {
    /// Copia para a área de transferência, mostra o toast e toca uma háptica leve.
    static func copiar(_ texto: String, aviso: String, toast: BXToastCentral) {
        #if canImport(UIKit)
        UIPasteboard.general.string = texto
        #endif
        BXHaptica.tocar(.leve)
        toast.mostrar(aviso, .sucesso)
    }
}

// MARK: - QR Code

/// QR Code nítido (CIQRCodeGenerator, correção M, ampliação sem interpolação), tinta sobre superfície.
struct BXQRCode: View {
    let conteudo: String
    let lado: CGFloat

    init(_ conteudo: String, lado: CGFloat = 220) {
        self.conteudo = conteudo
        self.lado = lado
    }

    var body: some View {
        Group {
            if let img = BXQRCode.gerar(conteudo) {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                BXBlocoEsqueleto(raio: BXRaio.sm)
            }
        }
        .frame(width: lado, height: lado)
        .accessibilityElement()
        .accessibilityLabel("QR Code")
        .accessibilityAddTraits(.isImage)
    }

    nonisolated static func gerar(_ texto: String) -> CGImage? {
        let filtro = CIFilter.qrCodeGenerator()
        filtro.message = Data(texto.utf8)
        filtro.correctionLevel = "M"
        guard let saida = filtro.outputImage else { return nil }
        // tinta (#0A0B0E) sobre superfície (#FBFAF7)
        let cores = CIFilter.falseColor()
        cores.inputImage = saida
        cores.color0 = CIColor(red: 10 / 255, green: 11 / 255, blue: 14 / 255)
        cores.color1 = CIColor(red: 251 / 255, green: 250 / 255, blue: 247 / 255)
        guard let colorida = cores.outputImage else { return nil }
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(colorida, from: colorida.extent)
    }
}

// MARK: - Compartilhar como imagem

enum BXCompartilharImagem {
    /// Renderiza qualquer view (ex.: um `BXRecibo`) em imagem, escala 3, fundo chão.
    @MainActor static func imagem<V: View>(de view: V, largura: CGFloat = 375) -> Image? {
        let r = ImageRenderer(content:
            view
                .frame(width: largura - 2 * BXEspaco.margem)
                .padding(BXEspaco.margem)
                .background(BXCor.chao, in: Rectangle())
                .environment(\.colorScheme, .light)
        )
        r.scale = 3
        #if canImport(UIKit)
        guard let ui = r.uiImage else { return nil }
        return Image(uiImage: ui)
        #else
        guard let cg = r.cgImage else { return nil }
        return Image(decorative: cg, scale: 3)
        #endif
    }
}
