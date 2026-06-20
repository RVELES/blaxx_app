//
//  AdaptiveLayout.swift
//  BlaxxPontos
//
//  Helpers para layouts que se adaptam entre iPhone (compact) e Mac/iPad (regular).
//

import SwiftUI

/// HStack em telas largas, VStack em telas estreitas (iPhone).
struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var spacing: CGFloat = 16
    var hAlignment: HorizontalAlignment = .leading
    var vAlignment: VerticalAlignment = .top
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isCompact {
            VStack(alignment: hAlignment, spacing: spacing, content: content)
        } else {
            HStack(alignment: vAlignment, spacing: spacing, content: content)
        }
    }

    var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }
}

/// Detecta se estamos em compact (iPhone retrato).
struct CompactReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let content: (Bool) -> Content

    var body: some View {
        #if os(iOS)
        content(sizeClass == .compact)
        #else
        content(false)
        #endif
    }
}
