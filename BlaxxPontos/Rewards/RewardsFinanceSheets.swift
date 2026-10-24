#if BX_LEGADO_REWARDS   // desativado no redesenho Embarque de 22/10/2026. Não apagar sem decisão do dono (D14).
//
//  RewardsFinanceSheets.swift
//  BlaxxPontos
//
//  The three REAL-backend sheets layered over the mock Rewards world, styled to
//  match the prototype: Comprar (PIX buy), Vender (redeem → PIX cashback) and
//  Enviar (P2P transfer). Each operates against `RewardsBackend`, degrades
//  gracefully on failure, and carries the homologação disclaimer badge.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Shared helpers

private let rwMinPts = 1_000

/// Builds the PIX QR code: prefers the provider image (`qr_code_image`, a
/// base64 data URI from Mercado Pago); falls back to generating one locally
/// from the `br_code` payload (Mock / homologação, where the field is nil).
private func rwPixQR(for charge: PixChargeDTO) -> UIImage? {
    if let uri = charge.qr_code_image, let comma = uri.firstIndex(of: ",") {
        let b64 = String(uri[uri.index(after: comma)...])
        if let data = Data(base64Encoded: b64), let img = UIImage(data: data) {
            return img
        }
    }
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(charge.br_code.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    let context = CIContext()
    guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cg)
}

private func rwFmtBrl(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "pt_BR")
    return f.string(from: NSNumber(value: value)) ?? "R$ \(value)"
}

