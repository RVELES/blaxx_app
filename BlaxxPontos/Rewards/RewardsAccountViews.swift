//
//  RewardsAccountViews.swift
//  BlaxxPontos
//
//  Área logada do app, em paridade com o menu do PWA.
//
//  A taxonomia é a de `blaxx/assets/blaxx-nav.js` → `MENU_LOGADO`, item a item:
//
//      Conta      Início · Carteira · Extrato · Cartão BlaXx · Perfil
//      Pontos     Comprar · Enviar · Resgatar em dinheiro · Indique e ganhe
//      Descobrir  Parceiros · Campanhas
//      Ajuda      Central de ajuda · Perguntas frequentes · Abrir chamado
//
//  A troca entre programas (exchange) fica de fora por decisão do produto.
//
//  Navegação: este arquivo é um roteador próprio, com header e "voltar"
//  manuais, em vez de NavigationStack — a shell do Rewards não tem barra de
//  navegação e o visual é a assinatura Neo-Brutal, não a do sistema.
//

import SwiftUI

// MARK: - Rotas

enum RWAccountRoute: Hashable {
    case menu
    case perfil
    case extrato
    case cartao
    case notificacoes
    case campanhas
    case resgates
    case indique
    case seguranca
    case ajuda
    case faq
    case chamado
}

// MARK: - Roteador

struct RewardsAccountView: View {
    @Environment(RewardsBackend.self) private var backend
    var initialRoute: RWAccountRoute = .menu
    var onClose: () -> Void
    /// Ações que pertencem à shell (abrir sheet financeiro / trocar de aba).
    var onOpenBuy: () -> Void = {}
    var onOpenSell: () -> Void = {}
    var onOpenTransfer: () -> Void = {}
    var onOpenWallet: () -> Void = {}
    var onOpenPartners: () -> Void = {}

    @State private var route: RWAccountRoute = .menu
    /// Pilha de retorno: permite entrar em Extrato pelo menu e voltar pra ele,
    /// ou entrar em Notificações pelo sino e o "voltar" fechar a área.
    @State private var stack: [RWAccountRoute] = []

    var body: some View {
        ZStack {
            RWColor.screenBg.ignoresSafeArea()
            content
        }
        .onAppear { route = initialRoute }
    }

    @ViewBuilder
    private var content: some View {
        switch route {
        case .menu:
            RWAccountMenu(
                onClose: onClose,
                onSelect: { push($0) },
                onOpenBuy: onOpenBuy,
                onOpenSell: onOpenSell,
                onOpenTransfer: onOpenTransfer,
                onOpenWallet: onOpenWallet,
                onOpenPartners: onOpenPartners)
        case .perfil:
            RWProfileView(onBack: { pop() }, onSignOut: onClose)
        case .extrato:
            RWStatementView(onBack: { pop() })
        case .cartao:
            RWCardView(onBack: { pop() })
        case .notificacoes:
            RWNotificationsView(onBack: { pop() })
        case .campanhas:
            RWCampaignsView(onBack: { pop() })
        case .resgates:
            RWBenefitsView(onBack: { pop() })
        case .indique:
            RWReferralView(onBack: { pop() })
        case .seguranca:
            RWSecurityView(onBack: { pop() })
        case .ajuda:
            RWHelpView(onBack: { pop() }, onFaq: { push(.faq) }, onTicket: { push(.chamado) })
        case .faq:
            RWFaqView(onBack: { pop() })
        case .chamado:
            RWTicketView(onBack: { pop() })
        }
    }

    private func push(_ r: RWAccountRoute) {
        stack.append(route)
        withAnimation(.easeInOut(duration: 0.2)) { route = r }
    }

    /// Volta um nível; se não há para onde voltar (entrou direto pelo sino),
    /// fecha a área logada inteira.
    private func pop() {
        if let last = stack.popLast() {
            withAnimation(.easeInOut(duration: 0.2)) { route = last }
        } else {
            onClose()
        }
    }
}

// MARK: - Átomos compartilhados da área logada

