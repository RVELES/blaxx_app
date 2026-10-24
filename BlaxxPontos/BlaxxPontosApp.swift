//
//  BlaxxPontosApp.swift
//  BlaxxPontos
//
//  Redesenho "Embarque" (22/10/2026): a raiz é `ContentView` → `BXRaiz` (Rewards/Telas/Casca), que trata os
//  deep links (`blaxxpontos://redefinir-senha?token=…`, `blaxxpontos://enviar?para=…`) e pede push só depois
//  do login (D12). Nada de rede no lançamento além do que a sessão precisa.
//

import SwiftUI
import SwiftData

@main
struct BlaxxPontosApp: App {
    /// Sessão do app antigo: só o `legacyBody` (fora do iOS) usa. No iOS a sessão é `BXSessao`.
    @State private var session = Session()

    // App delegate pra receber callbacks de APNs (deviceToken / didFail).
    #if os(iOS)
    @UIApplicationDelegateAdaptor(BlaxxAppDelegate.self) private var appDelegate
    #endif

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
                // Cobre toda a árvore de views com overlay opaco quando o app
                // sai de .active — protege o snapshot do App Switcher contra
                // exposição de saldo, histórico e códigos.
                #if os(iOS)
                .protectedSnapshot()
                #endif
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
