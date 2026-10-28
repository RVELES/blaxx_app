import json, struct, base64, sys
w = json.load(open(sys.argv[1]))
tr = w.get("transform")
arcs = []
for a in w["arcs"]:
    x = y = 0; pts = []
    for p in a:
        if tr:
            x += p[0]; y += p[1]
            lon = x*tr["scale"][0]+tr["translate"][0]; lat = y*tr["scale"][1]+tr["translate"][1]
        else:
            lon, lat = p[0], p[1]
        pts.append((lat, lon))
    arcs.append(pts)
def ring(idx):
    out = []
    for i in idx:
        seg = arcs[i] if i >= 0 else arcs[~i][::-1]
        out.extend(seg if not out else seg[1:])
    return out
polys = []
for g in w["objects"]["countries"]["geometries"]:
    if g["type"] == "Polygon": ps = [g["arcs"]]
    elif g["type"] == "MultiPolygon": ps = g["arcs"]
    else: continue
    for p in ps: polys.append([ring(r) for r in p])
buf = bytearray(); npts = 0
buf += struct.pack("<H", len(polys))
for p in polys:
    buf += struct.pack("<H", len(p))
    for r in p:
        buf += struct.pack("<H", len(r)); npts += len(r)
        for lat, lon in r:
            buf += struct.pack("<hh", round(lat*100), round(lon*100))
b64 = base64.b64encode(bytes(buf)).decode()
print(len(polys), npts, len(b64), file=sys.stderr)
lines = [b64[i:i+120] for i in range(0, len(b64), 120)]
body = "\n".join(lines)
open(sys.argv[2], "w").write('''//
//  BXTerrasMundo.swift
//  BlaxxPontos · Design system "Embarque"
//
//  Polígonos dos países (terra firme) para o globo do painel de partidas.
//  GERADO de blaxx/vendor/countries-110m.json (Natural Earth, domínio público) pelo
//  script docs/scripts/gerar_terras_mundo.py — não editar à mão; rode o script de novo.
//  Formato: UInt16 nº de polígonos; por polígono UInt16 nº de anéis; por anel UInt16
//  nº de pontos e pares Int16 (lat×100, lon×100), little-endian.
//

import Foundation

nonisolated enum BXTerrasMundo {
    /// Cada polígono é uma lista de anéis (o primeiro é o contorno; os demais, buracos).
    static let poligonos: [[[(Double, Double)]]] = {
        guard let dados = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return [] }
        var i = 0
        func u16() -> Int { defer { i += 2 }; return Int(UInt16(dados[i]) | UInt16(dados[i + 1]) << 8) }
        func i16() -> Double { Double(Int16(bitPattern: UInt16(u16()))) / 100 }
        var saida: [[[(Double, Double)]]] = []
        for _ in 0..<u16() {
            var aneis: [[(Double, Double)]] = []
            for _ in 0..<u16() {
                let n = u16()
                var anel: [(Double, Double)] = []
                anel.reserveCapacity(n)
                for _ in 0..<n { let lat = i16(); let lon = i16(); anel.append((lat, lon)) }
                aneis.append(anel)
            }
            saida.append(aneis)
        }
        return saida
    }()

    private static let base64 = """
''' + body + '''
"""
}
''')