/// Cabeçalho de tela com voltar. O título usa a display family, como os sheets.
struct RWScreenHeader: View {
    let title: String
    var trailing: AnyView? = nil
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(RWColor.ink)
                    .frame(width: 40, height: 40)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rwBrutalCard(corner: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            Text(title)
                .font(BlaxxFont.display(21, weight: .bold))
                .foregroundStyle(RWColor.ink)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.bottom, 16)
    }
}

/// Rótulo de grupo do menu (equivale ao `<p class="bxnav-grupo">` do PWA).
struct RWGroupLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(RWColor.fieldLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 18)
            .padding(.bottom, 8)
    }
}

/// Linha de navegação do menu.
struct RWNavRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var badge: Int = 0
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
                    .frame(width: 36, height: 36)
                    .background(RWColor.pctBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RWColor.ink)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(RWColor.ink)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RWColor.neon)
                        .clipShape(Capsule())
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RWColor.chipPts)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xC2C6BC))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .rwBrutalCard()
        }
        .buttonStyle(.plain)
    }
}

/// Estado vazio / carregando / erro, num único componente para as listas.
struct RWListState: View {
    enum Kind { case loading, empty, failed }
    let kind: Kind
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            switch kind {
            case .loading:
                ProgressView().tint(RWColor.greenLight)
            case .empty:
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundStyle(RWColor.muted)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(RWColor.amber)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(RWColor.chipPts)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

/// Datas do backend chegam como `datetime.isoformat()` — sem timezone e com
/// microssegundos. `ISO8601DateFormatter` recusa esse formato, então a lista
/// de tentativas abaixo é deliberada, do mais específico ao mais tolerante.
enum RWDate {
    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd",
    ]

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        for f in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(identifier: "UTC")
            df.dateFormat = f
            if let d = df.date(from: s) { return d }
        }
        return nil
    }

    /// "Hoje" / "Ontem" / "12 ago" — mesmo agrupamento do `extrato.html`.
    static func dayKey(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Hoje" }
        if cal.isDateInYesterday(d) { return "Ontem" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "d MMM"
        return df.string(from: d)
    }

    static func hhmm(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }

    static func short(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "dd/MM/yyyy"
        return df.string(from: d)
    }
}

// MARK: - Menu da conta

private struct RWAccountMenu: View {
    @Environment(RewardsBackend.self) private var backend
    var onClose: () -> Void
    var onSelect: (RWAccountRoute) -> Void
    var onOpenBuy: () -> Void
    var onOpenSell: () -> Void
    var onOpenTransfer: () -> Void
    var onOpenWallet: () -> Void
    var onOpenPartners: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Minha conta")
                        .font(BlaxxFont.display(24, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(RWColor.ink)
                            .frame(width: 40, height: 40)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .rwBrutalCard(corner: 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fechar")
                }
                .padding(.bottom, 4)

                identityCard

                RWGroupLabel(text: "Conta")
                VStack(spacing: 9) {
                    RWNavRow(icon: "wallet.pass", title: "Carteira") { onOpenWallet() }
                    RWNavRow(icon: "list.bullet.rectangle", title: "Extrato") { onSelect(.extrato) }
                    RWNavRow(icon: "creditcard", title: "Cartão BlaXx") { onSelect(.cartao) }
                    RWNavRow(icon: "person.crop.circle", title: "Perfil") { onSelect(.perfil) }
                    RWNavRow(icon: "bell", title: "Notificações") { onSelect(.notificacoes) }
                }

                RWGroupLabel(text: "Pontos")
                VStack(spacing: 9) {
                    RWNavRow(icon: "cart", title: "Comprar pontos") { onOpenBuy() }
                    RWNavRow(icon: "paperplane", title: "Enviar pontos") { onOpenTransfer() }
                    RWNavRow(icon: "arrow.down.circle", title: "Resgatar em dinheiro") { onOpenSell() }
                    RWNavRow(icon: "gift", title: "Resgatar com pontos") { onSelect(.resgates) }
                    RWNavRow(icon: "person.2", title: "Indique e ganhe") { onSelect(.indique) }
                }

                RWGroupLabel(text: "Descobrir")
                VStack(spacing: 9) {
                    RWNavRow(icon: "square.grid.2x2", title: "Parceiros") { onOpenPartners() }
                    RWNavRow(icon: "megaphone", title: "Campanhas") { onSelect(.campanhas) }
                }

                RWGroupLabel(text: "Ajuda")
                VStack(spacing: 9) {
                    RWNavRow(icon: "lifepreserver", title: "Central de ajuda") { onSelect(.ajuda) }
                    RWNavRow(icon: "questionmark.circle", title: "Perguntas frequentes") { onSelect(.faq) }
                    RWNavRow(icon: "envelope", title: "Abrir chamado") { onSelect(.chamado) }
                    RWNavRow(icon: "lock.shield", title: "Segurança") { onSelect(.seguranca) }
                }

                RWHomologBadge().padding(.top, 22)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
    }

    private var identityCard: some View {
        HStack(spacing: 13) {
            Text(String((backend.user?.name.prefix(1) ?? "?")).uppercased())
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(RWColor.neon)
                .frame(width: 52, height: 52)
                .background(RWColor.ink2)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(backend.user?.name ?? "Visitante")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(backend.cardIdFormatted.map { "Cartão \($0)" } ?? "Sem sessão ativa")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RWColor.heroSub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(backend.balancePts.map { RWFormat.n($0) } ?? "—")
                    .font(BlaxxFont.display(20, weight: .bold))
                    .foregroundStyle(RWColor.neon)
                Text("pontos")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(RWColor.heroSub)
            }
        }
        .padding(16)
        .background(RWColor.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .rwCardShadow()
    }
}

// MARK: - Perfil

private struct RWProfileView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void
    var onSignOut: () -> Void

