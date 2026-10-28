//
//  BXGloboRede.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Globo do "Painel de partidas · Mapa", portado de `blaxx/assets/blaxx-globo.js` com as opções da
//  home-embarque (esfera azul-clara, terra azul-marinho, alfinetes neo-brutais com monograma da vertical).
//  Projeção ortográfica desenhada em Canvas + TimelineView, sem WebView nem rede.
//
//  - Gira sozinho (pausa com "Reduzir movimento").
//  - Tocar num alfinete seleciona a cidade; escolher uma cidade na lista gira o globo até ela.
//  - Não há arraste: dentro da ScrollView ele roubaria a rolagem vertical da página.
//

import SwiftUI

struct BXGloboRede: View {
    let cidades: [BXCidadePainel]
    @Binding var selecionada: String?

    @Environment(\.accessibilityReduceMotion) private var reduzido

    /// Centro inicial: abre no Brasil, como a home do site (rotate [47, -12] do d3).
    @State private var base = Centro(lon: -47, lat: 12)
    @State private var ancora = Date()
    @State private var girando = true
    @State private var animacao: Animacao?

    /// Graus por segundo (o site gira 0,12°/quadro ≈ 7°/s).
    private let velocidade = 7.0

    struct Centro: Equatable { var lon: Double; var lat: Double }
    private struct Animacao { let de: Centro; let para: Centro; let inicio: Date }

    var body: some View {
        GeometryReader { geo in
            let lado = min(geo.size.width, 340)
            TimelineView(.animation(paused: !(girando && !reduzido) && animacao == nil)) { linha in
                let c = centro(em: linha.date)
                Canvas { ctx, tamanho in
                    Self.desenhar(ctx, tamanho: tamanho, centro: c, cidades: cidades, selecionada: selecionada)
                }
            }
            .frame(width: lado, height: lado)
            .contentShape(Circle())
            .gesture(SpatialTapGesture().onEnded { toque in
                tocar(em: toque.location, lado: lado)
            })
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity)
        .onChange(of: selecionada) { _, id in
            guard let id, let cidade = cidades.first(where: { $0.id == id }) else { return }
            let agora = Date()
            animacao = Animacao(de: centro(em: agora),
                                para: Centro(lon: cidade.longitude, lat: max(-60, min(60, cidade.latitude))),
                                inicio: agora)
            girando = false
        }
        .accessibilityElement()
        .accessibilityLabel("Globo com as cidades da rede BlaXx e da rede em expansão")
        .accessibilityHint("Escolha uma cidade na lista abaixo para centralizar o globo nela.")
    }

    // MARK: - Tempo

    private func centro(em agora: Date) -> Centro {
        if let a = animacao {
            let t = min(1, agora.timeIntervalSince(a.inicio) / (reduzido ? 0.01 : 0.9))
            let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            var dLon = a.para.lon - a.de.lon
            dLon = dLon.truncatingRemainder(dividingBy: 360)
            if dLon > 180 { dLon -= 360 } else if dLon < -180 { dLon += 360 }
            let c = Centro(lon: a.de.lon + dLon * e, lat: a.de.lat + (a.para.lat - a.de.lat) * e)
            if t >= 1 { DispatchQueue.main.async { finalizar(a, em: c) } }
            return c
        }
        guard girando, !reduzido else { return base }
        return Centro(lon: base.lon - agora.timeIntervalSince(ancora) * velocidade, lat: base.lat)
    }

    private func finalizar(_ a: Animacao, em c: Centro) {
        guard let atual = animacao, atual.inicio == a.inicio else { return }
        base = c
        animacao = nil
    }

    private func tocar(em ponto: CGPoint, lado: CGFloat) {
        let c = centro(em: Date())
        let tamanho = CGSize(width: lado, height: lado)
        var melhor: (id: String, d: CGFloat)?
        for cidade in cidades {
            guard let (p, z) = Self.projetar(cidade.latitude, cidade.longitude, centro: c, tamanho: tamanho) else { continue }
            let cabeca = Self.cabecaAlfinete(ponta: p, z: z)
            let d = hypot(cabeca.x - ponto.x, cabeca.y - ponto.y)
            if d < 26, d < (melhor?.d ?? .infinity) { melhor = (cidade.id, d) }
        }
        if let m = melhor { selecionada = m.id }
    }

