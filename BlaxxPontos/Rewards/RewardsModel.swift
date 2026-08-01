//
//  RewardsModel.swift
//  BlaxxPontos
//
//  Data + session state for "BlaXx Rewards". PROGRAMS / CONTACTS / HISTORY /
//  OFFERS copied verbatim from the prototype <script>. Logic (trade calc, send
//  flow, balance mutation) ports the JS exactly.
//

import SwiftUI
import Observation

// MARK: - Data models

struct RWProgram: Identifiable {
    let id: String
    let name: String
    let logo: String        // text shown in the colored badge ("S", "azul", "LP"…)
    let bg: Color
    let fg: Color
    var balance: Double
    let perBlaxx: Double
    let brlPerK: Double
    let expiring: String?
    let bonus: Int          // featured-offer bonus percentage (0 when none)

    /// R$ equivalent: balance/1000 * brlPerK  (== JS `brl(p)`).
    var brl: Double { balance / 1000 * brlPerK }
}

struct RWContact: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initial: String
    let color: Color
}

struct RWTx: Identifiable {
    let id = UUID()
    let t: String       // title
    let d: String       // date string
    let pts: String     // already-formatted, with sign
    let isIn: Bool
    let icon: String    // SF Symbol name
}

// MARK: - Store

@Observable
final class RewardsStore {
    // Featured offers (have bonus) — same order/ids as JS OFFERS.
    let offerIds = ["smiles", "azul", "latam"]

    let bonusDefault = 0.08   // BONUS = 0.08

    var programs: [RWProgram] = [
        RWProgram(id: "smiles", name: "Smiles",     logo: "S",    bg: Color(hex: 0xFF6A00), fg: .white,               balance: 420000, perBlaxx: 1.0, brlPerK: 21, expiring: "12.000 expiram em 30 dias", bonus: 120),
        RWProgram(id: "azul",   name: "TudoAzul",   logo: "azul", bg: Color(hex: 0xEAF1FB), fg: Color(hex: 0x0F4C9A), balance: 310000, perBlaxx: 0.9, brlPerK: 19, expiring: nil,                          bonus: 80),
        RWProgram(id: "latam",  name: "LATAM Pass", logo: "LP",   bg: Color(hex: 0xF3ECFA), fg: Color(hex: 0x5B2A8C), balance: 280000, perBlaxx: 0.8, brlPerK: 18, expiring: "8.500 expiram em 21 dias",  bonus: 60),
        RWProgram(id: "livelo", name: "Livelo",     logo: "L",    bg: Color(hex: 0xE6007E), fg: .white,               balance: 160000, perBlaxx: 1.2, brlPerK: 23, expiring: nil,                          bonus: 0),
        RWProgram(id: "esfera", name: "Esfera",     logo: "E",    bg: Color(hex: 0xEC0000), fg: .white,               balance: 80000,  perBlaxx: 1.1, brlPerK: 24, expiring: nil,                          bonus: 0)
    ]

    let contacts: [RWContact] = [
        RWContact(name: "Marina Alves", handle: "@marina", initial: "M", color: Color(hex: 0x7C5CFC)),
        RWContact(name: "Rafael Costa", handle: "@rafa",   initial: "R", color: Color(hex: 0x0EA5E9)),
        RWContact(name: "Júlia Santos", handle: "@jusan",  initial: "J", color: Color(hex: 0xF0568C)),
        RWContact(name: "Bruno Lima",   handle: "@brunol", initial: "B", color: Color(hex: 0x16A34A))
    ]

    let history: [String: [RWTx]] = [
        "smiles": [
            RWTx(t: "Troca recebida de Livelo", d: "12 jun · 2026", pts: "+45.000",  isIn: true,  icon: "arrow.left.arrow.right"),
            RWTx(t: "Bônus de transferência",   d: "02 jun · 2026", pts: "+9.000",   isIn: true,  icon: "gift"),
            RWTx(t: "Resgate de passagem",      d: "21 mai · 2026", pts: "−120.000", isIn: false, icon: "airplane.departure")
        ],
        "azul": [
            RWTx(t: "Compra de pontos",         d: "08 jun · 2026", pts: "+60.000",  isIn: true,  icon: "cart"),
            RWTx(t: "Envio para Rafael Costa",  d: "30 mai · 2026", pts: "−25.000",  isIn: false, icon: "paperplane")
        ],
        "latam": [
            RWTx(t: "Troca recebida de Esfera", d: "15 jun · 2026", pts: "+30.000",  isIn: true,  icon: "arrow.left.arrow.right"),
            RWTx(t: "Bônus BlaXx",              d: "15 jun · 2026", pts: "+2.400",   isIn: true,  icon: "gift")
        ],
        "livelo": [
            RWTx(t: "Acúmulo cartão de crédito", d: "10 jun · 2026", pts: "+18.000", isIn: true, icon: "creditcard")
        ],
        "esfera": [
            RWTx(t: "Acúmulo investimentos",     d: "05 jun · 2026", pts: "+12.000", isIn: true, icon: "chart.line.uptrend.xyaxis")
        ]
    ]

    // MARK: Derived totals

    var totalPts: Double { programs.reduce(0) { $0 + $1.balance } }
    var totalBRL: Double { programs.reduce(0) { $0 + $1.balance / 1000 * $1.brlPerK } }

    // MARK: Lookups

    func index(ofId id: String) -> Int { programs.firstIndex { $0.id == id } ?? 0 }
    func program(id: String) -> RWProgram { programs.first { $0.id == id } ?? programs[0] }
    func offerExpiry(_ id: String) -> String { id == "smiles" ? "3" : id == "azul" ? "12" : "18" }
    func offerCountdown(_ id: String) -> String { id == "smiles" ? "2d 14h" : id == "azul" ? "11d 6h" : "17d 9h" }
    func tx(for id: String) -> [RWTx] { history[id] ?? [] }

    // MARK: Mutations

    /// Applies a confirmed trade: from -= amount, to += total.
    func applyTrade(fromIdx: Int, toIdx: Int, amount: Double, total: Double) {
        programs[fromIdx].balance -= amount
        programs[toIdx].balance += total
    }

    /// Applies a confirmed send: from -= amount.
    func applySend(fromIdx: Int, amount: Double) {
        programs[fromIdx].balance -= amount
    }
}

// MARK: - Trade calculation (ports JS trdCalc exactly)

struct RWTradeCalc {
    let from: RWProgram
    let to: RWProgram
    let rate: Double
    let amount: Double
    let base: Double
    let bonus: Double
    let total: Double

    /// rate = to.perBlaxx/from.perBlaxx; amount clamped to from.balance;
    /// base = round(amount*rate); bonus = round(base*bonusRate); total = base+bonus.
    init(from: RWProgram, to: RWProgram, requestedAmount: Double, bonusRate: Double) {
        self.from = from
        self.to = to
        self.rate = to.perBlaxx / from.perBlaxx
        let amt = min(requestedAmount, from.balance)
        self.amount = amt
        self.base = (amt * rate).rounded()
        self.bonus = (base * bonusRate).rounded()
        self.total = base + bonus
    }

    var rateLabel: String {
        "1.000 \(from.name) ≈ \(RWFormat.n(1000 * rate)) \(to.name)"
    }
}
