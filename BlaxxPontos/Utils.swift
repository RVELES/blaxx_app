//
//  Utils.swift
//  BlaxxPontos
//

import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
func copyToClipboard(_ s: String) {
    #if canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
    #elseif canImport(UIKit)
    UIPasteboard.general.string = s
    #endif
}
