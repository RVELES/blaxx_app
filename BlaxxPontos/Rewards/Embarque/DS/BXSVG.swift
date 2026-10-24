//
//  BXSVG.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Parser mínimo de SVG → `Path` do SwiftUI, usado pelos 57 ícones (docs/redesenho/icones.json
//  + 6 desenhos inline do web) e pelo wordmark (blaxx/assets/marca/*.svg).
//
//  Suporta:
//  - elementos `<path d>`, `<rect x y width height rx ry>`, `<circle cx cy r>`, `<ellipse cx cy rx ry>`;
//  - comandos `M m L l H h V v C c S s Q q T t A a Z z`, números colados (`.5.5`, `-1.4-2`),
//    expoente, comandos implícitos repetidos e flags de arco coladas;
//  - arcos convertidos da parametrização de ponto final para centro (SVG 1.1, F.6.5)
//    e aproximados por cúbicas de no máximo 90°;
//  - atributos `fill` (none | currentColor | #RRGGBB), `stroke` (none | currentColor | #RRGGBB),
//    `stroke-width`, `stroke-dasharray`, `fill-rule="evenodd"`.
//  Ordem de pintura: traço e depois preenchimento (é o `paint-order="stroke"` do wordmark claro;
//  nenhum ícone tem os dois ao mesmo tempo).
//

import SwiftUI

