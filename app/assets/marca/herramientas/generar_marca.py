"""Genera los archivos de la marca TuTurno a partir de los originales de assets/marca/fuente/.

Lee:
  - fuente/logotipos.svg: las cuatro opciones de logotipo exportadas de Canva (una por cuadrante).
    La opción 4 (abajo a la derecha, letras recortadas finas) es EL logotipo; las otras tres se
    guardan solo como alternativas archivadas.
  - fuente/monograma-tut.jpeg: el monograma «TuT» (dos T altas y una u pequeña). Se vectoriza:
    las T son polígonos de 8 aristas rectas (se ajusta una recta a cada arista y las esquinas salen
    de sus cortes) y la u, dos cortes rectos y dos curvas de Bézier ajustadas al contorno.

Escribe (rutas relativas a app/):
  - assets/marca/logotipo/tuturno-*.svg y assets/marca/monograma/tut-*.svg, en amarillo, azul noche,
    blanco y azul.
  - assets/marca/alternativas/opcion-*.svg (las tres opciones descartadas, en amarillo).
  - assets/marca/icono/icono-app.svg y icono-app-1024.png (icono cuadrado para tiendas y documentos).
  - lib/widgets/marca/trazos_marca.dart (los trazos para LogoTuTurno, MonogramaTut e IntroMarca).
  - android/app/src/main/res/: icono adaptativo (fondo, primer plano y capa monocroma), PNG de
    mipmap-*dpi para Android 7 y el monograma de la pantalla de arranque (claro y oscuro).
  - web/: favicon.svg, favicon.png e icons/*.png.

Uso (desde app/, con un entorno virtual que tenga Pillow, numpy, scipy, scikit-image y cairosvg):
  python3 -m venv /tmp/marca && /tmp/marca/bin/pip install Pillow numpy scipy scikit-image cairosvg
  /tmp/marca/bin/python -I assets/marca/herramientas/generar_marca.py .
Después: dart format --line-length 120 lib/widgets/marca/trazos_marca.dart
"""

import io
import json
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

import cairosvg
import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter
from skimage import measure

AMARILLO = '#FFDE59'
AZUL = '#2643E0'
AZUL_NOCHE = '#0E1A4F'
BLANCO = '#FFFFFF'
TONOS = {'amarillo': AMARILLO, 'azul-noche': AZUL_NOCHE, 'blanco': BLANCO, 'azul': AZUL}

# ---------------------------------------------------------------------------------------------
# Trazos SVG (solo M, L, C y Z absolutos, que es lo que exporta Canva y lo que genera este script)
# ---------------------------------------------------------------------------------------------

_NUM = r'-?\d+(?:\.\d+)?(?:e-?\d+)?'


def parsear(d):
    tokens = re.findall(r'[MLCZ]|' + _NUM, d)
    i, cmd, cmds = 0, None, []
    while i < len(tokens):
        t = tokens[i]
        if t in 'MLCZ':
            cmd = t
            i += 1
            if cmd == 'Z':
                cmds.append(('Z', []))
                continue
        n = {'M': 2, 'L': 2, 'C': 6}[cmd]
        v = [float(x) for x in tokens[i:i + n]]
        i += n
        cmds.append((cmd, [(v[k], v[k + 1]) for k in range(0, n, 2)]))
        if cmd == 'M':
            cmd = 'L'
    return cmds


def transformar(cmds, fn):
    return [(c, [fn(p) for p in pts]) for c, pts in cmds]


def mover(cmds, dx, dy):
    return transformar(cmds, lambda p: (p[0] + dx, p[1] + dy))


