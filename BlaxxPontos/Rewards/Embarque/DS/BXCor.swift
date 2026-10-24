//
//  BXCor.swift
//  BlaxxPontos · Design system "Embarque" (fundação G0)
//
//  Tokens de cor, valores exatos de blaxx/assets/blaxx-embarque.css (:root, linhas 42-64)
//  e das medidas computadas a 375 px (docs/redesenho/medidas-computadas-375.txt).
//
//  Regras do dono que este arquivo sustenta:
//  - neon (#59FD27) é PREENCHIMENTO sobre claro; como texto, só sobre `tinta` (use `.bxTextoNeon()`);
//  - o app fica claro (sem modo escuro), como o web; os tokens são semânticos, então um tema
//    futuro troca só este arquivo.
//  - `Color(bxHex:)` só pode ser usado aqui. Telas usam os tokens.
//

import SwiftUI

extension Color {
    /// Cor a partir de um inteiro 0xRRGGBB. Nome novo para não colidir com o `Color(hex:)` antigo.
    nonisolated init(bxHex: UInt32, opacidade: Double = 1) {
        self.init(.sRGB,
                  red: Double((bxHex >> 16) & 0xFF) / 255,
                  green: Double((bxHex >> 8) & 0xFF) / 255,
                  blue: Double(bxHex & 0xFF) / 255,
                  opacity: opacidade)
    }
}

nonisolated enum BXCor {
    // MARK: superfícies
    /// `--bx-bg`: chão de toda tela.
    static let chao        = Color(bxHex: 0xE4E1D9)
    /// `--bx-surface`: cartões, gaveta, campos, recibo.
    static let superficie  = Color(bxHex: 0xFBFAF7)
    /// `--bx-surface-2`: campo de busca, trilho, toque.
    static let superficie2 = Color(bxHex: 0xF4F2EC)
    /// `--bx-line`: contorno de 1 pt e picote.
    static let linha       = Color(bxHex: 0xD9D6CE)
    /// `--bx-leader`: pontilhado do recibo e tracejado de "Mais categorias".
    static let pontilhado  = Color(bxHex: 0xB9B6AE)

    // MARK: texto
    /// `--bx-grey`: texto secundário (AA no chão e no cartão).
    static let cinza       = Color(bxHex: 0x555860)
    /// `--bx-grey-soft`: só decoração, nunca texto.
    static let cinzaIcone  = Color(bxHex: 0x5F6168)
    /// `--bx-ink`: preto da marca.
    static let tinta       = Color(bxHex: 0x0A0B0E)
    /// `--bx-ink-2`: linha sobre preto.
    static let tinta2      = Color(bxHex: 0x2A2D35)
    /// `--bx-ink-3`: tracejado sobre preto.
    static let tinta3      = Color(bxHex: 0x3A3D46)
    /// `--bx-ink-muted`: texto secundário sobre preto; rótulo inativo da barra de abas.
    static let tintaApagada = Color(bxHex: 0x8A8D96)
    /// `--bx-bar-fg`: barra utilitária e legenda da cabeça do recibo.
    static let barraTexto  = Color(bxHex: 0xC9CBD1)
    /// Papel: texto principal sobre preto.
    static let papel       = Color(bxHex: 0xF4F2EC)

    // MARK: marca
    /// Neon oficial. Só preenchimento sobre claro; texto só sobre `tinta`.
    static let neon            = Color(bxHex: 0x59FD27)
    /// Botão neon pressionado (hover do web).
    static let neonPressionado = Color(bxHex: 0x4FE81F)
    /// Estado ativo do botão neon. Nunca texto.
    static let neonProfundo    = Color(bxHex: 0x5AB800)
    /// Fundo do chip "OLÁ, …".
    static let limaSuave       = Color(bxHex: 0xEEF7E2)
    /// Halo de foco dos campos.
    static let halo            = Color(bxHex: 0x59FD27, opacidade: 0.35)

    // MARK: status (fundo, texto)
    static let okFundo = Color(bxHex: 0xE4F5DA),     okTexto = Color(bxHex: 0x1F6B14)
    static let avisoFundo = Color(bxHex: 0xF7EFD6),  avisoTexto = Color(bxHex: 0x7A5A00)
    static let perigoFundo = Color(bxHex: 0xF6DFD6), perigoTexto = Color(bxHex: 0x9A2F15)
    static let infoFundo = Color(bxHex: 0xDCE8F3),   infoTexto = Color(bxHex: 0x1B4A80)

    // MARK: quadro preto
    static let quadroLinha = Color(bxHex: 0x1C1F25), quadroToque = Color(bxHex: 0x15171C)
    static let quadroRodape = Color(bxHex: 0x111318), quadroChip = Color(bxHex: 0x1A1D23)
    static let quadroApagado = Color(bxHex: 0x4A4D55)
    /// Fundo atrás da gaveta e das folhas.
    static let scrim = Color(bxHex: 0x0A0B0E, opacidade: 0.45)
    /// Pontilhado da faixa neon do recibo (`rgba(10,11,14,.35)`).
    static let pontilhadoSobreNeon = Color(bxHex: 0x0A0B0E, opacidade: 0.35)
    /// Borda do botão vazado sobre preto (`rgba(244,242,236,.35)`).
    static let bordaSobrePreto = Color(bxHex: 0xF4F2EC, opacidade: 0.35)

    // MARK: níveis do Cartão BlaXx
    /// Paleta LOCAL dos níveis. Nunca usar `tier.color`/`text_color` da API (o Black da API é o lima legado #C6FF00).
    /// bronze #CD7F32/tinta · prata #9AA0A6/tinta · ouro #D4AF37/tinta · black #0A0B0E/neon · vip #0A0B0E/papel.
    /// No "black", o texto neon é permitido porque o fundo é tinta.
    static func nivel(_ chave: String) -> (fundo: Color, texto: Color) {
        switch chave.lowercased() {
        case "bronze": return (Color(bxHex: 0xCD7F32), tinta)
        case "prata", "silver": return (Color(bxHex: 0x9AA0A6), tinta)
        case "ouro", "gold": return (Color(bxHex: 0xD4AF37), tinta)
        case "black": return (tinta, neon)
        case "vip", "blaxx_vip", "blaxx vip": return (tinta, papel)
        default: return (superficie2, tinta)
        }
    }
}