nonisolated enum BXSVG {

    enum Pintura: Sendable, Equatable {
        case corAtual
        case cor(Color)
    }

    struct Elemento: Sendable {
        let path: Path
        let preenchimento: Pintura?
        let traco: Pintura?
        let larguraTraco: CGFloat?
        let tracejado: [CGFloat]?
        let parOuImpar: Bool

        /// Atalho do contrato (§1.4): elemento só preenchido.
        var preenchido: Bool { preenchimento != nil && traco == nil }
    }

    // MARK: elementos

    /// Lê os elementos de um trecho de SVG.
    /// - Parameter tracoPadrao: `true` para ícones (o `<svg>` raiz do web tem `fill="none" stroke="currentColor"`),
    ///   `false` para a marca (sem traço por padrão, preenchimento pelo próprio arquivo).
    static func elementos(_ svg: String, tracoPadrao: Bool) -> [Elemento] {
        var saida: [Elemento] = []
        for pedaco in svg.components(separatedBy: "<").dropFirst() {
            let nome = pedaco.prefix { $0.isLetter }
            guard ["path", "rect", "circle", "ellipse"].contains(String(nome)) else { continue }
            let attrs = atributos(String(pedaco.dropFirst(nome.count)))
            func num(_ k: String) -> CGFloat { CGFloat(Double(attrs[k] ?? "") ?? 0) }

            let p: Path
            switch nome {
            case "path":
                p = path(attrs["d"] ?? "")
            case "rect":
                let r = CGRect(x: num("x"), y: num("y"), width: num("width"), height: num("height"))
                let rx = attrs["rx"] != nil ? num("rx") : (attrs["ry"] != nil ? num("ry") : 0)
                let ry = attrs["ry"] != nil ? num("ry") : rx
                p = (rx > 0 || ry > 0)
                    ? Path(roundedRect: r, cornerSize: CGSize(width: rx, height: ry), style: .circular)
                    : Path(r)
            case "circle":
                let r = num("r")
                p = Path(ellipseIn: CGRect(x: num("cx") - r, y: num("cy") - r, width: 2 * r, height: 2 * r))
            default: // ellipse
                let rx = num("rx"), ry = num("ry")
                p = Path(ellipseIn: CGRect(x: num("cx") - rx, y: num("cy") - ry, width: 2 * rx, height: 2 * ry))
            }

            let preenchimento: Pintura?
            if let f = attrs["fill"] { preenchimento = pintura(f) } else { preenchimento = tracoPadrao ? nil : .corAtual }
            let traco: Pintura?
            if let s = attrs["stroke"] { traco = pintura(s) } else { traco = (tracoPadrao && attrs["fill"] == nil) ? .corAtual : nil }

            let largura = attrs["stroke-width"].flatMap { Double($0) }.map { CGFloat($0) }
            let tracejado = attrs["stroke-dasharray"].map { numeros($0) }
            saida.append(Elemento(path: p,
                                  preenchimento: preenchimento,
                                  traco: traco,
                                  larguraTraco: largura,
                                  tracejado: tracejado,
                                  parOuImpar: attrs["fill-rule"] == "evenodd"))
        }
        return saida
    }

    /// `none` → nil (sem pintura), `currentColor` → cor atual, `#RRGGBB` → cor do arquivo.
    private static func pintura(_ v: String) -> Pintura? {
        let t = v.trimmingCharacters(in: .whitespaces)
        if t == "none" { return nil }
        if t.hasPrefix("#"), let hex = UInt32(t.dropFirst(), radix: 16), t.count == 7 {
            return .cor(Color(bxHex: hex))
        }
        return .corAtual
    }

    /// Lê `nome="valor"` de um elemento (aspas duplas, como nos arquivos do web).
    static func atributos(_ s: String) -> [String: String] {
        var r: [String: String] = [:]
        var resto = Substring(s)
        while let igual = resto.firstIndex(of: "=") {
            let nome = resto[..<igual].split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).last.map(String.init) ?? ""
            let depois = resto[resto.index(after: igual)...]
            guard let abre = depois.firstIndex(of: "\""),
                  let fecha = depois[depois.index(after: abre)...].firstIndex(of: "\"") else { break }
            r[nome] = String(depois[depois.index(after: abre)..<fecha])
            resto = depois[depois.index(after: fecha)...]
        }
        return r
    }

    private static func numeros(_ s: String) -> [CGFloat] {
        var l = Leitor(s)
        var r: [CGFloat] = []
        while let n = l.numero() { r.append(n) }
        return r
    }

    // MARK: path

    /// Converte o atributo `d` em `Path` (coordenadas do viewBox).
    static func path(_ d: String) -> Path {
        var p = Path()
        var l = Leitor(d)
        var atual = CGPoint.zero
        var inicio = CGPoint.zero
        var ultimoControleC: CGPoint? = nil   // para S/s
        var ultimoControleQ: CGPoint? = nil   // para T/t
        var cmd: Character? = nil

        while true {
            l.pularSeparadores()
            guard let c = l.atual else { break }
            if c.isLetter {
                cmd = c
                l.avancar()
            } else if cmd == nil {
                break
            }
            guard let comando = cmd else { break }
            let rel = comando.isLowercase
            var novoControleC: CGPoint? = nil
            var novoControleQ: CGPoint? = nil

            switch comando {
            case "M", "m":
                guard let x = l.numero(), let y = l.numero() else { return p }
                let pt = rel ? CGPoint(x: atual.x + x, y: atual.y + y) : CGPoint(x: x, y: y)
                p.move(to: pt)
                atual = pt; inicio = pt
                cmd = rel ? "l" : "L"   // pares seguintes são linhas implícitas
            case "L", "l":
                guard let x = l.numero(), let y = l.numero() else { return p }
                let pt = rel ? CGPoint(x: atual.x + x, y: atual.y + y) : CGPoint(x: x, y: y)
                p.addLine(to: pt); atual = pt
            case "H", "h":
                guard let x = l.numero() else { return p }
                let pt = CGPoint(x: rel ? atual.x + x : x, y: atual.y)
                p.addLine(to: pt); atual = pt
            case "V", "v":
                guard let y = l.numero() else { return p }
                let pt = CGPoint(x: atual.x, y: rel ? atual.y + y : y)
                p.addLine(to: pt); atual = pt
            case "C", "c":
                guard let x1 = l.numero(), let y1 = l.numero(), let x2 = l.numero(), let y2 = l.numero(),
                      let x = l.numero(), let y = l.numero() else { return p }
                let o = rel ? atual : .zero
                let c1 = CGPoint(x: o.x + x1, y: o.y + y1)
                let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                let pt = CGPoint(x: o.x + x, y: o.y + y)
                p.addCurve(to: pt, control1: c1, control2: c2)
                atual = pt; novoControleC = c2
            case "S", "s":
                guard let x2 = l.numero(), let y2 = l.numero(), let x = l.numero(), let y = l.numero() else { return p }
                let o = rel ? atual : .zero
                let c1 = ultimoControleC.map { CGPoint(x: 2 * atual.x - $0.x, y: 2 * atual.y - $0.y) } ?? atual
                let c2 = CGPoint(x: o.x + x2, y: o.y + y2)
                let pt = CGPoint(x: o.x + x, y: o.y + y)
                p.addCurve(to: pt, control1: c1, control2: c2)
                atual = pt; novoControleC = c2
            case "Q", "q":
                guard let x1 = l.numero(), let y1 = l.numero(), let x = l.numero(), let y = l.numero() else { return p }
                let o = rel ? atual : .zero
                let c1 = CGPoint(x: o.x + x1, y: o.y + y1)
                let pt = CGPoint(x: o.x + x, y: o.y + y)
                p.addQuadCurve(to: pt, control: c1)
                atual = pt; novoControleQ = c1
            case "T", "t":
                guard let x = l.numero(), let y = l.numero() else { return p }
                let o = rel ? atual : .zero
                let c1 = ultimoControleQ.map { CGPoint(x: 2 * atual.x - $0.x, y: 2 * atual.y - $0.y) } ?? atual
                let pt = CGPoint(x: o.x + x, y: o.y + y)
                p.addQuadCurve(to: pt, control: c1)
                atual = pt; novoControleQ = c1
            case "A", "a":
                guard let rx = l.numero(), let ry = l.numero(), let rot = l.numero(),
                      let grande = l.flag(), let horario = l.flag(),
                      let x = l.numero(), let y = l.numero() else { return p }
                let pt = rel ? CGPoint(x: atual.x + x, y: atual.y + y) : CGPoint(x: x, y: y)
                arco(&p, de: atual, para: pt, rx: rx, ry: ry, rotacaoGraus: rot, grande: grande, horario: horario)
                atual = pt
            case "Z", "z":
                p.closeSubpath()
                atual = inicio
                cmd = nil
            default:
                return p
            }
            ultimoControleC = novoControleC
            ultimoControleQ = novoControleQ
        }
        return p
    }

    /// Arco elíptico (SVG 1.1, apêndice F.6.5) aproximado por cúbicas de até 90°.
    static func arco(_ p: inout Path, de p0: CGPoint, para p1: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat,
                     rotacaoGraus: CGFloat, grande: Bool, horario: Bool) {
        if p0 == p1 { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { p.addLine(to: p1); return }
        let phi = rotacaoGraus * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p = cosP * dx2 + sinP * dy2
        let y1p = -sinP * dx2 + cosP * dy2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = lambda.squareRoot(); rx *= s; ry *= s }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = (grande != horario ? 1 : -1) * (den == 0 ? 0 : max(0, num / den).squareRoot())
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2

        func angulo(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = (ux * ux + uy * uy).squareRoot() * (vx * vx + vy * vy).squareRoot()
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let theta1 = angulo(1, 0, ux, uy)
        var dtheta = angulo(ux, uy, vx, vy)
        if !horario && dtheta > 0 { dtheta -= 2 * .pi } else if horario && dtheta < 0 { dtheta += 2 * .pi }

        let segmentos = max(1, Int((abs(dtheta) / (.pi / 2)).rounded(.up)))
        let delta = dtheta / CGFloat(segmentos)
        let t = 4.0 / 3.0 * tan(delta / 4)
        func ponto(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * u * cosP - ry * v * sinP, y: cy + rx * u * sinP + ry * v * cosP)
        }
        var a1 = theta1
        for i in 0..<segmentos {
            let a2 = a1 + delta
            let c1 = cos(a1), s1 = sin(a1), c2 = cos(a2), s2 = sin(a2)
            let fim = i == segmentos - 1 ? p1 : ponto(c2, s2)
            p.addCurve(to: fim,
                       control1: ponto(c1 - t * s1, s1 + t * c1),
                       control2: ponto(c2 + t * s2, s2 - t * c2))
            a1 = a2
        }
    }

    // MARK: leitor de números

    struct Leitor {
        private let c: [Character]
        private var i = 0
        init(_ s: String) { c = Array(s) }

        var atual: Character? { i < c.count ? c[i] : nil }
        mutating func avancar() { i += 1 }

        mutating func pularSeparadores() {
            while i < c.count, c[i] == " " || c[i] == "," || c[i] == "\n" || c[i] == "\t" || c[i] == "\r" { i += 1 }
        }

        /// Número SVG: sinal, dígitos, um ponto, expoente. Para no segundo ponto ou num sinal novo.
        mutating func numero() -> CGFloat? {
            pularSeparadores()
            let ini = i
            if i < c.count, c[i] == "-" || c[i] == "+" { i += 1 }
            var digitos = false, ponto = false
            while i < c.count {
                let ch = c[i]
                if ch.isASCII && ch.isNumber { digitos = true; i += 1 }
                else if ch == "." && !ponto { ponto = true; i += 1 }
                else { break }
            }
            if digitos, i < c.count, c[i] == "e" || c[i] == "E" {
                var j = i + 1
                if j < c.count, c[j] == "-" || c[j] == "+" { j += 1 }
                if j < c.count, c[j].isASCII, c[j].isNumber {
                    i = j
                    while i < c.count, c[i].isASCII, c[i].isNumber { i += 1 }
                }
            }
            guard digitos, let v = Double(String(c[ini..<i])) else { i = ini; return nil }
            return CGFloat(v)
        }

        /// Flag de arco: um único caractere `0` ou `1` (pode vir colado ao próximo número).
        mutating func flag() -> Bool? {
            pularSeparadores()
            guard i < c.count else { return nil }
            if c[i] == "0" { i += 1; return false }
            if c[i] == "1" { i += 1; return true }
            return nil
        }
    }
}