def _extremos_cubica(p0, p1, p2, p3):
    ts = [0.0, 1.0]
    a = -p0 + 3 * p1 - 3 * p2 + p3
    b = 2 * (p0 - 2 * p1 + p2)
    c = p1 - p0
    if abs(a) < 1e-12:
        if abs(b) > 1e-12:
            ts.append(-c / b)
    else:
        disc = b * b - 4 * a * c
        if disc >= 0:
            r = math.sqrt(disc)
            ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
    return [(1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3
            for t in ts if 0 <= t <= 1]


def caja(cmds):
    xs, ys, cur, ini = [], [], None, None
    for c, pts in cmds:
        if c == 'M':
            cur = ini = pts[0]
            xs.append(cur[0])
            ys.append(cur[1])
        elif c == 'L':
            cur = pts[0]
            xs.append(cur[0])
            ys.append(cur[1])
        elif c == 'C':
            (x1, y1), (x2, y2), (x3, y3) = pts
            xs += _extremos_cubica(cur[0], x1, x2, x3)
            ys += _extremos_cubica(cur[1], y1, y2, y3)
            cur = pts[2]
        else:
            cur = ini
    return min(xs), min(ys), max(xs), max(ys)


def caja_de(lista):
    cajas = [caja(c) for c in lista]
    return (min(b[0] for b in cajas), min(b[1] for b in cajas), max(b[2] for b in cajas), max(b[3] for b in cajas))


def num(v, decimales=2):
    s = f'{v:.{decimales}f}'.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def a_d(cmds, decimales=2):
    partes = []
    for c, pts in cmds:
        partes.append('Z' if c == 'Z' else c + ' '.join(f'{num(x, decimales)} {num(y, decimales)}' for x, y in pts))
    return ''.join(partes)


# ---------------------------------------------------------------------------------------------
# Logotipos (logotipos.svg de Canva)
# ---------------------------------------------------------------------------------------------

_SVG = '{http://www.w3.org/2000/svg}'
_XL = '{http://www.w3.org/1999/xlink}'


def leer_logotipos(ruta):
    """Las cuatro opciones, en el orden en que están colocadas en la página, como listas de letras."""
    raiz = ET.parse(ruta).getroot()
    glifos = {g.get('id'): parsear(g.find(_SVG + 'path').get('d'))
              for g in raiz.iter(_SVG + 'g') if (g.get('id') or '').startswith('glyph-')}
    fuentes = {g.get('id'): [(u.get(_XL + 'href')[1:], float(u.get('x')), float(u.get('y')))
                             for u in g.iter(_SVG + 'use')]
               for g in raiz.iter(_SVG + 'g') if (g.get('id') or '').startswith('source-')}
    opciones = []
    for u in raiz.findall(_SVG + 'use'):
        m = re.match(r'matrix\(1, 0, 0, 1, ([\d.-]+), ([\d.-]+)\)', u.get('transform'))
        tx, ty = float(m.group(1)), float(m.group(2))
        opciones.append([mover(glifos[gid], x + tx, y + ty) for gid, x, y in fuentes[u.get(_XL + 'href')[1:]]])
    # Cuadrantes: 1 arriba a la izquierda, 2 arriba a la derecha, 3 abajo a la izquierda, 4 abajo a la derecha.
    centros = [((b[0] + b[2]) / 2, (b[1] + b[3]) / 2) for b in (caja_de(o) for o in opciones)]
    orden = sorted(range(len(opciones)), key=lambda i: (centros[i][1] > 405, centros[i][0] > 720))
    return [opciones[i] for i in orden]


def normalizar(letras):
    """Mueve el dibujo para que su caja empiece en (0, 0). Devuelve (letras, ancho, alto)."""
    x0, y0, x1, y1 = caja_de(letras)
    return [mover(c, -x0, -y0) for c in letras], x1 - x0, y1 - y0


# ---------------------------------------------------------------------------------------------
# Monograma (vectorización del JPEG)
# ---------------------------------------------------------------------------------------------

def _cobertura(ruta):
    """0 = fondo, 1 = amarillo. Sale del canal azul, que es el que más separa el amarillo del papel."""
    a = np.asarray(Image.open(ruta).convert('RGB')).astype(float)
    azul = a[:, :, 2]
    fondo = np.median(azul[azul > 230])
    tinta = np.median(azul[azul < 100])
    return np.clip((fondo - azul) / (fondo - tinta), 0, 1)


def _recta(pts):
    m = pts.mean(0)
    _, _, vt = np.linalg.svd(pts - m)
    return m, vt[0]


def _corte(r1, r2):
    (p, d), (q, e) = r1, r2
    s, _ = np.linalg.solve(np.array([d, -e]).T, q - p)
    return p + s * d


def _indice(contorno, punto):
    return int(np.argmin(np.linalg.norm(contorno[:-1] - punto, axis=1)))


def _tramo(contorno, a, b):
    n = len(contorno) - 1
    return contorno[[(a + i) % n for i in range(((b - a) % n) + 1)]]


def _sin_extremos(pts, margen=3.0):
    lejos = (np.linalg.norm(pts - pts[0], axis=1) > margen) & (np.linalg.norm(pts - pts[-1], axis=1) > margen)
    return pts[lejos]


def _poligono_t(contorno):
    poly = measure.approximate_polygon(contorno, tolerance=1.2)[:-1]
    n = len(poly)
    largas = [(poly[i], poly[(i + 1) % n]) for i in range(n) if np.linalg.norm(poly[(i + 1) % n] - poly[i]) > 6]
    assert len(largas) == 8, f'Una T debería tener 8 aristas y tiene {len(largas)}'
    rectas = [_recta(_sin_extremos(_tramo(contorno, _indice(contorno, a), _indice(contorno, b)))) for a, b in largas]
    esquinas = [_corte(rectas[i - 1], rectas[i]) for i in range(8)]
    return [('M', [tuple(esquinas[0])])] + [('L', [tuple(p)]) for p in esquinas[1:]] + [('Z', [])]


# Ajuste de curvas de Bézier cúbicas (algoritmo de Schneider, Graphics Gems, 1990).

def _bez(c, t):
    t = np.asarray(t)[:, None]
    return (1 - t) ** 3 * c[0] + 3 * (1 - t) ** 2 * t * c[1] + 3 * (1 - t) * t ** 2 * c[2] + t ** 3 * c[3]


def _bez1(c, t):
    t = np.asarray(t)[:, None]
    return 3 * (1 - t) ** 2 * (c[1] - c[0]) + 6 * (1 - t) * t * (c[2] - c[1]) + 3 * t ** 2 * (c[3] - c[2])


def _bez2(c, t):
    t = np.asarray(t)[:, None]
    return 6 * (1 - t) * (c[2] - 2 * c[1] + c[0]) + 6 * t * (c[3] - 2 * c[2] + c[1])


def _generar(pts, u, t1, t2):
    p0, p3 = pts[0], pts[-1]
    a1 = np.outer(3 * (1 - u) ** 2 * u, t1)
    a2 = np.outer(3 * (1 - u) * u ** 2, t2)
    base = _bez(np.array([p0, p0, p3, p3]), u)
    c = np.array([[np.sum(a1 * a1), np.sum(a1 * a2)], [np.sum(a1 * a2), np.sum(a2 * a2)]])
    x = np.array([np.sum(a1 * (pts - base)), np.sum(a2 * (pts - base))])
    det = c[0, 0] * c[1, 1] - c[0, 1] * c[1, 0]
    seg = np.linalg.norm(p3 - p0)
    al1 = al2 = seg / 3
    if abs(det) > 1e-12:
        al1 = (x[0] * c[1, 1] - x[1] * c[0, 1]) / det
        al2 = (c[0, 0] * x[1] - c[1, 0] * x[0]) / det
    if al1 < 1e-6 * seg or al2 < 1e-6 * seg:
        al1 = al2 = seg / 3
    return np.array([p0, p0 + t1 * al1, p3 + t2 * al2, p3])


def _ajustar(pts, t1, t2, tol):
    if len(pts) == 2:
        d = np.linalg.norm(pts[1] - pts[0]) / 3
        return [np.array([pts[0], pts[0] + t1 * d, pts[1] + t2 * d, pts[1]])]
    u = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    u = u / u[-1]
    c = _generar(pts, u, t1, t2)
    for _ in range(20):
        err = np.linalg.norm(_bez(c, u) - pts, axis=1)
        if err.max() < tol:
            return [c]
        d, d1, d2 = _bez(c, u) - pts, _bez1(c, u), _bez2(c, u)
        den = (d1 * d1 + d * d2).sum(1)
        u = np.clip(np.where(np.abs(den) > 1e-12, u - (d * d1).sum(1) / np.where(den == 0, 1, den), u), 0, 1)
        c = _generar(pts, u, t1, t2)
    i = min(max(int(np.argmax(np.linalg.norm(_bez(c, u) - pts, axis=1))), 2), len(pts) - 3)
    tc = pts[i - 2] - pts[i + 2]
    tc = tc / np.linalg.norm(tc)
    return _ajustar(pts[:i + 1], t1, tc, tol) + _ajustar(pts[i:], -tc, t2, tol)


def _trazo_u(contorno):
    poly = measure.approximate_polygon(contorno, tolerance=1.2)[:-1]
    arriba = sorted(sorted(range(len(poly)), key=lambda i: poly[i][1])[:4], key=lambda i: poly[i][0])
    esquinas = [poly[i] for i in arriba]  # fuera izq., dentro izq., dentro der., fuera der.
    k = [_indice(contorno, p) for p in esquinas]
    n = len(contorno) - 1
    if (k[1] - k[0]) % n > (k[3] - k[0]) % n:  # que el contorno vaya de fuera izq. a dentro izq.
        contorno = contorno[::-1].copy()
        k = [_indice(contorno, p) for p in esquinas]
    tapa_izq, dentro, tapa_der, fuera = (_tramo(contorno, k[a], k[b]) for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)))

    def lado(pts, desde_inicio):
        d = np.linalg.norm(pts - (pts[0] if desde_inicio else pts[-1]), axis=1)
        return _recta(pts[(d > 3) & (d < 14)])

    r_ti, r_td = _recta(_sin_extremos(tapa_izq)), _recta(_sin_extremos(tapa_der))
    r_di, r_dd, r_fd, r_fi = lado(dentro, True), lado(dentro, False), lado(fuera, True), lado(fuera, False)
    p_fi, p_di, p_dd, p_fd = _corte(r_fi, r_ti), _corte(r_ti, r_di), _corte(r_dd, r_td), _corte(r_td, r_fd)

    def curva(pts, p_ini, p_fin, r_ini, r_fin):
        medio = _sin_extremos(pts)
        pts = np.vstack([p_ini, medio, p_fin])
        t1 = r_ini[1] if np.dot(r_ini[1], medio[0] - p_ini) > 0 else -r_ini[1]
        t2 = r_fin[1] if np.dot(r_fin[1], medio[-1] - p_fin) > 0 else -r_fin[1]
        return _ajustar(pts, t1, t2, 0.45)

    cmds = [('M', [tuple(p_fi)]), ('L', [tuple(p_di)])]
    cmds += [('C', [tuple(c[1]), tuple(c[2]), tuple(c[3])]) for c in curva(dentro, p_di, p_dd, r_di, r_dd)]
    cmds.append(('L', [tuple(p_fd)]))
    cmds += [('C', [tuple(c[1]), tuple(c[2]), tuple(c[3])]) for c in curva(fuera, p_fd, p_fi, r_fd, r_fi)]
    return cmds + [('Z', [])]