    // MARK: - Desenho

    private static let raioRelativo: CGFloat = 0.44

    /// Projeção ortográfica; nil quando o ponto está no hemisfério de trás. `z` = cosseno da distância ao centro.
    static func projetar(_ lat: Double, _ lon: Double, centro: Centro, tamanho: CGSize) -> (CGPoint, Double)? {
        let r = min(tamanho.width, tamanho.height) * raioRelativo
        let phi0 = centro.lat * .pi / 180, lam0 = centro.lon * .pi / 180
        let la = lat * .pi / 180, dl = lon * .pi / 180 - lam0
        let z = sin(phi0) * sin(la) + cos(phi0) * cos(la) * cos(dl)
        guard z >= 0 else { return nil }
        let x = cos(la) * sin(dl)
        let y = cos(phi0) * sin(la) - sin(phi0) * cos(la) * cos(dl)
        return (CGPoint(x: tamanho.width / 2 + r * x, y: tamanho.height / 2 - r * y), z)
    }

    private static func escala(_ z: Double) -> CGFloat { CGFloat(0.6 + 0.55 * z) }

    static func cabecaAlfinete(ponta: CGPoint, z: Double) -> CGPoint {
        CGPoint(x: ponta.x, y: ponta.y - 8.5 * escala(z) * 1.7)
    }

    private static let esferaAlta = Color(red: 0xE3 / 255, green: 0xF1 / 255, blue: 0xFC / 255)
    private static let esferaMeio = Color(red: 0x8E / 255, green: 0xC3 / 255, blue: 0xEA / 255)
    private static let esferaBaixa = Color(red: 0x4A / 255, green: 0x93 / 255, blue: 0xD1 / 255)
    private static let terra = Color(red: 15 / 255, green: 50 / 255, blue: 90 / 255).opacity(0.85)
    private static let costa = Color(red: 8 / 255, green: 32 / 255, blue: 60 / 255).opacity(0.55)
    private static let grade = Color(red: 8 / 255, green: 32 / 255, blue: 60 / 255).opacity(0.10)

    static func desenhar(_ ctx: GraphicsContext, tamanho: CGSize, centro: Centro,
                         cidades: [BXCidadePainel], selecionada: String?) {
        let cx = tamanho.width / 2, cy = tamanho.height / 2
        let r = min(tamanho.width, tamanho.height) * raioRelativo
        let esfera = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
        let phi0 = centro.lat * .pi / 180, lam0 = centro.lon * .pi / 180
        let sP = sin(phi0), cP = cos(phi0)

        // Ponto na tela; atrás do globo é levado até a borda (recorte simples dos polígonos).
        func tela(_ lat: Double, _ lon: Double) -> (CGPoint, Bool) {
            let la = lat * .pi / 180, dl = lon * .pi / 180 - lam0
            let cl = cos(la)
            var x = cl * sin(dl)
            var y = cP * sin(la) - sP * cl * cos(dl)
            let z = sP * sin(la) + cP * cl * cos(dl)
            let frente = z >= 0
            if !frente {
                let n = max(hypot(x, y), 1e-9)
                x /= n; y /= n
            }
            return (CGPoint(x: cx + r * x, y: cy - r * y), frente)
        }

        // Esfera.
        ctx.fill(Path(ellipseIn: esfera), with: .radialGradient(
            Gradient(stops: [.init(color: esferaAlta, location: 0), .init(color: esferaMeio, location: 0.65),
                             .init(color: esferaBaixa, location: 1)]),
            center: CGPoint(x: cx - r * 0.35, y: cy - r * 0.35), startRadius: r * 0.1, endRadius: r))

        var recortado = ctx
        recortado.clip(to: Path(ellipseIn: esfera))

        // Grade de 10°.
        var gradePath = Path()
        func linha(_ amostras: [(Double, Double)]) {
            var caneta = false
            for (la, lo) in amostras {
                let (p, frente) = tela(la, lo)
                if frente { if caneta { gradePath.addLine(to: p) } else { gradePath.move(to: p); caneta = true } }
                else { caneta = false }
            }
        }
        for lon in stride(from: -180.0, to: 180.0, by: 10) { linha(stride(from: -80.0, through: 80.0, by: 4).map { ($0, lon) }) }
        for lat in stride(from: -80.0, through: 80.0, by: 10) { linha(stride(from: -180.0, through: 180.0, by: 4).map { (lat, $0) }) }
        recortado.stroke(gradePath, with: .color(grade), lineWidth: 0.5)

        // Terra: cada país com os seus buracos (even-odd). Anel inteiro atrás do globo é pulado.
        var contorno = Path()
        for poligono in BXTerrasMundo.poligonos {
            var p = Path()
            for anel in poligono {
                var pontos: [CGPoint] = []
                pontos.reserveCapacity(anel.count)
                var algumNaFrente = false
                for (la, lo) in anel {
                    let (pt, frente) = tela(la, lo)
                    pontos.append(pt)
                    if frente { algumNaFrente = true }
                }
                guard algumNaFrente, let primeiro = pontos.first else { continue }
                p.move(to: primeiro)
                for pt in pontos.dropFirst() { p.addLine(to: pt) }
                p.closeSubpath()
            }
            recortado.fill(p, with: .color(terra), style: FillStyle(eoFill: true))
            contorno.addPath(p)
        }
        recortado.stroke(contorno, with: .color(costa), lineWidth: 0.6)

        // Anel neon.
        ctx.stroke(Path(ellipseIn: esfera), with: .color(BXCor.neon.opacity(0.5)), lineWidth: 1.4)

        // Alfinetes: os de trás primeiro, o selecionado por último.
        let visiveis = cidades.compactMap { c -> (BXCidadePainel, CGPoint, Double)? in
            guard let (p, z) = projetar(c.latitude, c.longitude, centro: centro, tamanho: tamanho) else { return nil }
            return (c, p, z)
        }
        .sorted { a, b in
            if (a.0.id == selecionada) != (b.0.id == selecionada) { return b.0.id == selecionada }
            return a.2 < b.2
        }
        for (cidade, p, z) in visiveis {
            alfinete(ctx, ponta: p, z: z, cidade: cidade, destacado: cidade.id == selecionada)
        }
    }

