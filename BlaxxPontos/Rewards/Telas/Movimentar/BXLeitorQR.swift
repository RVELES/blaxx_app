//
//  BXLeitorQR.swift
//  BlaxxPontos · Redesenho "Embarque" · G3 (Movimentar)
//
//  Leitura do QR de um Cartão BlaXx para preencher o "Para" do envio (spec §3.2 e §5 G3 item 8).
//  VisionKit `DataScannerViewController`, só quando o aparelho suporta e o Info.plist tem
//  `NSCameraUsageDescription` (o G1 acrescenta). Aceita o link `blaxxpontos://enviar?para=<ID>` gerado
//  pela tela Receber e o código puro de 8 hex; qualquer outro QR é recusado (quem chama mostra o aviso).
//

import SwiftUI
#if os(iOS) && canImport(VisionKit)
import VisionKit
import Vision
#endif

@MainActor enum BXLeitorQR {
    /// Botão "Ler QR" só aparece quando dá para usar a câmera de verdade.
    static var disponivel: Bool {
        #if os(iOS) && canImport(VisionKit) && !targetEnvironment(simulator)
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else { return false }
        return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        #else
        return false
        #endif
    }

    /// Cartão BlaXx (8 hex maiúsculos) a partir do conteúdo lido; nil se não for um Cartão BlaXx.
    nonisolated static func cartao(de lido: String) -> String? {
        let texto = lido.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: texto), url.scheme?.lowercased() == "blaxxpontos" {
            guard case .enviar(let para)? = BXDestino.deLink(url), let para else { return nil }
            return codigoPuro(para)
        }
        return codigoPuro(texto)
    }

    nonisolated private static func codigoPuro(_ s: String) -> String? {
        let limpo = s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").uppercased()
        guard limpo.count == 8, limpo.allSatisfy(\.isHexDigit) else { return nil }
        return limpo
    }
}

#if os(iOS)
/// Folha com a câmera: devolve o primeiro QR lido (quem chama valida com `BXLeitorQR.cartao(de:)`).
struct BXLeitorQRFolha: View {
    let aoLer: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            BXCabecaFolha("Ler QR do Cartão BlaXx") { dismiss() }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            ZStack {
                BXCor.tinta
                #if canImport(VisionKit)
                BXScannerQR(aoLer: aoLer)
                #endif
                RoundedRectangle(cornerRadius: BXRaio.lg, style: .continuous)
                    .strokeBorder(BXCor.neon, lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .accessibilityHidden(true)
            }
            Text("Aponte a câmera para o QR Code do Cartão BlaXx de quem vai receber.")
                .bxFonte(.corpo).foregroundStyle(BXCor.cinza)
                .multilineTextAlignment(.center)
                .padding(20)
        }
        .background(BXCor.superficie, in: Rectangle())
        .environment(\.colorScheme, .light)
    }
}

#if canImport(VisionKit)
private struct BXScannerQR: UIViewControllerRepresentable {
    let aoLer: (String) -> Void

    func makeCoordinator() -> Coordenador { Coordenador(aoLer: aoLer) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                           qualityLevel: .balanced,
                                           recognizesMultipleItems: false,
                                           isHighFrameRateTrackingEnabled: false,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordenador) {
        vc.stopScanning()
    }

    final class Coordenador: NSObject, DataScannerViewControllerDelegate {
        let aoLer: (String) -> Void
        private var leu = false
        init(aoLer: @escaping (String) -> Void) { self.aoLer = aoLer }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !leu else { return }
            for item in addedItems {
                if case .barcode(let codigo) = item, let texto = codigo.payloadStringValue {
                    leu = true
                    dataScanner.stopScanning()
                    aoLer(texto)
                    return
                }
            }
        }
    }
}
#endif
#endif
