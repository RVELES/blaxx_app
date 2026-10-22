//
//  BuyView.swift
//  BlaxxPontos
//
//  Fluxo 1 do fluxograma: Comprar pontos via PIX.
//
//  ⚠️ CÓDIGO MORTO — alcançável só por `ContentView.legacyBody`, que ninguém
//  chama. A tela viva de compra é `Rewards/RewardsFinanceSheets.swift`
//  (`RewardsBuySheet`). Corrigir aqui não chega ao app. Ver ContentView.swift.
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct BuyView: View {
    @Environment(Session.self) private var session
    @State private var packages: [PointPackageDTO] = []
    @State private var loading = false
    @State private var charge: PixChargeDTO?
    @State private var paid = false
    @State private var error: String?
    @State private var isMockProvider = true   // Sprint 3: detecta provider real

    // Onda 2 · Valor livre · agora usa /pix/charge MP igual a Web
    @State private var mode: BuyMode = .packages
    @State private var customAmount: String = ""
    @State private var pollTask: Task<Void, Never>?

    // Onda 3 · Compra com email não verificado → abre sheet do EmailVerifyView
    // e ao dismiss, re-tenta a operação original pendente.
    @State private var showEmailVerifySheet = false
    /// Operação pendente que deve ser retentada após verificação de email.
    /// Closure captura o package key ou amount_brl original.
    @State private var pendingRetry: (() async -> Void)?

    enum BuyMode: String, CaseIterable {
        case packages = "Pacotes"
        case custom = "Valor livre"
    }

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 28) {
                    if !isCompact {
                        Topbar(eyebrow: "Compra de pontos", title: "Comprar pontos",
                               userName: session.user?.name ?? "?")
                    }

                    // Segmented control entre pacotes e valor livre
                    if !paid && charge == nil {
                        Picker("Modo", selection: $mode) {
                            ForEach(BuyMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                    }

                    if paid {
                        successView
                    } else if let charge {
                        paymentView(charge: charge)
                    } else if mode == .custom {
                        customAmountView
                    } else {
                        packagesView
                    }
                }
                .padding(isCompact ? 16 : 40)
            }
            .background(BlaxxColor.appBg)
            .navigationTitle(isCompact ? "Comprar" : "")
            .blaxxBrandNavBar()
            .task { await loadPackages() }
            .sheet(isPresented: $showEmailVerifySheet, onDismiss: {
                // Ao fechar a sheet, se o usuário verificou o email
                // (session.user.isEmailVerified == true), retenta a operação
                // pendente. Senão limpa a retry pra não auto-disparar.
                Task {
                    await session.refreshUser()
                    if session.user?.isEmailVerified == true,
                       let retry = pendingRetry {
                        pendingRetry = nil
                        await retry()
                    } else {
                        pendingRetry = nil
                    }
                }
            }) {
                EmailVerifyView().environment(session)
            }
        }
    }

    /// Detecta se um erro do backend é 403 EMAIL_NOT_VERIFIED.
    /// Case-insensitive na comparação do `code` (backend devolve
    /// "EMAIL_NOT_VERIFIED" uppercase) e fallback no message contendo
    /// "e-mail" / "verificad" pra robustez frente a variações.
    private func isEmailVerificationError(_ err: Error) -> Bool {
        guard let api = err as? APIError, api.status == 403 else { return false }
        let m = api.message.lowercased()
        return m.contains("e-mail") || m.contains("email") ||
               m.contains("verificad") || m.contains("confirme")
    }

    // MARK: - Lista de pacotes

    private var packagesView: some View {
        VStack(alignment: .leading, spacing: 16) {
            BlaxxCard(variant: .lime) {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow(text: "Pacotes de pontos")
                    Text("Escolha um pacote")
                        .font(BlaxxFont.display(22))
                        .foregroundStyle(BlaxxColor.black)
                    Text("Pague via PIX e os pontos são creditados em segundos. Validade 24 meses.")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray800)
                }
            }
            // Banner de erro VISÍVEL (acima dos pacotes, não só quando lista vazia)
            if let error {
                errorBanner(error)
            }
            if loading {
                ProgressView("Carregando pacotes…").padding()
            } else if packages.isEmpty {
                Text("Nenhum pacote disponível.").foregroundStyle(BlaxxColor.gray600)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                    ForEach(packages) { pkg in
                        packageCard(pkg)
                    }
                }
            }
        }
    }

    /// Banner padronizado de erro com botão de ação contextual.
    @ViewBuilder
    private func errorBanner(_ msg: String) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BlaxxColor.warning)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Não foi possível continuar")
                            .font(.system(size: 14, weight: .semibold))
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundStyle(BlaxxColor.gray600)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // Atalho específico se o problema for e-mail não verificado
                if msg.lowercased().contains("e-mail") || msg.lowercased().contains("verificad") {
                    Button("Reenviar verificação por e-mail") {
                        Task { await resendVerification() }
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                Button("Tentar novamente") {
                    error = nil
                    Task { await loadPackages() }
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private func resendVerification() async {
        do {
            try await BlaxxAPI.shared.resendEmailVerification()
            error = "Código reenviado para seu e-mail. Verifique a caixa de entrada."
        } catch let e {
            error = "Falha ao reenviar: \(e.localizedDescription)"
        }
    }

    private func packageCard(_ p: PointPackageDTO) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: p.label)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(p.formattedPoints)
                        .font(BlaxxFont.display(32))
                        .foregroundStyle(BlaxxColor.black)
                    Text("pts")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray600)
                }
                Text("por ").font(.system(size: 13)).foregroundStyle(BlaxxColor.gray600)
                + Text(p.formattedPrice).font(.system(size: 13, weight: .semibold)).foregroundStyle(BlaxxColor.black)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    bulletPoint("Crédito imediato após PIX")
                    bulletPoint("Validade 24 meses")
                    bulletPoint("Cashback em 6 meses")
                }
                Button(loading ? "Gerando QR…" : "Pagar com PIX") {
                    Task { await createCharge(p.key) }
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .disabled(loading)
                .padding(.top, 4)
            }
        }
    }

    private func bulletPoint(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(BlaxxColor.gray400)
            Text(s).font(.system(size: 12)).foregroundStyle(BlaxxColor.gray600)
        }
    }

    // MARK: - Tela de pagamento PIX

    private func paymentView(charge: PixChargeDTO) -> some View {
        AdaptiveStack(spacing: 16) {
            BlaxxCard {
                VStack(alignment: .center, spacing: 12) {
                    Eyebrow(text: "Escaneie")
                    Text("QR Code PIX")
                        .font(BlaxxFont.display(18))
                    qrPlaceholder(content: charge.br_code)
                    Text("Aponte o app do seu banco")
                        .font(.system(size: 12))
                        .foregroundStyle(BlaxxColor.gray400)
                }
                .frame(maxWidth: .infinity)
            }

            BlaxxCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Ou cole o código")
                    Text("PIX copia-e-cola")
                        .font(BlaxxFont.display(18))
                    Text(charge.br_code)
                        .font(BlaxxFont.mono(11))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BlaxxColor.appBg)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(BlaxxColor.gray200, lineWidth: 0.5))
                    Button("Copiar código") {
                        copyToClipboard(charge.br_code)
                    }
                    .buttonStyle(DarkButtonStyle(fullWidth: true))
                    Divider()
                    summaryRow("Valor", formatBRL(charge.amount_brl))
                    summaryRow("Pontos", "\(formatPts(charge.points_to_credit)) pts")
                    summaryRow("Expira em", "30 minutos")
                    #if DEBUG
                    if isMockProvider {
                        Button("Simular pagamento (demo)") {
                            Task { await simulate(charge: charge) }
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                        .padding(.top, 6)
                    } else {
                        Text("Aguardando pagamento real…")
                            .font(.system(size: 13))
                            .foregroundStyle(BlaxxColor.gray600)
                            .padding(.top, 6)
                    }
                    #else
                    // Release: nunca mostra o atalho de simular pagamento.
                    Text("Aguardando pagamento real…")
                        .font(.system(size: 13))
                        .foregroundStyle(BlaxxColor.gray600)
                        .padding(.top, 6)
                    #endif
                }
            }
        }
    }

    private func summaryRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(BlaxxColor.gray600).font(.system(size: 13))
            Spacer()
            Text(v).font(.system(size: 14, weight: .semibold))
        }
    }

    private func qrPlaceholder(content: String) -> some View {
        // Sprint 3: se backend retornou data URI base64, renderiza o QR real.
        // Senão, gera local com CoreImage. Último fallback: placeholder.
        Group {
            if let img = qrImageFromCharge() {
                img.resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let img = qrImageFromString(content) {
                img.resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).stroke(
                        BlaxxColor.gray200,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                    VStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80, weight: .light))
                            .foregroundStyle(BlaxxColor.gray400)
                        Text("QR CODE")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(BlaxxColor.gray400)
                    }
                }
                .frame(width: 220, height: 220)
            }
        }
    }

    /// Tenta extrair imagem do `qr_code_image` (data URI base64) que o MP retorna.
    private func qrImageFromCharge() -> Image? {
        guard let s = charge?.qr_code_image,
              let comma = s.firstIndex(of: ","),
              let data = Data(base64Encoded: String(s[s.index(after: comma)...])) else {
            return nil
        }
        #if canImport(AppKit)
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        #endif
        #if canImport(UIKit)
        if let ui = UIImage(data: data) { return Image(uiImage: ui) }
        #endif
        return nil
    }

    /// Gera QR localmente a partir do BR Code (fallback se backend não mandou PNG).
    private func qrImageFromString(_ s: String) -> Image? {
        guard !s.isEmpty,
              let data = s.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ci = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(ci, from: ci.extent) else {
            return nil
        }
        #if canImport(AppKit)
        let ns = NSImage(cgImage: cg, size: NSSize(width: ci.extent.width, height: ci.extent.height))
        return Image(nsImage: ns)
        #elseif canImport(UIKit)
        return Image(uiImage: UIImage(cgImage: cg))
        #else
        return nil
        #endif
    }

    // MARK: - Sucesso

    private var successView: some View {
        VStack(spacing: 16) {
            SuccessTick()
            Eyebrow(text: "Compra aprovada")
            Text("Pontos creditados!")
                .font(BlaxxFont.display(32))
            Text("Sua carteira foi atualizada agora.")
                .foregroundStyle(BlaxxColor.gray600)
            HStack(spacing: 12) {
                Button("Comprar mais") {
                    resetPurchaseState()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Ver carteira") {
                    resetPurchaseState()
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Ações

    /// Limpa todo o estado de uma tentativa de compra (charge, polling, erro).
    /// Volta o usuário pra tela inicial de seleção de pacote/valor livre.
    private func resetPurchaseState() {
        pollTask?.cancel()
        pollTask = nil
        paid = false
        charge = nil
        customAmount = ""
        error = nil
    }

    private func loadPackages() async {
        loading = true
        defer { loading = false }
        do {
            packages = try await BlaxxAPI.shared.packages()
            // Detecta se backend está usando provider real ou mock
            if let info = try? await BlaxxAPI.shared.providerInfo() {
                isMockProvider = info.is_mock
            }
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    private func createCharge(_ pkg: String) async {
        do {
            let c = try await BlaxxAPI.shared.createCharge(package: pkg)
            charge = c
            // Confirmação automática via webhook MP — mesmo flow do valor livre.
            startPolling(chargeId: c.id)
        } catch {
            // Backend exige email verificado para /pix/charge. Se 403
            // EMAIL_NOT_VERIFIED, abre sheet de verificação e agenda retry.
            if isEmailVerificationError(error) {
                pendingRetry = { await createCharge(pkg) }
                showEmailVerifySheet = true
                return
            }
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    private func simulate(charge: PixChargeDTO) async {
        do {
            try await BlaxxAPI.shared.simulatePayment(chargeId: charge.id)
            paid = true
            // Notifica Dashboard/Carteira/Extrato para recarregarem do backend:
            // a compra cria uma Transaction tipo "purchase" no ledger.
            session.bumpWalletReload()
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    // MARK: - Format helpers

    private func formatBRL(_ v: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "pt_BR")
        return nf.string(from: NSNumber(value: v)) ?? "R$ \(v)"
    }
    private func formatPts(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    // MARK: - Valor livre (Onda 2)

    private var customAmountView: some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "Quanto você quer comprar?")
                Text("Valor livre via PIX")
                    .font(BlaxxFont.display(22))
                Text("Conversão: 1 ponto = R$ 0,09. Mínimo R$ 10,00.")
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray600)

                BlaxxField(label: "Valor em R$", value: $customAmount,
                           placeholder: "50,00",
                           hint: "Você vai receber \(previewPts()) pts")
                if let error {
                    Text(error).foregroundStyle(BlaxxColor.negative).font(.system(size: 12))
                }
                Button("Gerar QR Code de pagamento") {
                    Task { await createCustomMP() }
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .disabled(parsedAmount() < 10)
            }
        }
    }

    private func parsedAmount() -> Double {
        let s = customAmount.replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "R$", with: "")
            .trimmingCharacters(in: .whitespaces)
        return Double(s) ?? 0
    }

    // 1 ponto = R$ 0,09 = 9 centavos. Sincronizar com backend Config.CENTS_PER_POINT.
    private static let centsPerPoint = 9

    private func previewPts() -> String {
        let cents = Int(round(parsedAmount() * 100))
        let pts = cents / Self.centsPerPoint  // floor: centavos restantes ficam como house edge
        return formatPts(pts)
    }

    /// Cria charge via MP direto com valor livre, idêntico ao fluxo da Web.
    /// Backend gera QR Code real do Mercado Pago, e o webhook MP confirma
    /// automaticamente — não precisa mais admin/“Já paguei”.
    private func createCustomMP() async {
        do {
            let c = try await BlaxxAPI.shared.createCharge(amountBRL: parsedAmount())
            charge = c
            error = nil
            startPolling(chargeId: c.id)
        } catch let e {
            // Mesmo padrão de createCharge(pkg): 403 EMAIL_NOT_VERIFIED abre
            // a sheet de verificação e agenda retry preservando o valor.
            if isEmailVerificationError(e) {
                pendingRetry = { await createCustomMP() }
                showEmailVerifySheet = true
                return
            }
            if let api = e as? APIError {
                error = api.message
            } else {
                error = e.localizedDescription
            }
        }
    }

    /// Polling do status da charge a cada 4s. Encerra quando webhook MP
    /// marcar paid (sucesso) ou em expired/rejected (erro).
    private func startPolling(chargeId: String) {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { return }
                do {
                    let updated = try await BlaxxAPI.shared.getCharge(id: chargeId)
                    await MainActor.run {
                        charge = updated
                        if updated.status == "paid" {
                            paid = true
                            session.bumpWalletReload()
                            pollTask?.cancel()
                        } else if updated.status == "expired" || updated.status == "rejected" {
                            error = "Cobrança \(updated.status). Gere uma nova."
                            charge = nil
                            pollTask?.cancel()
                        }
                    }
                } catch {
                    // Falha de rede momentânea — tenta de novo no próximo tick.
                }
            }
        }
    }
}