    @State private var confirmDelete = false
    @State private var deletePassword = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Perfil", onBack: onBack)

                if let u = backend.user {
                    VStack(spacing: 9) {
                        infoRow("Nome", u.name)
                        infoRow("E-mail", u.email)
                        infoRow("CPF", maskCPF(u.cpf))
                        infoRow("Chave PIX", u.pix_key ?? "não cadastrada")
                        infoRow("Cartão BlaXx", backend.cardIdFormatted ?? "—")
                        infoRow("E-mail verificado", u.isEmailVerified ? "sim" : "não")
                    }
                } else {
                    RWListState(kind: .empty, message: "Entre na sua conta para ver o perfil.")
                }

                if let error { RWSheetError(message: error).padding(.top, 14) }

                RWCTA(title: "Sair da conta", ghost: true) {
                    backend.signOut()
                    onSignOut()
                }
                .padding(.top, 22)

                RWGroupLabel(text: "Zona de risco")
                Text("Excluir a conta apaga seus dados e o saldo de pontos. Não dá para desfazer.")
                    .font(.system(size: 12))
                    .foregroundStyle(RWColor.chipPts)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)

                if confirmDelete {
                    RWFieldLabel(text: "Confirme com a sua senha")
                        .padding(.bottom, 8)
                    SecureField("", text: $deletePassword,
                                prompt: Text("Senha").foregroundColor(RWColor.muted))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RWColor.ink)
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .background(RWColor.searchBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.bottom, 12)
                    RWCTA(title: busy ? "Excluindo…" : "Excluir definitivamente",
                          disabled: busy || deletePassword.isEmpty) {
                        Task { await deleteAccount() }
                    }
                    RWCTA(title: "Cancelar", ghost: true) {
                        confirmDelete = false; deletePassword = ""; error = nil
                    }
                    .padding(.top, 9)
                } else {
                    RWCTA(title: "Excluir minha conta", ghost: true) { confirmDelete = true }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }

    private func infoRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RWColor.breakdownK)
            Spacer(minLength: 14)
            Text(v)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RWColor.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }

    /// Mostra só os 3 últimos dígitos — o CPF inteiro não precisa ficar na tela.
    private func maskCPF(_ cpf: String) -> String {
        let digits = cpf.filter(\.isNumber)
        guard digits.count >= 3 else { return "•••" }
        return "•••.•••.\(digits.suffix(5).prefix(3))-••"
    }

    private func deleteAccount() async {
        busy = true; error = nil
        defer { busy = false }
        do {
            try await backend.deleteAccount(password: deletePassword)
            onSignOut()
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = "Não foi possível excluir a conta."
        }
    }
}