def vectorizar_monograma(ruta):
    """[T izquierda, u, T derecha] en píxeles de la imagen original."""
    c = gaussian_filter(_cobertura(ruta), 0.5)
    contornos = sorted((k[:, ::-1] for k in measure.find_contours(c, 0.5) if len(k) > 50), key=lambda k: k[:, 0].min())
    assert len(contornos) == 3, f'El monograma debería tener 3 piezas y tiene {len(contornos)}'
    return [_poligono_t(contornos[0]), _trazo_u(contornos[1]), _poligono_t(contornos[2])]


# ---------------------------------------------------------------------------------------------
# Salidas
# ---------------------------------------------------------------------------------------------

def svg_de(trazos, ancho, alto, color, titulo, fondo=None, extra=''):
    paths = ''.join(f'<path d="{a_d(c)}"/>' for c in trazos)
    rect = f'<rect width="{num(ancho)}" height="{num(alto)}" fill="{fondo}"/>' if fondo else ''
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {num(ancho)} {num(alto)}" '
            f'width="{num(ancho)}" height="{num(alto)}"><title>{titulo}</title>{rect}{extra}'
            f'<g fill="{color}">{paths}</g></svg>\n')


def colocar(trazos, ancho, alto, cx, cy, escala):
    """Escala el dibujo (caja 0..ancho, 0..alto) y lo centra en (cx, cy)."""
    return [transformar(c, lambda p: (cx + (p[0] - ancho / 2) * escala, cy + (p[1] - alto / 2) * escala)) for c in trazos]


