//
//  ProtectedSnapshot.swift
//  BlaxxPontos
//
//  Cobre telas sensíveis (carteira, cartão, transferências, compra, resgate)
//  com um overlay opaco enquanto o app está em background ou inativo. Isso
//  evita que o snapshot capturado pelo iOS para o switcher mostre saldo,
//  PIX em andamento ou histórico financeiro do usuário.
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

private struct SnapshotOverlay: View {
    var body: some View {
        ZStack {
            // Fundo escuro com a marca para não vazar conteúdo financeiro
            // no snapshot do iOS App Switcher.
            BlaxxColor.black
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(BlaxxColor.lime)
                Text("BlaXx Pontos")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Conteúdo protegido")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

extension View {
    /// Aplica o overlay de proteção de snapshot quando o app vai pro background.
    func protectedSnapshot() -> some View {
        modifier(ProtectedSnapshotModifier())
    }
}
