//
//  CardView.swift
//  BlaxxPontos
//
//  Cartão Blaxx — níveis de cliente (loyalty tiers) + Apple Wallet (.pkpass).
//  Mostra o cartão com a cor do nível atual, o progresso até o próximo nível,
//  o catálogo dos 4 níveis e o botão "Adicionar à Apple Wallet".
//
//  O nível é definido pelos pontos acumulados (lifetime) e nunca cai ao
//  resgatar. O botão de Wallet só fica ativo quando o servidor tem o
//  certificado Pass Type ID configurado (card.wallet_pass_available).
//

import SwiftUI
import PassKit
#if canImport(AppKit)
import AppKit
#endif

struct CardView: View {
    @Environment(Session.self) private var session

    @State private var card: CardStateDTO?
    @State private var loading = true
    @State private var addingToWallet = false
    @State private var errorMsg: String?

    // Apple Wallet (iOS): controla a apresentação do PKAddPassesViewController.
    @State private var pendingPass: PKPass?
    @State private var showAddPass = false

    var body: some View {
        CompactReader { isCompact in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 16 : 28) {
                    if !isCompact {
                        Topbar(eyebrow: "Seu cartão", title: "Cartão Blaxx",
                               userName: session.user?.name ?? "?")
                    }

                    if loading {
                        ProgressView().padding()
                    } else if let card {
                        AdaptiveStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                cardFace(card, isCompact: isCompact)
                                walletButton(card)
                            }
                            tiersCatalog(card)
                        }
                    } else {
                        Text(errorMsg ?? "Não foi possível carregar o cartão.")
                            .foregroundStyle(BlaxxColor.gray400)
                    }
                }
                .padding(isCompact ? 16 : 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(BlaxxColor.gray50.ignoresSafeArea())
        .task { await load() }
        #if os(iOS)
        .sheet(isPresented: $showAddPass) {
            if let pendingPass {
                AddPassesSheet(pass: pendingPass)
            }
        }
        #endif
    }

    // MARK: - Cartão visual

    @ViewBuilder
    private func cardFace(_ card: CardStateDTO, isCompact: Bool) -> some View {
        let bg = Color(blaxxHex: card.tier.color) ?? BlaxxColor.black
        let fg = Color(blaxxHex: card.tier.text_color) ?? .white

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BlaXx")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
                Spacer()
                Text(card.tier.label)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .foregroundStyle(fg)
                    .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(formatNumber(card.balance_pts))
                    .font(BlaxxFont.display(isCompact ? 34 : 44))
                Text("pts")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(fg.opacity(0.85))
            }
            .foregroundStyle(fg)
            .padding(.top, 8)

            Text("\(card.member.name) · ID \(card.member.id)")
                .font(.system(size: 12))
                .foregroundStyle(fg.opacity(0.85))

            if let next = card.next_tier {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Acumulado: \(formatNumber(card.lifetime_points)) pts")
                        Spacer()
                        Text("Faltam \(formatNumber(card.points_to_next)) p/ \(next.label)")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.9))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.22))
                            Capsule().fill(fg)
                                .frame(width: geo.size.width * CGFloat(card.progress_pct) / 100)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 12)
            } else {
                Text("Nível máximo · \(formatNumber(card.lifetime_points)) pts acumulados")
                    .font(.system(size: 11))
                    .foregroundStyle(fg.opacity(0.9))
                    .padding(.top, 12)
            }
        }
        .padding(isCompact ? 18 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18).fill(bg)
        )
    }

    // MARK: - Botão Apple Wallet

    @ViewBuilder
    private func walletButton(_ card: CardStateDTO) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await addToWallet() }
            } label: {
                HStack {
                    if addingToWallet {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wallet.pass.fill")
                    }
                    Text(card.wallet_pass_available
                         ? "Adicionar à Apple Wallet"
                         : "Apple Wallet · em breve")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(addingToWallet || !card.wallet_pass_available)

            if !card.wallet_pass_available {
                Text("O cartão na carteira do iPhone será habilitado assim que o certificado da Apple for configurado no servidor.")
                    .font(.system(size: 12))
                    .foregroundStyle(BlaxxColor.gray600)
            }
        }
    }

    // MARK: - Catálogo de níveis

    @ViewBuilder
    private func tiersCatalog(_ card: CardStateDTO) -> some View {
        BlaxxCard {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "Programa de níveis")
                Text("Como você evolui")
                    .font(BlaxxFont.display(20))
                    .foregroundStyle(BlaxxColor.black)
                Text("Seu nível é definido pelos pontos acumulados (vitalício) e nunca cai ao resgatar.")
                    .font(.system(size: 13))
                    .foregroundStyle(BlaxxColor.gray600)

                ForEach(card.tiers) { t in
                    let active = t.key == card.tier.key
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(blaxxHex: t.color) ?? BlaxxColor.gray400)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(BlaxxColor.gray200, lineWidth: 0.5))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(t.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(BlaxxColor.black)
                                Spacer()
                                Text(t.key == "vip" ? "Por convite" : "\(formatNumber(t.min_points))+ pts")
                                    .font(.system(size: 12))
                                    .foregroundStyle(BlaxxColor.gray600)
                            }
                            if let perks = t.perks {
                                Text(perks)
                                    .font(.system(size: 12))
                                    .foregroundStyle(BlaxxColor.gray600)
                            }
                        }
                        if active {
                            Text("atual")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(BlaxxColor.limeLight)
                                .foregroundStyle(BlaxxColor.limeDark)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(active ? BlaxxColor.limeLight.opacity(0.5) : BlaxxColor.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(active ? BlaxxColor.limeDark.opacity(0.5) : BlaxxColor.gray200,
                                    lineWidth: active ? 1 : 0.5)
                    )
                }
            }
        }
    }

    // MARK: - Ações

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            card = try await BlaxxAPI.shared.card()
        } catch is CancellationError {
            // View dismissed antes de terminar — ignora.
        } catch {
            errorMsg = (error as? APIError)?.message ?? error.localizedDescription
        }
    }

    private func addToWallet() async {
        guard card?.wallet_pass_available == true else { return }
        addingToWallet = true
        defer { addingToWallet = false }
        do {
            let data = try await BlaxxAPI.shared.walletPass()
            #if os(iOS)
            let pass = try PKPass(data: data)
            pendingPass = pass
            showAddPass = true
            #else
            // macOS: salva o .pkpass e abre no app padrão (Wallet via iCloud /
            // Preview), já que PKAddPassesViewController é iOS-only.
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("cartao-blaxx.pkpass")
            try data.write(to: url)
            NSWorkspace.shared.open(url)
            #endif
        } catch let apiErr as APIError where apiErr.status == 503 {
            errorMsg = "Apple Wallet ainda não disponível — em breve."
        } catch {
            errorMsg = "Falha ao gerar o cartão: \((error as? APIError)?.message ?? error.localizedDescription)"
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.groupingSeparator = "."
        return nf.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Apple Wallet add-pass sheet (iOS)

#if os(iOS)
private struct AddPassesSheet: UIViewControllerRepresentable {
    let pass: PKPass

    func makeUIViewController(context: Context) -> PKAddPassesViewController {
        PKAddPassesViewController(pass: pass) ?? PKAddPassesViewController()
    }

    func updateUIViewController(_ vc: PKAddPassesViewController, context: Context) {}
}
#endif

// MARK: - Color a partir de hex ("#RRGGBB")

extension Color {
    /// Inicializa a partir de uma string hex do backend (ex.: "#0B0B0C").
    /// Retorna nil se o formato for inválido — o caller usa um fallback.
    init?(blaxxHex hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8) / 255,
            blue: Double(v & 0x0000FF) / 255
        )
    }
}