/// REQUIRED homologação disclaimer — visible em builds DEBUG/homologação;
/// retorna EmptyView em RELEASE para não aparecer ao usuário final.
/// O texto literal é preservado intencionalmente: a remoção de literais
/// quebra auditoria, então o gating fica só na renderização.
struct RWHomologBadge: View {
    var body: some View {
        if BuildConfig.isProduction {
            EmptyView()
        } else {
            HStack(spacing: 7) {
                Image(systemName: "flask")
                    .font(.system(size: 11, weight: .semibold))
                Text("Ambiente de homologação · PIX simulado · dados fictícios")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(RWColor.countdownFg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(RWColor.countdownBg)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Inline error chip (amber) used when a backend call fails.
struct RWSheetError: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(RWColor.amber)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RWColor.amber.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Plain text input styled like the prototype fields.
struct RWSheetInput: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(RWColor.muted))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(RWColor.ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(RWColor.searchBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// "Você recebe / vai pagar" dark display card (reuses the hero gradient).
private struct RWAmountCard: View {
    let caption: String
    let value: String
    let unit: String
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(RWColor.heroSub)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(BlaxxFont.display(30, weight: .bold))
                    .foregroundStyle(RWColor.neon)
                Text(unit)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xCFD3CB))
            }
            .padding(.top, 2)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(RWColor.heroSub)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Comprar (PIX buy)

struct RewardsBuySheet: View {
    let backend: RewardsBackend
    var onClose: () -> Void

    private enum Step { case select, pix, done }
    @State private var step: Step = .select
    @State private var packages: [PointPackageDTO] = []
    @State private var selectedKey: String?
    @State private var customBrl = ""
    @State private var charge: PixChargeDTO?
    @State private var qrImage: UIImage?
    @State private var busy = false
    @State private var error: String?
    /// `true` só quando o backend responde `GET /pix/provider` com `is_mock`.
    /// Gate da afordância de simulação — ver `pixStep`.
    @State private var providerIsMock = false

    private var customAmount: Double? {
        let cleaned = customBrl.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(cleaned), v > 0 else { return nil }
        return v
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RWGrabber()
                switch step {
                case .select: selectStep
                case .pix: pixStep
                case .done: doneStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .task {
            packages = (try? await backend.packages()) ?? []
            if selectedKey == nil { selectedKey = packages.first?.key }
            #if DEBUG
            // Só faz sentido perguntar em DEBUG: em release a afordância de
            // simulação não é renderizada de qualquer forma.
            providerIsMock = (try? await backend.providerInfo())?.is_mock ?? false
            #endif
        }
    }

    // Step 1 — choose package or custom amount.
    private var selectStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWSheetHeader(title: "Comprar pontos", onClose: onClose)

            RWFieldLabel(text: "Pacotes")
                .padding(.bottom, 9)
            VStack(spacing: 9) {
                ForEach(packages) { pkg in
                    packageRow(pkg)
                }
            }
            .padding(.bottom, 18)

            RWFieldLabel(text: "Ou valor personalizado")
                .padding(.bottom, 9)
            RWSheetInput(placeholder: "R$ 0,00", text: $customBrl, keyboard: .decimalPad)
                .padding(.bottom, 16)

            if let error { RWSheetError(message: error).padding(.bottom, 14) }

            RWCTA(title: busy ? "Gerando PIX…" : "Gerar PIX", disabled: busy || !canGenerate) {
                Task { await generate() }
            }
            .padding(.bottom, 14)
            RWHomologBadge()
        }
    }

    private var canGenerate: Bool { customAmount != nil || selectedKey != nil }

    private func packageRow(_ pkg: PointPackageDTO) -> some View {
        let selected = customAmount == nil && pkg.key == selectedKey
        return Button {
            selectedKey = pkg.key
            customBrl = ""
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pkg.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    Text("\(pkg.formattedPoints) pontos")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RWColor.chipPts)
                }
                Spacer()
                Text(pkg.formattedPrice)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(selected ? RWColor.greenLight : RWColor.ink)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(selected ? RWColor.chipSelBg : .white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? RWColor.neon : RWColor.chipBorder, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // Step 2 — PIX copia-e-cola + confirm.
    private var pixStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWBackHeader(title: "Pague com PIX") { step = .select }

            if let c = charge {
                RWAmountCard(
                    caption: "Você vai pagar",
                    value: rwFmtBrl(c.amount_brl),
                    unit: "",
                    footnote: "Crédito de \(RWFormat.n(c.points_to_credit)) pontos")
                    .padding(.bottom, 16)

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(RWColor.chipBorder, lineWidth: 1.5))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)
                }

                RWFieldLabel(text: "PIX copia e cola")
                    .padding(.bottom, 9)
                Text(c.br_code)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(RWColor.breakdownK)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(RWColor.simBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.bottom, 10)
                Button {
                    UIPasteboard.general.string = c.br_code
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "doc.on.doc")
                        Text("Copiar código")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RWColor.pctFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RWColor.pctBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)

                if let error { RWSheetError(message: error).padding(.bottom, 14) }

                // O CTA primário é o do fluxo REAL. "Simular pagamento" era o
                // primário e era renderizado incondicionalmente — inclusive em
                // release, onde `POST /pix/simulate-payment` responde 403
                // (`api/pix.py:327`): botão principal quebrado numa tela de
                // pagamento de verdade (achado N1, auditoria de 05/08).
                RWCTA(title: busy ? "Verificando…" : "Já paguei", disabled: busy) {
                    Task { await poll(c) }
                }
                .padding(.bottom, 14)

                #if DEBUG
                // Dois gates, como no backend: build de desenvolvimento E
                // provider mock. `RWHomologBadge` some em release, então
                // depender só dele deixaria o botão órfão do aviso.
                if providerIsMock {
                    RWCTA(title: busy ? "Confirmando…" : "Simular pagamento",
                          ghost: true, disabled: busy) {
                        Task { await simulate(c) }
                    }
                    .padding(.bottom, 14)
                }
                #endif

                RWHomologBadge()
            }
        }
    }

    // Step 3 — success.
    private var doneStep: some View {
        VStack(spacing: 0) {
            RWSuccessBadge().padding(.bottom, 22)
            Text("Pontos creditados!")
                .font(BlaxxFont.display(24, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Text("Seu saldo BlaXx já foi atualizado.")
                .font(.system(size: 13))
                .foregroundStyle(RWColor.chipPts)
                .padding(.top, 12)
            RWCTA(title: "Concluir") { onClose() }
                .padding(.top, 26)
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    // MARK: Actions

    private func generate() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            if let amount = customAmount {
                charge = try await backend.createCharge(amountBRL: amount)
            } else if let key = selectedKey {
                charge = try await backend.createCharge(package: key)
            }
            if let charge {
                qrImage = rwPixQR(for: charge)
                withAnimation { step = .pix }
            }
        } catch let e as APIError {
            error = e.message
        } catch is CancellationError {
            // ignore
        } catch {
            self.error = "Não foi possível gerar o PIX. Tente novamente."
        }
    }

    private func simulate(_ c: PixChargeDTO) async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await backend.simulatePayment(chargeId: c.id)
            await backend.refresh()
            withAnimation { step = .done }
        } catch let e as APIError {
            error = e.message
        } catch is CancellationError {
        } catch {
            self.error = "Falha ao confirmar o pagamento."
        }
    }

    private func poll(_ c: PixChargeDTO) async {
        busy = true; error = nil
        defer { busy = false }
        for _ in 0..<4 {
            if let updated = try? await backend.getCharge(id: c.id),
               updated.status.lowercased() == "paid" {
                await backend.refresh()
                withAnimation { step = .done }
                return
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        error = "Pagamento ainda não confirmado. Aguarde alguns instantes."
    }
}

// MARK: - Vender (redeem → PIX cashback)

struct RewardsSellSheet: View {
    let backend: RewardsBackend
    var onClose: () -> Void

    private enum Step { case form, done }
    @State private var step: Step = .form
    @State private var amount: Double = 0
    @State private var quote: RedeemQuoteDTO?
    @State private var busy = false
    @State private var error: String?
    /// Resultado do resgate. O status decide a tela final: com Asaas o caminho
    /// comum é `processing` (`services/redeem.py:203`), não `paid`.
    @State private var payout: RedeemResponse?

    private var available: Int { backend.balancePts ?? 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RWGrabber()
                switch step {
                case .form: formStep
                case .done: doneStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .task(id: amount) {
            guard Int(amount) >= rwMinPts else { quote = nil; return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            quote = try? await backend.redeemQuote(points: Int(amount))
        }
    }

    private var formStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWSheetHeader(title: "Vender pontos", onClose: onClose)

            if available < rwMinPts {
                emptyState
            } else {
                amountBlock
                    .padding(.bottom, 16)

                // Só o valor que cai na conta e quantos pontos saem. O rótulo
                // de cotação saiu por decisão de produto (12/08).
                RWAmountCard(
                    caption: "Você recebe via PIX",
                    value: quote.map { rwFmtBrl($0.amount_brl) } ?? "—",
                    unit: "",
                    footnote: quote.map { "\(RWFormat.n($0.points)) pontos" })
                    .padding(.bottom, 16)

                if let error { RWSheetError(message: error).padding(.bottom, 14) }

                RWCTA(title: busy ? "Processando…" : "Resgatar via PIX",
                      disabled: busy || Int(amount) < rwMinPts) {
                    Task { await redeem() }
                }
                .padding(.bottom, 14)
                RWHomologBadge()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wallet.pass")
                .font(.system(size: 34))
                .foregroundStyle(RWColor.muted)
            Text("Saldo insuficiente para resgate")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Text("É preciso ao menos \(RWFormat.n(rwMinPts)) pontos para resgatar via PIX.")
                .font(.system(size: 13))
                .foregroundStyle(RWColor.chipPts)
                .multilineTextAlignment(.center)
            RWCTA(title: "Entendi", ghost: true) { onClose() }
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                RWFieldLabel(text: "Quanto resgatar")
                Spacer()
                Text("disp. \(RWFormat.n(available))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RWColor.chipPts)
            }
            .padding(.bottom, 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(RWFormat.n(amount))
                    .font(BlaxxFont.display(30, weight: .bold))
                    .foregroundStyle(RWColor.ink)
                Text("pontos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RWColor.muted)
            }
            RWSlider(value: Binding(
                get: { amount },
                set: { amount = max(0, min($0, Double(available))) }),
                     range: 0...Double(max(1, available)))
            RWPctRow { pct in
                amount = (Double(available) * pct).rounded()
            }
        }
    }

    /// Copy final derivada de `payout.status`, espelhando a ramificação do PWA
    /// (`assets/blaxx-app.js:1811-1824`) — a mais completa das 5 plataformas:
    /// trata os quatro status e cai num texto neutro no desconhecido, em vez de
    /// afirmar conclusão. `requested` entra junto de `processing` porque
    /// também é estado não-final.
    private var doneCopy: (title: String, message: String, failed: Bool) {
        switch payout?.status.lowercased() {
        case "paid":
            return ("Resgate concluído!",
                    "O valor já foi enviado para a sua chave PIX.", false)
        case "processing", "requested":
            return ("Resgate em processamento",
                    "O PIX sai em até 1 dia útil. Acompanhe pelo extrato.", false)
        case "failed":
            let reason = payout?.failure_reason
            return ("Resgate não concluído",
                    reason.map { "\($0) — os pontos foram estornados." }
                        ?? "Os pontos foram estornados automaticamente.", true)
        case let other:
            return ("Resgate registrado",
                    other.map { "Status: \($0). Acompanhe pelo extrato." }
                        ?? "Acompanhe o andamento pelo extrato.", false)
        }
    }

    private var doneStep: some View {
        let copy = doneCopy
        return VStack(spacing: 0) {
            if copy.failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(RWColor.amber)
                    .frame(height: 88)
                    .padding(.bottom, 22)
                    .accessibilityLabel("Resgate não concluído")
            } else {
                RWSuccessBadge().padding(.bottom, 22)
            }
            Text(copy.title)
                .font(BlaxxFont.display(24, weight: .bold))
                .foregroundStyle(RWColor.ink)
                .multilineTextAlignment(.center)
            Text(copy.message)
                .font(.system(size: 13))
                .foregroundStyle(RWColor.chipPts)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            RWCTA(title: "Concluir") { onClose() }
                .padding(.top, 26)
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    private func redeem() async {
        // Exige biometria antes de uma operação financeira (resgate via PIX).
        let ok = await BiometricGate.authenticate(reason: "Confirmar resgate de pontos")
        guard ok else {
            error = "Autenticação cancelada"
            return
        }
        busy = true; error = nil
        defer { busy = false }
        do {
            payout = try await backend.redeem(points: Int(amount))
            await backend.refresh()
            withAnimation { step = .done }
        } catch let e as APIError {
            error = e.message
        } catch is CancellationError {
        } catch {
            self.error = "Não foi possível concluir o resgate."
        }
    }
}

// MARK: - Enviar (P2P transfer)

struct RewardsTransferSheet: View {
    let backend: RewardsBackend
    var onClose: () -> Void

    private enum Step { case form, done }
    @State private var step: Step = .form
    @State private var recipient = ""
    @State private var amount: Double = 0
    @State private var message = ""
    @State private var busy = false
    @State private var error: String?

    private var available: Int { backend.balancePts ?? 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                RWGrabber()
                switch step {
                case .form: formStep
                case .done: doneStep
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
    }

    private var formStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            RWSheetHeader(title: "Enviar pontos", onClose: onClose)

            RWFieldLabel(text: "Para (Cartão BlaXx, e-mail ou CPF)")
                .padding(.bottom, 9)
            RWSheetInput(placeholder: "XXXX XXXX, email ou CPF", text: $recipient)
                .padding(.bottom, 18)

            amountBlock
                .padding(.bottom, 18)

            RWFieldLabel(text: "Mensagem (opcional)")
                .padding(.bottom, 9)
            RWSheetInput(placeholder: "Ex.: Obrigado!", text: $message)
                .padding(.bottom, 16)

            if let error { RWSheetError(message: error).padding(.bottom, 14) }

            RWCTA(title: busy ? "Enviando…" : "Enviar pontos",
                  disabled: busy || !canSend) {
                Task { await send() }
            }
            .padding(.bottom, 14)
            RWHomologBadge()
        }
    }

    private var canSend: Bool {
        !recipient.trimmingCharacters(in: .whitespaces).isEmpty && Int(amount) >= 1 && Int(amount) <= available
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                RWFieldLabel(text: "Quanto enviar")
                Spacer()
                Text("disp. \(RWFormat.n(available))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RWColor.chipPts)
            }
            .padding(.bottom, 6)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(RWFormat.n(amount))
                    .font(BlaxxFont.display(30, weight: .bold))
                    .foregroundStyle(RWColor.ink)
                Text("pontos")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RWColor.muted)
            }
            RWSlider(value: Binding(
                get: { amount },
                set: { amount = max(0, min($0, Double(available))) }),
                     range: 0...Double(max(1, available)))
            RWPctRow { pct in
                amount = (Double(available) * pct).rounded()
            }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 0) {
            RWSuccessBadge().padding(.bottom, 22)
            Text("Pontos enviados!")
                .font(BlaxxFont.display(24, weight: .bold))
                .foregroundStyle(RWColor.ink)
            (Text("Você enviou ").foregroundColor(RWColor.breakdownK)
             + Text("\(RWFormat.n(amount)) pontos").foregroundColor(RWColor.ink).bold())
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            RWCTA(title: "Concluir") { onClose() }
                .padding(.top, 26)
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
    }

    private func send() async {
        // Biometria antes de transferir pontos para outro usuário.
        let ok = await BiometricGate.authenticate(reason: "Confirmar envio de pontos")
        guard ok else {
            error = "Autenticação cancelada"
            return
        }
        busy = true; error = nil
        defer { busy = false }
        let note = message.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await backend.transfer(
                to: recipient.trimmingCharacters(in: .whitespaces),
                amountPts: Int(amount),
                message: note.isEmpty ? nil : note)
            await backend.refresh()
            withAnimation { step = .done }
        } catch let e as APIError {
            error = e.message
        } catch is CancellationError {
        } catch {
            self.error = "Não foi possível enviar os pontos."
        }
    }
}

#endif
