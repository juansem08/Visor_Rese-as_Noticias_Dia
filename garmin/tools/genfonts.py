"""Genera fuentes BMFont (.fnt + .png) para Connect IQ a partir de TTF.

Uso: python -I genfonts.py <carpeta_ttf> <carpeta_salida>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

TTF_DIR = Path(sys.argv[1])
OUT_DIR = Path(sys.argv[2])
OUT_DIR.mkdir(parents=True, exist_ok=True)

ASCII = ''.join(chr(c) for c in range(32, 127))
LATIN1 = ''.join(chr(c) for c in range(160, 256) if c != 0xAD)  # sin guion suave
COMPLETO = ASCII + LATIN1
TITULO = ' ABCDEFGHIJKLMNOPQRSTUVWXYZÁÉÍÓÚÑÜ0123456789'
NUMEROS = '0123456789/ '
DIGITOS = '0123456789'

# id, archivo ttf, instancia variable (o None), tamaño px, espaciado extra px, caracteres
FUENTES = [
    ('titulo',     'BarlowCondensed-Bold.ttf', None,       60, 0,   TITULO),
    ('titulo_s',   'BarlowCondensed-Bold.ttf', None,       46, 0,   TITULO),
    ('numero',     'BarlowCondensed-Bold.ttf', None,       24, 0.5, NUMEROS),
    ('fondo',      'BarlowCondensed-Bold.ttf', None,      176, 0,   DIGITOS),
    ('titular',    'Inter.ttf',                'Bold',     25, 0,   COMPLETO),
    ('titular_m',  'Inter.ttf',                'Bold',     22, 0,   COMPLETO),
    ('titular_s',  'Inter.ttf',                'Bold',     19, 0,   COMPLETO),
    ('etiqueta',   'Inter.ttf',                'SemiBold', 15, 1.2, COMPLETO),
    ('texto',      'Inter.ttf',                'SemiBold', 16, 0,   COMPLETO),
]

ANCHO_ATLAS = 512
MARGEN = 2


def cargar(archivo, instancia, tam):
    fuente = ImageFont.truetype(str(TTF_DIR / archivo), tam)
    if instancia:
        nombres = [n.decode() if isinstance(n, bytes) else n for n in fuente.get_variation_names()]
        if instancia not in nombres:
            raise SystemExit(f'{archivo}: no existe la instancia {instancia}; hay {nombres}')
        fuente.set_variation_by_name(instancia)
    return fuente


def generar(fid, archivo, instancia, tam, espaciado, caracteres):
    fuente = cargar(archivo, instancia, tam)
    ascenso, descenso = fuente.getmetrics()
    alto_linea = ascenso + descenso

    glifos = []
    for ch in dict.fromkeys(caracteres):  # sin duplicados, en orden
        x0, y0, x1, y1 = fuente.getbbox(ch)  # ancla "la": origen en la línea de ascenso
        avance = round(fuente.getlength(ch) + espaciado)
        glifos.append((ch, x0, y0, max(0, x1 - x0), max(0, y1 - y0), avance))

    # Empaquetado por filas
    x = y = fila = 0
    posiciones = []
    for ch, x0, y0, w, h, _ in glifos:
        if x + w + MARGEN > ANCHO_ATLAS:
            x, y, fila = 0, y + fila + MARGEN, 0
        posiciones.append((x, y))
        x += w + MARGEN
        fila = max(fila, h)
    alto_atlas = y + fila + MARGEN
    alto_atlas += (-alto_atlas) % 4

    atlas = Image.new('RGBA', (ANCHO_ATLAS, alto_atlas), (255, 255, 255, 0))
    mascara = Image.new('L', atlas.size, 0)
    dibujo = ImageDraw.Draw(mascara)
    for (ch, x0, y0, w, h, _), (px, py) in zip(glifos, posiciones):
        if w and h:
            dibujo.text((px - x0, py - y0), ch, font=fuente, fill=255)
    atlas.putalpha(mascara)
    png = f'{fid}.png'
    atlas.save(OUT_DIR / png)

    lineas = [
        f'info face="{fid}" size={tam} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing={MARGEN},{MARGEN}',
        f'common lineHeight={alto_linea} base={ascenso} scaleW={ANCHO_ATLAS} scaleH={alto_atlas} pages=1 packed=0',
        f'page id=0 file="{png}"',
        f'chars count={len(glifos)}',
    ]
    for (ch, x0, y0, w, h, avance), (px, py) in zip(glifos, posiciones):
        lineas.append(
            f'char id={ord(ch)} x={px} y={py} width={w} height={h} '
            f'xoffset={x0} yoffset={y0} xadvance={avance} page=0 chnl=15'
        )
    (OUT_DIR / f'{fid}.fnt').write_text('\n'.join(lineas) + '\n', encoding='utf-8')
    print(f'{fid:10s} {tam:3d}px  {len(glifos):3d} glifos  atlas {ANCHO_ATLAS}x{alto_atlas}  alto línea {alto_linea}')


for f in FUENTES:
    generar(*f)