// MARK: - Segurança (troca de senha)

private struct RWSecurityView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void

    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var busy = false
    @State private var error: String?
    @State private var done = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Segurança", onBack: onBack)

                if done {
                    VStack(spacing: 0) {
                        RWSuccessBadge().padding(.bottom, 20)
                        Text("Senha alterada")
                            .font(BlaxxFont.display(22, weight: .bold))
                            .foregroundStyle(RWColor.ink)
                        Text("Use a senha nova no próximo acesso.")
                            .font(.system(size: 13))
                            .foregroundStyle(RWColor.chipPts)
                            .padding(.top, 10)
                        RWCTA(title: "Concluir") { onBack() }.padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Trocar a senha de acesso.")
                        .font(.system(size: 13))
                        .foregroundStyle(RWColor.chipPts)
                        .padding(.bottom, 16)

                    secureField("Senha atual", $current)
                    secureField("Nova senha", $new1)
                    secureField("Repita a nova senha", $new2)

                    if let error { RWSheetError(message: error).padding(.bottom, 12) }

                    RWCTA(title: busy ? "Salvando…" : "Salvar nova senha",
                          disabled: busy || !canSubmit) {
                        Task { await submit() }
                    }
                }

                RWGroupLabel(text: "Dispositivo")
                Text("O app exige biometria antes de resgatar ou enviar pontos. "
                     + "Encerrar a sessão remove o acesso deste aparelho.")
                    .font(.system(size: 12))
                    .foregroundStyle(RWColor.chipPts)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }

    private var canSubmit: Bool {
        !current.isEmpty && new1.count >= 8 && new1 == new2
    }

    private func secureField(_ placeholder: String, _ binding: Binding<String>) -> some View {
        SecureField("", text: binding,
                    prompt: Text(placeholder).foregroundColor(RWColor.muted))
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(RWColor.ink)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(RWColor.searchBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.bottom, 10)
    }

    private func submit() async {
        guard new1 == new2 else { error = "As senhas não conferem."; return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await backend.changePassword(current: current, new: new1)
            withAnimation { done = true }
        } catch let e as APIError {
            error = e.message
        } catch {
            self.error = "Não foi possível trocar a senha."
        }
    }
}

// MARK: - Indique e ganhe

private struct RWReferralView: View {
    @Environment(RewardsBackend.self) private var backend
    var onBack: () -> Void
    @State private var copied = false

    /// O PWA (`indique.html:133`) usa `user.referral_code` quando existe e cai
    /// num literal quando não. Como o `/auth/me` do backend ainda não devolve
    /// esse campo, o código aqui deriva do ID do cartão — estável por usuário e
    /// verificável, em vez de um texto fixo igual para todo mundo.
    private var code: String { backend.cardId ?? "BLAXX" }
    private var link: String { "https://blaxxpontos.com.br/cadastro?ref=\(code)" }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Indique e ganhe", onBack: onBack)

