//
//  BXFormato.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Formatação pt-BR: pontos com separador de milhar ("32.480"), dinheiro SÓ para tarifa de pacote
//  e valor de cobrança ("R$ 470,00"), datas, tempo relativo, agrupamento por dia, máscaras.
//  Regra do dono: nunca formatar valor do ponto, saldo em R$ ou cotação.
//

import Foundation

nonisolated enum BXFormato {
    static let local = Locale(identifier: "pt_BR")
    private static let meses = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]

    private static var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = local
        c.timeZone = .current
        return c
    }

    // MARK: pontos

    /// "32.480"
    static func pontos(_ n: Int) -> String {
        n.formatted(.number.grouping(.automatic).locale(local))
    }

    /// "32.480 pts"
    static func pontosComUnidade(_ n: Int) -> String {
        "\(pontos(n)) pts"
    }

    /// "+1.234" / "−353" (sinal de menos tipográfico U+2212).
    static func pontosSinal(_ n: Int) -> String {
        n < 0 ? "\u{2212}\(pontos(-n))" : "+\(pontos(n))"
    }

    /// Leitura para o VoiceOver: "32.480 pontos" (nunca "pts").
    static func pontosFalados(_ n: Int) -> String {
        "\(pontos(n)) \(abs(n) == 1 ? "ponto" : "pontos")"
    }

    // MARK: dinheiro (só tarifa de pacote e valor de cobrança)

    /// "R$ 470,00" (espaço comum, não o NBSP do formatador).
    static func dinheiro(_ v: Decimal) -> String {
        v.formatted(.currency(code: "BRL").locale(local))
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    // MARK: datas

    /// "22/10/2026"
    static func data(_ d: Date) -> String {
        let c = calendario.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02ld/%02ld/%04ld", c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }

    /// "22 out · 14:05"
    static func dataHora(_ d: Date) -> String {
        let c = calendario.dateComponents([.day, .month, .hour, .minute], from: d)
        return "\(c.day ?? 0) \(meses[max(0, min(11, (c.month ?? 1) - 1))]) · " + String(format: "%02ld:%02ld", c.hour ?? 0, c.minute ?? 0)
    }

    /// "14:05"
    static func hora(_ d: Date) -> String {
        let c = calendario.dateComponents([.hour, .minute], from: d)
        return String(format: "%02ld:%02ld", c.hour ?? 0, c.minute ?? 0)
    }

    /// "agora", "há 5 min", "há 2 h", "há 3 d"
    static func relativo(_ d: Date, agora: Date = .now) -> String {
        let s = max(0, agora.timeIntervalSince(d))
        if s < 60 { return "agora" }
        if s < 3600 { return "há \(Int(s / 60)) min" }
        if s < 86_400 { return "há \(Int(s / 3600)) h" }
        return "há \(Int(s / 86_400)) d"
    }

    /// "Hoje", "Ontem", "12 out" (cabeçalho de grupo do extrato).
    static func dia(_ d: Date, agora: Date = .now) -> String {
        let cal = calendario
        if cal.isDate(d, inSameDayAs: agora) { return "Hoje" }
        if let ontem = cal.date(byAdding: .day, value: -1, to: agora), cal.isDate(d, inSameDayAs: ontem) { return "Ontem" }
        let c = cal.dateComponents([.day, .month, .year], from: d)
        let anoAtual = cal.component(.year, from: agora)
        let base = "\(c.day ?? 0) \(meses[max(0, min(11, (c.month ?? 1) - 1))])"
        return c.year == anoAtual ? base : "\(base) \(c.year ?? 0)"
    }

    /// Agrupa itens por dia, do mais recente para o mais antigo (rótulo de `dia(_:)`).
    static func agruparPorDia<T>(_ itens: [T], data: (T) -> Date, agora: Date = .now) -> [(rotulo: String, itens: [T])] {
        let cal = calendario
        let ordenados = itens.sorted { data($0) > data($1) }
        var grupos: [(Date, [T])] = []
        for item in ordenados {
            let inicio = cal.startOfDay(for: data(item))
            if let ultimo = grupos.last, ultimo.0 == inicio {
                grupos[grupos.count - 1].1.append(item)
            } else {
                grupos.append((inicio, [item]))
            }
        }
        return grupos.map { (dia($0.0, agora: agora), $0.1) }
    }

    // MARK: identificadores e máscaras

    /// Número do Cartão BlaXx: 8 primeiros hex do id, em dois blocos ("DE0A 11C2").
    static func cartao(_ id: String) -> String {
        let hex = id.uppercased().filter { $0.isHexDigit }
        let oito = String(hex.prefix(8))
        guard oito.count == 8 else { return oito }
        return "\(oito.prefix(4)) \(oito.suffix(4))"
    }

    /// "***.***.789-**" (só o 3º bloco visível). CPF incompleto vira "Não informado".
    static func cpfMascarado(_ cpf: String) -> String {
        let d = cpf.filter(\.isNumber)
        guard d.count == 11 else { return "Não informado" }
        let meio = d.dropFirst(6).prefix(3)
        return "***.***.\(meio)-**"
    }

    /// "+55 (••) •••••-1234"
    static func celularMascarado(_ tel: String) -> String {
        let d = tel.filter(\.isNumber)
        guard d.count >= 4 else { return "Não informado" }
        return "+55 (••) •••••-\(d.suffix(4))"
    }

    /// Aplica a máscara de CPF progressivamente: 000.000.000-00.
    static func mascaraCPF(_ s: String) -> String {
        let d = Array(s.filter(\.isNumber).prefix(11))
        var r = ""
        for (i, c) in d.enumerated() {
            if i == 3 || i == 6 { r.append(".") }
            if i == 9 { r.append("-") }
            r.append(c)
        }
        return r
    }

    /// Aplica a máscara de celular progressivamente: (00) 00000-0000.
    static func mascaraCelular(_ s: String) -> String {
        let d = Array(s.filter(\.isNumber).prefix(11))
        var r = ""
        for (i, c) in d.enumerated() {
            if i == 0 { r.append("(") }
            if i == 2 { r.append(") ") }
            if i == 7 { r.append("-") }
            r.append(c)
        }
        return r
    }

    /// Dígitos digitados em reais com centavos: "47000" → "R$ 470,00".
    static func mascaraDinheiro(_ s: String) -> String {
        let d = s.filter(\.isNumber)
        guard let centavos = Int(d.prefix(12)), centavos > 0 else { return "" }
        return dinheiro(Decimal(centavos) / 100)
    }

    /// Valor em reais a partir do texto mascarado ("R$ 470,00" → 470).
    static func decimalDeDinheiro(_ s: String) -> Decimal? {
        let d = s.filter(\.isNumber)
        guard let centavos = Int(d.prefix(12)) else { return nil }
        return Decimal(centavos) / 100
    }

    /// Pontos digitados com milhar: "12000" → "12.000".
    static func mascaraPontos(_ s: String) -> String {
        let d = s.filter(\.isNumber)
        guard let n = Int(d.prefix(9)) else { return "" }
        return pontos(n)
    }

    // MARK: ISO 8601

    /// Aceita com e sem fração de segundo, com "Z", com fuso e sem fuso (sem fuso = UTC, como o backend grava).
    static func iso8601(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        let comFracao = ISO8601DateFormatter()
        comFracao.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = comFracao.date(from: t) { return d }
        let semFracao = ISO8601DateFormatter()
        semFracao.formatOptions = [.withInternetDateTime]
        if let d = semFracao.date(from: t) { return d }
        // sem fuso: "2026-10-22T14:05:00(.123456)"
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        for formato in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = formato
            if let d = f.date(from: t) { return d }
        }
        return nil
    }
}
