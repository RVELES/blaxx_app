//
//  ProtectedSnapshot.swift
//  BlaxxPontos
//
//  Cobre telas sensíveis (carteira, cartão, transferências, compra, resgate)
//  com um overlay opaco enquanto o app está em background ou inativo. Isso
//  evita que o snapshot capturado pelo iOS para o switcher mostre saldo,
//  cobrança em andamento ou histórico financeiro do usuário.
//
//  Uso: `.protectedSnapshot()` em qualquer View sensível.
//

import SwiftUI

private struct ProtectedSnapshotModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay {
                if scenePhase != .active {
                    SnapshotOverlay()
                        .transition(.opacity)
                }
            }
    }
}

/// Redesenho "Embarque": fundo tinta oficial, wordmark da barra e "Conteúdo protegido" em papel.
private struct SnapshotOverlay: View {
    var body: some View {
        ZStack {
            // Fundo escuro com a marca para não vazar saldo, histórico ou códigos
            // no snapshot do iOS App Switcher.
            BXCor.tinta
                .ignoresSafeArea()
            VStack(spacing: 14) {
                BXWordmark(.barra, altura: 30)
                Text("Conteúdo protegido")
                    .bxFonte(.rotulo)
                    .foregroundStyle(BXCor.papel)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Aplica o overlay de proteção de snapshot quando o app vai pro background.
    func protectedSnapshot() -> some View {
        modifier(ProtectedSnapshotModifier())
    }
}