def vector_android(trazos, comentario, color='#FFFFFFFF'):
    paths = ''.join(f'\n    <path\n        android:fillColor="{color}"\n        android:pathData="{a_d(c, 3)}" />' for c in trazos)
    return (f'<?xml version="1.0" encoding="utf-8"?>\n<!-- {comentario} -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            '    android:width="108dp"\n    android:height="108dp"\n'
            '    android:viewportWidth="108"\n    android:viewportHeight="108">'
            f'{paths}\n</vector>\n')


def png(svg, lado, ruta):
    datos = cairosvg.svg2png(bytestring=svg.encode(), output_width=lado, output_height=lado)
    im = Image.open(io.BytesIO(datos))
    ruta.parent.mkdir(parents=True, exist_ok=True)
    im.save(ruta, optimize=True)


def icono_svg(mono, ancho, alto, lado, fondo, color, ocupa, radio=0.0):
    """Icono cuadrado: [fondo] (con esquinas de radio relativo [radio]) y el monograma centrado ocupando [ocupa]
    del ancho."""
    escala = lado * ocupa / ancho
    trazos = colocar(mono, ancho, alto, lado / 2, lado / 2, escala)
    r = num(lado * radio)
    rect = f'<rect width="{lado}" height="{lado}" rx="{r}" ry="{r}" fill="{fondo}"/>'
    return svg_de(trazos, lado, lado, color, 'TuTurno', extra=rect)