// MARK: - Vista

/// Desenha elementos de SVG num retângulo, mantendo a proporção do viewBox (centralizado).
/// Uso interno do design system (ícones e marca). Telas usam `BXIcone` e `BXWordmark`.
struct BXSVGVista: View {
    let elementos: [BXSVG.Elemento]
    let caixa: CGRect
    var corAtual: Color = BXCor.tinta
    /// Largura de traço padrão em unidades do viewBox (1,8 nos ícones).
    var tracoPadrao: CGFloat = 1.8
    /// Desenha todo preenchimento como traço cheio (ex.: coração preenchido do favorito).
    var preencherTracos: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let escala = min(size.width / caixa.width, size.height / caixa.height)
            let dx = (size.width - caixa.width * escala) / 2 - caixa.minX * escala
            let dy = (size.height - caixa.height * escala) / 2 - caixa.minY * escala
            let t = CGAffineTransform(a: escala, b: 0, c: 0, d: escala, tx: dx, ty: dy)
            for e in elementos {
                let p = e.path.applying(t)
                if let tr = e.traco {
                    let cor: Color
                    switch tr { case .corAtual: cor = corAtual; case .cor(let c): cor = c }
                    let largura = (e.larguraTraco ?? tracoPadrao) * escala
                    let estilo = StrokeStyle(lineWidth: largura, lineCap: .round, lineJoin: .round,
                                             dash: (e.tracejado ?? []).map { $0 * escala })
                    ctx.stroke(p, with: .color(cor), style: estilo)
                    if preencherTracos && e.tracejado == nil {
                        ctx.fill(p, with: .color(cor))
                    }
                }
                if let pr = e.preenchimento {
                    let cor: Color
                    switch pr { case .corAtual: cor = corAtual; case .cor(let c): cor = c }
                    ctx.fill(p, with: .color(cor), style: FillStyle(eoFill: e.parOuImpar))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
