"""Monta as capturas da App Store a partir das telas cruas do simulador.

Segue o guia de assets da Apple: frase curta por imagem, tela do app em
destaque, sem preço, URL ou ©. Visual da marca: papel, tinta, neon.

uso: python3 gerar_capturas_loja.py <pasta_crua> <fontes> <saida>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CRU, FONTES, SAIDA = map(Path, sys.argv[1:4])
PAPEL, TINTA, NEON = (228, 225, 217), (10, 11, 14), (89, 253, 39)

TELAS = [  # (arquivo, linha 1, linha 2 com destaque neon)
    ("inicio", "Seus pontos,", "num só lugar."),
    ("enviar", "Envie pontos", "pra quem quiser."),
    ("receber", "Receba com seu", "Cartão BlaXx."),
    ("cartao", "Suba de nível", "a cada ponto."),
    ("seguranca", "Sua conta,", "bem protegida."),
    ("boasvindas", "Cadastro grátis,", "sem mensalidade."),
]
APARELHOS = {"ipad": (2064, 2752), "iphone": (1320, 2868)}


def fonte(px, peso=700):
    f = ImageFont.truetype(str(FONTES / "Archivo-Variable.ttf"), px)
    try:
        f.set_variation_by_axes([peso, 100])  # eixos do Archivo: Weight, Width
    except Exception:
        try:
            f.set_variation_by_name("Bold")
        except Exception:
            pass
    return f


def sem_rodape(im, tabbar_frac):
    """Pinta o rodapé preto (tem "© 2026") com a cor do fundo da tela, mantendo
    a tab bar: o guia da Apple pede capturas sem símbolo de copyright."""
    w, h = im.size
    lim_tab = int(h * (1 - tabbar_frac))
    px = im.load()
    inicio = None
    for y in range(int(h * 0.35), lim_tab):
        escuros = sum(1 for x in range(0, w, 16) if sum(px[x, y]) < 90)
        if escuros > (w // 16) * 0.95:
            inicio = y
            break
    if inicio is None:
        return im
    cor = px[8, max(0, inicio - 24)]
    ImageDraw.Draw(im).rectangle((0, inicio, w, lim_tab), fill=cor)
    return im


def cantos(im, raio):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), raio, fill=255)
    out = Image.new("RGBA", im.size)
    out.paste(im, (0, 0), m)
    return out, m


for aparelho, (W, H) in APARELHOS.items():
    destino = SAIDA / aparelho
    destino.mkdir(parents=True, exist_ok=True)
    margem = int(W * 0.07)
    tam = int(W * (0.083 if aparelho == "ipad" else 0.092))
    f = fonte(tam)
    for n, (tela, l1, l2) in enumerate(TELAS, 1):
        tela_im = Image.open(CRU / f"{aparelho}-{tela}.png").convert("RGB")
        tela_im = sem_rodape(tela_im, 0.075 if aparelho == "ipad" else 0.105)
        fundo = Image.new("RGB", (W, H), PAPEL)
        d = ImageDraw.Draw(fundo)
        # rótulo mono, estilo cartão de embarque
        mono = ImageFont.truetype(str(FONTES / "SpaceMono-Regular.ttf"), int(tam * 0.26))
        y = int(H * 0.055)
        d.text((margem, y), f"BLAXX PONTOS · {n:02d}", font=mono, fill=(85, 88, 96))
        y += int(tam * 0.55)
        d.text((margem, y), l1, font=f, fill=TINTA)
        y += int(tam * 1.08)
        bx = d.textbbox((margem, y), l2, font=f)
        pad = int(tam * 0.12)
        d.rectangle((bx[0] - pad, bx[1] - pad, bx[2] + pad, bx[3] + pad), fill=NEON)
        d.text((margem, y), l2, font=f, fill=TINTA)
        topo = bx[3] + int(tam * 0.75)
        # tela do app: largura fixa, sangra pelo rodapé (corta tab bar e rodapé ©)
        larg = int(W * (0.80 if aparelho == "ipad" else 0.78))
        alt = int(tela_im.height * larg / tela_im.width)
        tela_im = tela_im.resize((larg, alt), Image.LANCZOS)
        raio = int(larg * (0.035 if aparelho == "ipad" else 0.09))
        arred, mascara = cantos(tela_im, raio)
        x = (W - larg) // 2
        sombra = Image.new("L", (W, H), 0)
        sombra.paste(mascara, (x, topo + int(W * 0.012)))
        sombra = sombra.filter(ImageFilter.GaussianBlur(W * 0.02)).point(lambda v: int(v * 0.28))
        fundo.paste(Image.new("RGB", (W, H), (40, 40, 40)), (0, 0), sombra)
        borda = max(4, W // 340)
        ImageDraw.Draw(fundo).rounded_rectangle(
            (x - borda, topo - borda, x + larg + borda, topo + alt + borda), raio + borda, fill=TINTA)
        fundo.paste(arred, (x, topo), arred)
        fundo.save(destino / f"{n:02d}-{tela}.png", optimize=True)
    print(aparelho, "ok")