def dart_trazos(letras, ancho, alto, mono, ancho_m, alto_m):
    def trazo(c):
        x0, y0, x1, y1 = caja(c)
        return (f"Trazo('{a_d(c)}', Rect.fromLTRB({num(x0)}, {num(y0)}, {num(x1)}, {num(y1)}))")

    nombres = ['T', 'u', 'T', 'u', 'r', 'n', 'o']
    lineas = [
        '// GENERADO por assets/marca/herramientas/generar_marca.py a partir de assets/marca/fuente/. No lo edites',
        '// a mano: si cambia el logotipo, vuelve a ejecutar el script.',
        '',
        "import 'dart:ui' show Rect;",
        '',
        '/// Un trazo de la marca: su contorno (datos de un `path` SVG con M, L, C y Z absolutos) y la caja que ocupa,',
        '/// en las unidades de su dibujo.',
        'class Trazo {',
        '  const Trazo(this.datos, this.caja);',
        '',
        '  final String datos;',
        '  final Rect caja;',
        '}',
        '',
        '/// El logotipo TuTurno (opción 4 de logotipos.svg, letras recortadas): una entrada por letra.',
        'abstract final class TrazosLogo {',
        f'  static const ancho = {num(ancho)};',
        f'  static const alto = {num(alto)};',
        '',
        f"  /// {', '.join(nombres)}.",
        '  static const letras = <Trazo>[',
    ]
    lineas += [f'    {trazo(c)},' for c in letras]
    lineas += [
        '  ];',
        '}',
        '',
        '/// El monograma TuT: dos T altas y una u pequeña (vectorizado de monograma-tut.jpeg).',
        'abstract final class TrazosMonograma {',
        f'  static const ancho = {num(ancho_m)};',
        f'  static const alto = {num(alto_m)};',
        '',
        f'  static const tIzquierda = {trazo(mono[0])};',
        f'  static const u = {trazo(mono[1])};',
        f'  static const tDerecha = {trazo(mono[2])};',
        '',
        '  static const piezas = [tIzquierda, u, tDerecha];',
        '}',
        '',
    ]
    return '\n'.join(lineas)