    /// Alfinete neo-brutal do site: corpo na cor da vertical (tinta na rede em expansão), emblema branco
    /// com o monograma da vertical, borda tinta e sombra dura.
    private static func alfinete(_ ctx: GraphicsContext, ponta: CGPoint, z: Double,
                                 cidade: BXCidadePainel, destacado: Bool) {
        let s = escala(z) * (destacado ? 1.35 : 1)
        let r = 8.5 * s
        let cyA = ponta.y - r * 1.7
        func forma(_ dx: CGFloat) -> Path {
            var p = Path()
            let tx = ponta.x + dx, ty = ponta.y + dx
            p.move(to: CGPoint(x: tx, y: ty))
            p.addQuadCurve(to: CGPoint(x: tx - r, y: cyA + dx), control: CGPoint(x: tx - r * 1.3, y: cyA + dx + r * 0.9))
            p.addArc(center: CGPoint(x: tx, y: cyA + dx), radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            p.addQuadCurve(to: CGPoint(x: tx, y: ty), control: CGPoint(x: tx + r * 1.3, y: cyA + dx + r * 0.9))
            p.closeSubpath()
            return p
        }
        let vertical = cidade.verticais.first
        let corpo = destacado ? BXCor.neon : (vertical?.cor ?? BXCor.tinta)
        ctx.fill(forma(1.6 * s), with: .color(BXCor.tinta.opacity(0.35)))
        let pin = forma(0)
        ctx.fill(pin, with: .color(corpo))
        ctx.stroke(pin, with: .color(BXCor.tinta), lineWidth: max(1.3, 1.6 * s))
        let emblema = Path(ellipseIn: CGRect(x: ponta.x - r * 0.64, y: cyA - r * 0.64, width: r * 1.28, height: r * 1.28))
        ctx.fill(emblema, with: .color(.white))
        ctx.stroke(emblema, with: .color(BXCor.tinta), lineWidth: max(1, s))
        if let vertical {
            let mono: String
            switch vertical {
            case .postos: mono = "PO"
            case .mercado: mono = "ME"
            case .farmacia: mono = "FA"
            }
            ctx.draw(Text(mono).font(.system(size: max(6, (r * 0.72).rounded()), weight: .heavy)).foregroundColor(BXCor.tinta),
                     at: CGPoint(x: ponta.x, y: cyA + 0.5))
        }
    }
}