                Text("Compartilhe seu código. Quando alguém se cadastra por ele, "
                     + "vocês dois entram nas campanhas de indicação ativas.")
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.chipPts)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                VStack(alignment: .leading, spacing: 8) {
                    Text("SEU CÓDIGO")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(RWColor.heroSub)
                    Text(code)
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(RWColor.neon)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(RWColor.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .rwCardShadow()
                .padding(.bottom, 16)

                RWCTA(title: copied ? "Código copiado ✓" : "Copiar código") {
                    UIPasteboard.general.string = code
                    copied = true
                }
                .padding(.bottom, 10)

                ShareLink(item: link) {
                    Text("Compartilhar convite")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .rwBrutalCard()
                }

                Text("O programa de indicação ainda não credita pontos automaticamente — "
                     + "o backend não tem contador de indicações. O código serve para "
                     + "campanhas manuais.")
                    .font(.system(size: 11))
                    .foregroundStyle(RWColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }
}

// MARK: - Ajuda / FAQ / Chamado

private struct RWHelpView: View {
    var onBack: () -> Void
    var onFaq: () -> Void
    var onTicket: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Central de ajuda", onBack: onBack)

                VStack(spacing: 9) {
                    RWNavRow(icon: "questionmark.circle", title: "Perguntas frequentes") { onFaq() }
                    RWNavRow(icon: "envelope", title: "Abrir chamado") { onTicket() }
                }

                RWGroupLabel(text: "Como funciona")
                VStack(alignment: .leading, spacing: 12) {
                    helpItem("Comprar pontos",
                             "Gere um PIX no app, pague e os pontos entram na carteira assim que a cobrança é confirmada.")
                    helpItem("Enviar pontos",
                             "Envie para outro usuário por e-mail, CPF ou número do Cartão BlaXx. O envio pede biometria.")
                    helpItem("Resgatar em dinheiro",
                             "O valor sai por PIX para a chave cadastrada. O resgate exige CPF verificado.")
                    helpItem("Prazo do resgate",
                             "O PIX pode sair na hora ou em até 1 dia útil. A tela final mostra em qual dos dois estados o seu resgate está.")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }

    private func helpItem(_ t: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t).font(.system(size: 14, weight: .bold)).foregroundStyle(RWColor.ink)
            Text(b).font(.system(size: 13)).foregroundStyle(RWColor.breakdownK)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .rwBrutalCard()
    }
}

private struct RWFaqView: View {
    var onBack: () -> Void
    @State private var open: Int?

    /// Mesmas perguntas do `faq.html`, para a resposta não divergir por canal.
    private let items: [(String, String)] = [
        ("Quanto vale um ponto BlaXx?",
         "O valor de compra e o de resgate são definidos pela BlaXx e aparecem na tela antes de você confirmar qualquer operação."),
        ("Quanto tempo leva para os pontos entrarem?",
         "Na compra por PIX, assim que o pagamento é confirmado. Se demorar, o app continua checando e credita sozinho."),
        ("Posso resgatar qualquer quantidade?",
         "O resgate tem mínimo de 1.000 pontos e exige CPF verificado."),
        ("Os pontos expiram?",
         "Sim, em 730 dias. A expiração é registrada no extrato quando ocorre."),
        ("Como cancelo um envio de pontos?",
         "Envios entre usuários têm uma janela curta de cancelamento logo após a confirmação."),
        ("Meus dados estão seguros?",
         "O acesso usa token com expiração e o app pede biometria antes de operações financeiras."),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 9) {
                RWScreenHeader(title: "Perguntas frequentes", onBack: onBack)
                ForEach(items.indices, id: \.self) { i in
                    faqRow(i)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }

    private func faqRow(_ i: Int) -> some View {
        let isOpen = open == i
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { open = isOpen ? nil : i }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Text(items[i].0)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RWColor.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: isOpen ? "minus" : "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(RWColor.greenLight)
                }
                if isOpen {
                    Text(items[i].1)
                        .font(.system(size: 13))
                        .foregroundStyle(RWColor.breakdownK)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .rwBrutalCard()
        }
        .buttonStyle(.plain)
    }
}

private struct RWTicketView: View {
    var onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                RWScreenHeader(title: "Abrir chamado", onBack: onBack)

                // O `abrir-chamado.html` do PWA também não tem backend: não há
                // endpoint de chamados. Em vez de simular um formulário que não
                // envia nada, o app diz para onde escrever — e o botão abre o
                // app de e-mail de verdade.
                Text("Ainda não temos abertura de chamado dentro do app. "
                     + "Escreva para o suporte e responda com o número do seu "
                     + "Cartão BlaXx — ele identifica sua conta.")
                    .font(.system(size: 13))
                    .foregroundStyle(RWColor.breakdownK)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                if let url = URL(string: "mailto:suporte@blaxxpontos.com.br") {
                    Link(destination: url) {
                        Text("Escrever para o suporte")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(RWColor.neon)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(RWColor.ink2)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .rwCardShadow()
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 34)
        }
    }
}