def main(app):
    marca = app / 'assets' / 'marca'
    fuente = marca / 'fuente'
    opciones = leer_logotipos(fuente / 'logotipos.svg')
    nombres_alt = {1: 'opcion-1-pincel', 2: 'opcion-2-condensada', 3: 'opcion-3-burbuja'}

    # Logotipo (opción 4) en cuatro colores y las alternativas archivadas.
    letras, ancho, alto = normalizar(opciones[3])
    for nombre, color in TONOS.items():
        escribir(marca / 'logotipo' / f'tuturno-{nombre}.svg', svg_de(letras, ancho, alto, color, 'TuTurno'))
    for i in (1, 2, 3):
        alt, w, h = normalizar(opciones[i - 1])
        escribir(marca / 'alternativas' / f'{nombres_alt[i]}.svg', svg_de(alt, w, h, AMARILLO, 'TuTurno (alternativa)'))

    # Monograma.
    mono, ancho_m, alto_m = normalizar(vectorizar_monograma(fuente / 'monograma-tut.jpeg'))
    for nombre, color in TONOS.items():
        escribir(marca / 'monograma' / f'tut-{nombre}.svg', svg_de(mono, ancho_m, alto_m, color, 'TuT'))

    # Icono para tiendas y documentos (1024 px, esquinas redondeadas como un icono de app).
    icono = icono_svg(mono, ancho_m, alto_m, 1024, AZUL, AMARILLO, 0.6, radio=0.22)
    escribir(marca / 'icono' / 'icono-app.svg', icono)
    png(icono, 1024, marca / 'icono' / 'icono-app-1024.png')

    # Dart.
    escribir(app / 'lib' / 'widgets' / 'marca' / 'trazos_marca.dart', dart_trazos(letras, ancho, alto, mono, ancho_m, alto_m))

    # Android: icono adaptativo (lienzo de 108 dp; el círculo seguro mide 66 dp). El monograma ocupa 52 dp de ancho:
    # su caja (52 x 36,4) cabe entera en el círculo seguro, así no se corta con ninguna máscara.
    res = app / 'android' / 'app' / 'src' / 'main' / 'res'
    escala = 52 / ancho_m
    colocado = colocar(mono, ancho_m, alto_m, 54, 54, escala)
    escribir(res / 'drawable' / 'ic_launcher_foreground.xml', vector_android(
        colocado, 'Primer plano del icono adaptativo: el monograma TuT en amarillo TuTurno (#FFDE59). Lienzo de\n'
        '     108 dp; el dibujo (52 x 36 dp) cabe entero en el círculo seguro de 66 dp. Generado por\n'
        '     app/assets/marca/herramientas/generar_marca.py.', '#FFFFDE59'))
    escribir(res / 'drawable' / 'ic_launcher_monochrome.xml', vector_android(
        colocar(mono, ancho_m, alto_m, 54, 54, 48 / ancho_m),
        'Capa monocroma (iconos temáticos de Android 13 o superior): el sistema solo usa la transparencia\n'
        '     y la colorea con el tema del móvil. El mismo monograma, un poco más pequeño para que respire.'))
    escribir(res / 'drawable' / 'splash_monograma.xml', vector_android(
        colocado, 'Monograma de la pantalla de arranque en tema claro: azul noche sobre amarillo (ver\n'
        '     values/colors.xml). En tema oscuro manda drawable-night/splash_monograma.xml.', '#FF0E1A4F'))
    escribir(res / 'drawable-night' / 'splash_monograma.xml', vector_android(
        colocado, 'Monograma de la pantalla de arranque en tema oscuro: amarillo sobre azul noche (ver\n'
        '     values-night/colors.xml).', '#FFFFDE59'))
    # Android 7 (sin iconos adaptativos): PNG con el fondo azul redondeado.
    for carpeta, lado in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        png(icono_svg(mono, ancho_m, alto_m, 192, AZUL, AMARILLO, 0.6, radio=0.22), lado,
            res / f'mipmap-{carpeta}' / 'ic_launcher.png')

    # Web: favicon (SVG nítido y PNG de reserva), iconos normales (redondeados) y enmascarables (a sangre, con el
    # dibujo dentro del círculo seguro del 80 %).
    web = app / 'web'
    favicon = icono_svg(mono, ancho_m, alto_m, 64, AZUL, AMARILLO, 0.7, radio=0.22)
    escribir(web / 'favicon.svg', favicon)
    png(favicon, 64, web / 'favicon.png')
    for lado in (192, 512):
        png(icono_svg(mono, ancho_m, alto_m, 512, AZUL, AMARILLO, 0.6, radio=0.22), lado, web / 'icons' / f'Icon-{lado}.png')
        png(icono_svg(mono, ancho_m, alto_m, 512, AZUL, AMARILLO, 0.5), lado, web / 'icons' / f'Icon-maskable-{lado}.png')

    print(json.dumps({'logotipo': [num(ancho), num(alto)], 'monograma': [num(ancho_m), num(alto_m)]}))


def escribir(ruta, texto):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    ruta.write_text(texto, encoding='utf-8')


if __name__ == '__main__':
    main(Path(sys.argv[1] if len(sys.argv) > 1 else '.').resolve())
