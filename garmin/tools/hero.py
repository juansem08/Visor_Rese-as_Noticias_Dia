"""Imagen principal 1440x720 para la tienda Connect IQ (se dibuja a 2x y se reduce).

Uso: python -I hero.py <captura_noticia.png> <carpeta_ttf> <salida.png>
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

CAPTURA, TTF, SALIDA = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
S = 2
W, H = 1440 * S, 720 * S

LIMA = (200, 255, 46)
BLANCO = (255, 255, 255)
GRIS = (150, 150, 150)
NEGRO = (0, 0, 0)

CENTRO_CAP, RADIO_CAP = (247, 247), 243  # pantalla del reloj dentro de la captura


def fuente(nombre, tam, peso=None):
    f = ImageFont.truetype(str(TTF / nombre), tam)
    if peso:
        f.set_variation_by_name(peso)
    return f


BARLOW = lambda t: fuente('BarlowCondensed-Bold.ttf', t)
INTER = lambda t, p='SemiBold': fuente('Inter.ttf', t, p)


def capa():
    return Image.new('RGBA', (W, H), (0, 0, 0, 0))


def componer(base, *capas):
    for c in capas:
        base = Image.alpha_composite(base, c)
    return base


def vidrio(d, caja, radio, relleno=(255, 255, 255, 16), borde=(255, 255, 255, 46), ancho=2 * S):
    d.rounded_rectangle(caja, radius=radio, fill=relleno, outline=borde, width=ancho)


def chevron(d, cx, cy, tam, color, ancho, direccion='derecha'):
    if direccion == 'derecha':
        puntos = [(cx - tam * 0.4, cy - tam), (cx + tam * 0.6, cy), (cx - tam * 0.4, cy + tam)]
    else:  # arriba
        puntos = [(cx - tam, cy + tam * 0.4), (cx, cy - tam * 0.6), (cx + tam, cy + tam * 0.4)]
    d.line(puntos, fill=color, width=ancho, joint='curve')


# ---------------------------------------------------------------- fondo
img = Image.new('RGBA', (W, H), (0, 0, 0, 255))

brillos = capa()
d = ImageDraw.Draw(brillos)
d.ellipse((-700, -900, 1300, 900), fill=(96, 52, 200, 150))     # morado arriba a la izquierda
d.ellipse((1500, 700, 3300, 2300), fill=(150, 220, 20, 70))     # lima abajo a la derecha
d.ellipse((1560, 200, 2560, 1240), fill=(160, 230, 40, 46))     # lima detrás del reloj
brillos = brillos.filter(ImageFilter.GaussianBlur(220))
img = componer(img, brillos)

# rejilla de puntos sutil
puntos = capa()
d = ImageDraw.Draw(puntos)
for y in range(40, H, 56):
    for x in range(40, W, 56):
        d.ellipse((x - 2, y - 2, x + 2, y + 2), fill=(255, 255, 255, 9))
img = componer(img, puntos)

# número gigante de fondo
marca = capa()
ImageDraw.Draw(marca).text((W - 40, 760), '01', font=BARLOW(1180), fill=(255, 255, 255, 9), anchor='rm')
img = componer(img, marca)

# ---------------------------------------------------------------- reloj
cx, cy = 2110, 720
R_BISEL, R_PANTALLA = 440, 378

reloj = capa()
d = ImageDraw.Draw(reloj)

# órbita decorativa con segmento lima
R_ORBITA = 580
d.ellipse((cx - R_ORBITA, cy - R_ORBITA, cx + R_ORBITA, cy + R_ORBITA), outline=(255, 255, 255, 28), width=3 * S)
d.arc((cx - R_ORBITA, cy - R_ORBITA, cx + R_ORBITA, cy + R_ORBITA), start=-62, end=-18, fill=LIMA + (255,), width=6 * S)
ang = math.radians(-18)
px, py = cx + R_ORBITA * math.cos(ang), cy + R_ORBITA * math.sin(ang)
d.ellipse((px - 16 * S, py - 16 * S, px + 16 * S, py + 16 * S), fill=LIMA + (255,))
d.ellipse((px - 7 * S, py - 7 * S, px + 7 * S, py + 7 * S), fill=NEGRO + (255,))

# correas con ranuras
ANCHO_CORREA = 480
for y0, y1 in [(-60, cy - 280), (cy + 280, H + 60)]:
    d.rounded_rectangle((cx - ANCHO_CORREA // 2, y0, cx + ANCHO_CORREA // 2, y1), radius=70, fill=(24, 24, 26, 255))
    for k in range(6):
        yy = (y0 + 90 + k * 64) if y0 < 0 else (y1 - 90 - k * 64)
        d.rounded_rectangle((cx - 150, yy - 9, cx + 150, yy + 9), radius=9, fill=(14, 14, 15, 255))

# botones (3 a la izquierda, 2 a la derecha)
for lado, offsets in [(-1, (-215, 0, 215)), (1, (-190, 190))]:
    for oy in offsets:
        bx = cx + lado * (math.sqrt(R_BISEL ** 2 - oy ** 2) - 8)
        d.rounded_rectangle((bx - 26, cy + oy - 58, bx + 26, cy + oy + 58), radius=18, fill=(46, 46, 48, 255))

# bisel
d.ellipse((cx - R_BISEL, cy - R_BISEL, cx + R_BISEL, cy + R_BISEL), fill=(30, 30, 32, 255))
d.ellipse((cx - R_BISEL, cy - R_BISEL, cx + R_BISEL, cy + R_BISEL), outline=(80, 80, 84, 255), width=3 * S)
d.ellipse((cx - R_PANTALLA - 26, cy - R_PANTALLA - 26, cx + R_PANTALLA + 26, cy + R_PANTALLA + 26), fill=(6, 6, 6, 255))

# sombra del reloj
sombra = capa()
ImageDraw.Draw(sombra).ellipse((cx - R_BISEL, cy - R_BISEL + 40, cx + R_BISEL, cy + R_BISEL + 40), fill=(0, 0, 0, 200))
sombra = sombra.filter(ImageFilter.GaussianBlur(60))
img = componer(img, sombra, reloj)

# pantalla real de la app
pantalla = Image.open(CAPTURA).convert('RGB')
ccx, ccy = CENTRO_CAP
pantalla = pantalla.crop((ccx - RADIO_CAP, ccy - RADIO_CAP, ccx + RADIO_CAP, ccy + RADIO_CAP))
lado = R_PANTALLA * 2
pantalla = pantalla.resize((lado, lado), Image.LANCZOS)
mascara = Image.new('L', (lado, lado), 0)
ImageDraw.Draw(mascara).ellipse((0, 0, lado - 1, lado - 1), fill=255)
img.paste(pantalla, (cx - R_PANTALLA, cy - R_PANTALLA), mascara)

# reflejo de cristal
reflejo = capa()
ImageDraw.Draw(reflejo).pieslice((cx - R_PANTALLA, cy - R_PANTALLA, cx + R_PANTALLA, cy + R_PANTALLA),
                                 start=200, end=290, fill=(255, 255, 255, 10))
img = componer(img, reflejo)

# ---------------------------------------------------------------- cápsulas flotantes junto al reloj
flot = capa()
d = ImageDraw.Draw(flot)
f_chip = INTER(25 * S, 'Bold')

# "Desliza para leer"
x0, y0 = 1380, 300
texto = 'DESLIZA PARA LEER'
ancho = d.textlength(texto, font=f_chip) + 150
vidrio(d, (x0, y0, x0 + ancho, y0 + 88), 44, relleno=(20, 20, 22, 230))
d.ellipse((x0 + 14, y0 + 14, x0 + 74, y0 + 74), fill=LIMA + (255,))
chevron(d, x0 + 44, y0 + 46, 13, NEGRO + (255,), 5 * S, 'arriba')
d.text((x0 + 96, y0 + 45), texto, font=f_chip, fill=BLANCO + (255,), anchor='lm')

# "Resumido por IA"
texto = 'RESUMIDO POR IA'
ancho = d.textlength(texto, font=f_chip) + 130
x0, y0 = W - ancho - 70, 1070
vidrio(d, (x0, y0, x0 + ancho, y0 + 88), 44, relleno=(20, 20, 22, 230))
d.ellipse((x0 + 28, y0 + 34, x0 + 48, y0 + 54), fill=LIMA + (255,))
d.text((x0 + 76, y0 + 45), texto, font=f_chip, fill=BLANCO + (255,), anchor='lm')
img = componer(img, flot)

# ---------------------------------------------------------------- columna de texto
txt = capa()
d = ImageDraw.Draw(txt)
X = 180

# píldora superior
f_pill = INTER(21 * S, 'Bold')
texto = 'TU RESUMEN DE CADA MAÑANA'
ancho = d.textlength(texto, font=f_pill) + 110
vidrio(d, (X, 196, X + ancho, 276), 40)
d.ellipse((X + 32, 226, X + 52, 246), fill=LIMA + (255,))
d.text((X + 74, 237), texto, font=f_pill, fill=BLANCO + (255,), anchor='lm')

# título
d.text((X - 8, 560), 'NOTICIAS', font=BARLOW(132 * S), fill=BLANCO + (255,), anchor='ls')
d.text((X - 8, 820), 'DEL DÍA', font=BARLOW(132 * S), fill=LIMA + (255,), anchor='ls')

# lema
d.text((X, 912), '3 noticias globales resumidas por IA', font=INTER(28 * S), fill=(225, 225, 225, 255), anchor='ls')
d.text((X, 976), 'cada mañana, directo en tu muñeca.', font=INTER(28 * S), fill=GRIS + (255,), anchor='ls')

# características
f_car = INTER(19 * S, 'Bold')
x = X
for texto in ['3 NOTICIAS', 'MÁX. 15 PALABRAS', 'CARRUSEL VERTICAL']:
    ancho = d.textlength(texto, font=f_car) + 92
    vidrio(d, (x, 1036, x + ancho, 1108), 36)
    d.ellipse((x + 26, 1063, x + 44, 1081), fill=LIMA + (255,))
    d.text((x + 62, 1072), texto, font=f_car, fill=(230, 230, 230, 255), anchor='lm')
    x += ancho + 20

# botón de acción
f_cta = INTER(22 * S, 'Bold')
texto = 'FORERUNNER 165'
ancho = d.textlength(texto, font=f_cta) + 170
y0 = 1160
d.rounded_rectangle((X, y0, X + ancho, y0 + 104), radius=52, fill=LIMA + (255,))
d.text((X + 46, y0 + 52), texto, font=f_cta, fill=NEGRO + (255,), anchor='lm')
cxb = X + ancho - 58
d.ellipse((cxb - 38, y0 + 14, cxb + 38, y0 + 90), fill=NEGRO + (255,))
chevron(d, cxb, y0 + 52, 13, LIMA + (255,), 5 * S, 'derecha')

img = componer(img, txt)

# ---------------------------------------------------------------- salida
final = img.convert('RGB').resize((1440, 720), Image.LANCZOS)
final.save(SALIDA)
print(SALIDA, final.size)
