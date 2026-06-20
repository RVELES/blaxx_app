//
//  BlaxxPontosApp.swift
//  BlaxxPontos
//

import SwiftUI
import SwiftData

@main
struct BlaxxPontosApp: App {
    @State private var session = Session()

    // Token de recuperação recebido por deep link
    // (`blaxxpontos://redefinir-senha?token=…`). Quando não-nil, ContentView
    // apresenta a ResetPasswordView por cima de qualquer tela.
    @State private var resetToken: String?

    let modelContainer: ModelContainer = {
        let schema = Schema([CachedWallet.self, CachedTransaction.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("ModelContainer fallback in-memory: \(error)")
            let inMem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [inMem])
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                #if os(macOS)
                .frame(minWidth: 1080, minHeight: 700)
                #endif
                .sheet(item: Binding(
                    get: { resetToken.map { ResetTokenWrapper(token: $0) } },
                    set: { resetToken = $0?.token }
                )) { wrapper in
                    ResetPasswordView(token: wrapper.token)
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }

    /// Trata deep links `blaxxpontos://redefinir-senha?token=…` (e o alias
    /// `reset`). O backend envia o link web `…/redefinir-senha.html?token=…`;
    /// para abrir no app nativo usamos o esquema custom registrado no Info.plist.
    private func handleDeepLink(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let host = comps.host ?? ""
        let path = comps.path
        let isReset = host.contains("redefinir-senha") || host == "reset"
            || path.contains("redefinir-senha") || path.contains("reset")
        guard isReset,
              let token = comps.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }
        resetToken = token
    }
}

/// Wrapper Identifiable para usar o token com `.sheet(item:)`.
private struct ResetTokenWrapper: Identifiable {
    let token: String
    var id: String { token }
}
