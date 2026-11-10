"""Icono de la app: versión tienda (512x512, cuadrado) y lanzador del reloj (54x54, redondo).

Uso: python -I icono.py <salida_tienda.png> <salida_lanzador.png>
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

SALIDA_TIENDA, SALIDA_LANZADOR = sys.argv[1], sys.argv[2]

S = 4                       # se dibuja a 4x y se reduce (bordes suaves)
L = 512 * S
LIMA = (200, 255, 46, 255)
BLANCO = (255, 255, 255, 255)
PISTA = (40, 40, 44, 255)
NEGRO = (0, 0, 0, 255)


def capa():
    return Image.new('RGBA', (L, L), (0, 0, 0, 0))


def dibujar(fondo_cuadrado: bool) -> Image.Image:
    img = Image.new('RGBA', (L, L), (0, 0, 0, 255) if fondo_cuadrado else (0, 0, 0, 0))
    c = L // 2

    # fondo: disco negro con brillos morado y lima
    fondo = capa()
    d = ImageDraw.Draw(fondo)
    d.ellipse((0, 0, L - 1, L - 1), fill=(0, 0, 0, 255))
    brillo = capa()
    db = ImageDraw.Draw(brillo)
    db.ellipse((-int(L * 0.25), -int(L * 0.25), int(L * 0.6), int(L * 0.6)), fill=(110, 60, 220, 170))
    db.ellipse((int(L * 0.5), int(L * 0.5), int(L * 1.2), int(L * 1.2)), fill=(170, 230, 30, 90))
    brillo = brillo.filter(ImageFilter.GaussianBlur(L * 0.12))
    mascara = Image.new('L', (L, L), 0)
    ImageDraw.Draw(mascara).ellipse((0, 0, L - 1, L - 1), fill=255)
    if fondo_cuadrado:
        mascara = Image.new('L', (L, L), 255)
    fondo = Image.alpha_composite(fondo if not fondo_cuadrado else Image.new('RGBA', (L, L), NEGRO), brillo)
    img.paste(fondo, (0, 0), mascara)

    d = ImageDraw.Draw(img)

    # anillo de progreso: 3 arcos de 116°, dos llenos en lima
    R = int(L * 0.40)
    ancho = int(L * 0.062)
    caja = (c - R, c - R, c + R, c + R)
    for k in range(3):
        inicio = -90 + 120 * k + 9          # PIL: grados en sentido horario desde las 3
        fin = inicio + 102                  # hueco amplio: las puntas redondeadas lo reducen
        color = LIMA if k < 2 else PISTA
        d.arc(caja, start=inicio, end=fin, fill=color, width=ancho)
        for a in (inicio, fin):             # puntas redondeadas
            x = c + (R - ancho / 2) * math.cos(math.radians(a))
            y = c + (R - ancho / 2) * math.sin(math.radians(a))
            d.ellipse((x - ancho / 2, y - ancho / 2, x + ancho / 2, y + ancho / 2), fill=color)

    # perilla al final del progreso
    a = math.radians(-90 + 120 + 9 + 102)
    px = c + (R - ancho / 2) * math.cos(a)
    py = c + (R - ancho / 2) * math.sin(a)
    rp = ancho * 0.95
    d.ellipse((px - rp, py - rp, px + rp, py + rp), fill=LIMA)
    d.ellipse((px - rp * 0.45, py - rp * 0.45, px + rp * 0.45, py + rp * 0.45), fill=NEGRO)

    # centro: píldora de categoría + 3 titulares
    u = L / 512
    d.rounded_rectangle((c - 64 * u, c - 112 * u, c + 26 * u, c - 80 * u), radius=16 * u, fill=LIMA)
    alto = 30 * u
    for i, (izq, der, color) in enumerate([(-112, 112, BLANCO), (-112, 80, BLANCO), (-112, 30, (130, 130, 136, 255))]):
        y = c - 46 * u + i * 56 * u
        d.rounded_rectangle((c + izq * u, y, c + der * u, y + alto), radius=alto / 2, fill=color)

    return img.resize((L // S, L // S), Image.LANCZOS)


tienda = dibujar(fondo_cuadrado=True).convert('RGB')
tienda.save(SALIDA_TIENDA)

lanzador = dibujar(fondo_cuadrado=False).resize((54, 54), Image.LANCZOS)
lanzador.save(SALIDA_LANZADOR)
print('ok', tienda.size, lanzador.size)
