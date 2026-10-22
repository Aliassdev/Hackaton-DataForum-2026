import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/motor/paleta_pixel.dart';
import 'package:tuturno/pixel/ui/pintura_pixel.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/tema.dart';

import 'ayudantes.dart';

double _contraste(Color a, Color b) => contrastePixel(a, b);

/// El filo con el que se pintó la caja [i] (de las que hay en pantalla).
Color? _filo(WidgetTester tester, [int i = 0]) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((pintura) => pintura.painter)
    .whereType<PintorCajaPixel>()
    .elementAt(i)
    .filo;

void main() {
  test('los colores del kit son los de PaletaPixel (un solo mundo)', () {
    final pares = {
      ColoresUiPixel.noche: PaletaPixel.noche,
      ColoresUiPixel.marino: PaletaPixel.marino,
      ColoresUiPixel.azul: PaletaPixel.azul,
      ColoresUiPixel.azulClaro: PaletaPixel.azulClaro,
      ColoresUiPixel.cielo: PaletaPixel.cielo,
      ColoresUiPixel.hielo: PaletaPixel.hielo,
      ColoresUiPixel.amarillo: PaletaPixel.amarillo,
      ColoresUiPixel.amarilloLuz: PaletaPixel.amarilloLuz,
      ColoresUiPixel.ocre: PaletaPixel.ocre,
      ColoresUiPixel.blanco: PaletaPixel.blanco,
      ColoresUiPixel.papel: PaletaPixel.papel,
      ColoresUiPixel.crema: PaletaPixel.crema,
      ColoresUiPixel.grisClaro: PaletaPixel.grisClaro,
      ColoresUiPixel.gris: PaletaPixel.gris,
      ColoresUiPixel.grisOscuro: PaletaPixel.grisOscuro,
      ColoresUiPixel.teja: PaletaPixel.teja,
      ColoresUiPixel.coral: PaletaPixel.coral,
      ColoresUiPixel.negro: PaletaPixel.negro,
      ColoresUiPixel.verdeOscuro: PaletaPixel.verdeOscuro,
      ColoresUiPixel.verde: PaletaPixel.verde,
    };
    for (final MapEntry(key: kit, value: paleta) in pares.entries) {
      expect(kit, paleta.color, reason: '${paleta.nombre} no coincide con PaletaPixel');
    }
  });

  test('todo el texto del kit tiene contraste AA (4,5:1) sobre su fondo', () {
    const n = ColoresUiPixel.noche;
    const p = ColoresUiPixel.papel;
    const b = ColoresUiPixel.blanco;
    final pares = <String, (Color, Color)>{
      'botón primario': (n, ColoresUiPixel.amarillo),
      'botón primario, ratón encima': (n, ColoresBotonPixel.primario.encima),
      'botón secundario': (n, ColoresUiPixel.papel),
      'botón de peligro': (b, ColoresUiPixel.teja),
      'diálogo': (p, n),
      'placa del nombre': (n, ColoresUiPixel.amarillo),
      'título del HUD': (ColoresUiPixel.amarillo, n),
      'opción correcta': (b, ColoresUiPixel.verdeOscuro),
      'opción incorrecta': (b, ColoresUiPixel.teja),
      'opción apagada': (ColoresUiPixel.grisOscuro, p),
      'carta bloqueada': (n, ColoresUiPixel.gris),
      'texto de la carta bloqueada': (n, ColoresUiPixel.grisClaro),
      'número de la carta': (p, n),
    };
    for (final MapEntry(key: nombre, value: (tinta, fondo)) in pares.entries) {
      expect(_contraste(tinta, fondo), greaterThanOrEqualTo(4.5), reason: nombre);
    }
    // Los iconos y bordes que dan información, 3:1 como mínimo.
    expect(_contraste(ColoresUiPixel.verdeOscuro, p), greaterThanOrEqualTo(3), reason: 'el ✓ de la correcta');
    expect(_contraste(ColoresUiPixel.amarillo, n), greaterThanOrEqualTo(3), reason: 'el relleno de la barra');
    expect(_contraste(ColoresUiPixel.azulClaro, n), greaterThanOrEqualTo(3), reason: 'los segmentos que faltan');
    expect(_contraste(p, n), greaterThanOrEqualTo(4.5), reason: 'las cifras del contador del HUD');
    // El filo que separa las piezas del azul noche del juego (y del tema oscuro).
    const fondoOscuro = Color(0xFF0B1543);
    for (final fondo in [n, fondoOscuro, ColoresUiPixel.marino]) {
      final filo = FondoPixel(color: fondo, child: const SizedBox()).colorFilo;
      expect(_contraste(filo, fondo), greaterThanOrEqualTo(2), reason: 'el filo sobre $fondo');
    }
  });

  testWidgets('la letra sale de un solo sitio: pixel por defecto y Atkinson con lectura fácil', (tester) async {
    late TextStyle pixel;
    late TextStyle facil;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Builder(
              builder: (context) {
                pixel = estiloTextoPixel(context, TipoTextoPixel.cuerpo);
                expect(familiaPixel(context), FuentesPixel.pixel);
                return const SizedBox();
              },
            ),
            TemaPixel(
              lecturaFacil: true,
              child: Builder(
                builder: (context) {
                  facil = estiloTextoPixel(context, TipoTextoPixel.cuerpo);
                  expect(familiaPixel(context), Fuentes.lecturaFacil);
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(pixel.fontFamily, 'PixelifySans');
    expect(facil.fontFamily, 'AtkinsonHyperlegible');
    expect(pixel.letterSpacing, greaterThan(0));
    expect(facil.letterSpacing, 0);
    // Si la letra pixel no está (o le falta un signo), se ve la letra de la app (no la del sistema).
    expect(pixel.fontFamilyFallback, [Fuentes.texto]);
  });

  test('las cifras de un texto en letra pixel van en Atkinson; con lectura fácil no cambia nada', () {
    const pixel = TextStyle(fontFamily: FuentesPixel.pixel, fontSize: 20);
    final span = textoConCifras('Sara tiene 15 años. Ley 4/2015, art. 20', pixel);
    expect(span.toPlainText(), 'Sara tiene 15 años. Ley 4/2015, art. 20');
    final cifras = [
      for (final hijo in span.children!.cast<TextSpan>())
        if (hijo.style?.fontFamily == FuentesPixel.cifras) hijo.text,
    ];
    expect(cifras, ['15', '4', '2015', '20']);
    expect(FuentesPixel.cifras, 'AtkinsonHyperlegible');
    // Sin cifras, o con otra letra, un solo trozo.
    expect(textoConCifras('Sin números', pixel).children, isNull);
    const facil = TextStyle(fontFamily: FuentesPixel.lecturaFacil, fontSize: 20);
    expect(textoConCifras('15 años', facil).children, isNull);
  });

  test('tamaños cómodos: nada por debajo de 18 y el cuerpo con mucho interlineado', () {
    for (final tipo in TipoTextoPixel.values) {
      expect(tipo.tamano, greaterThanOrEqualTo(18), reason: tipo.name);
    }
    expect(TipoTextoPixel.cuerpo.alto, greaterThanOrEqualTo(1.4));
  });

  testWidgets('la unidad pixel mide 2-4 puntos en un móvil y un número entero de píxeles físicos', (tester) async {
    Future<double> unidad(Size tamano, double dpr, {double? pedida}) async {
      ponerPantalla(tester, tamano, dpr: dpr);
      late double u;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: tamano, devicePixelRatio: dpr),
          child: TemaPixel(
            unidad: pedida,
            child: Builder(
              builder: (context) {
                u = unidadPixel(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      return u;
    }

    expect(await unidad(const Size(390, 844), 3), 3);
    expect(await unidad(const Size(320, 640), 2), 2);
    expect(await unidad(const Size(800, 1280), 2), 4);
    // Con densidad 2,625, 3 puntos serían 7,875 píxeles: se redondea a 8 (3,05 puntos), siempre igual.
    final u = await unidad(const Size(412, 915), 2.625);
    expect(u * 2.625, closeTo(8, 1e-9));
    expect(u, inInclusiveRange(2, 4));
    expect(await unidad(const Size(390, 844), 3, pedida: 2), 2);
  });

  test('los perfiles de las esquinas encajan unos dentro de otros', () {
    for (var radio = 0; radio < 6; radio++) {
      expect(perfilInterior(perfilEsquina(radio + 1)), perfilEsquina(radio), reason: 'radio $radio');
    }
  });

  testWidgets('las cajas se pintan sin suavizado, aunque su sitio caiga entre dos píxeles (también con Impeller)', (
    tester,
  ) async {
    // Con densidad 2,625, 12,4 puntos son 32,55 píxeles: sin el ajuste, Impeller mezclaría los bordes. (Con Skia ya
    // salen enteros; para probarlo con Impeller: flutter test --enable-impeller.)
    await montar(
      tester,
      // Lo que se mide (el RepaintBoundary) queda dentro del fondo, lejos de su borde (que sí se suaviza).
      const ColoredBox(
        color: ColoresUiPixel.cielo,
        child: Padding(
          padding: EdgeInsets.all(2),
          child: RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12.4, 12.3, 12, 12),
              child: SizedBox(
                width: 151,
                height: 61,
                child: CajaPixel(
                  estilo: EstiloCajaPixel(
                    relleno: ColoresUiPixel.amarillo,
                    luz: ColoresUiPixel.amarilloLuz,
                    sombraInterior: ColoresUiPixel.ocre,
                    esquina: 3,
                  ),
                  foco: true,
                ),
              ),
            ),
          ),
        ),
      ),
      dpr: 2.625,
    );
    final colores = await coloresPintados(tester, find.byType(CajaPixel));
    final permitidos = {
      for (final color in [
        ColoresUiPixel.cielo,
        ColoresUiPixel.noche,
        ColoresUiPixel.amarillo,
        ColoresUiPixel.amarilloLuz,
        ColoresUiPixel.ocre,
      ])
        rgba(color),
    };
    expect(colores.difference(permitidos), isEmpty, reason: 'hay píxeles a medias (con suavizado)');
    // Las esquinas escalonadas dejan ver el fondo.
    expect(colores, contains(rgba(ColoresUiPixel.cielo)));
  });

  testWidgets('AjustePixel pinta cada pieza con su origen en un píxel físico, sin cambiar su sitio', (tester) async {
    await montar(
      tester,
      const Padding(
        padding: EdgeInsets.only(left: 0.7, top: 27.5),
        child: CajaPixel(
          estilo: EstiloCajaPixel(relleno: ColoresUiPixel.amarillo),
          child: SizedBox(width: 60.3, height: 30),
        ),
      ),
      dpr: 2.625,
    );
    final ajuste = tester.renderObject<RenderAjustePixel>(find.byType(AjustePixel));
    final pintado = ajuste.child!.localToGlobal(Offset.zero) * 2.625;
    expect(pintado.dx, closeTo(pintado.dx.roundToDouble(), 1e-6));
    expect(pintado.dy, closeTo(pintado.dy.roundToDouble(), 1e-6));
    // Se mueve menos de medio píxel físico; el sitio que ocupa es el mismo.
    expect(ajuste.desfase.dx.abs() * 2.625, lessThanOrEqualTo(0.5 + 1e-9));
    expect(ajuste.desfase.dy.abs() * 2.625, lessThanOrEqualTo(0.5 + 1e-9));
    expect(tester.getSize(find.byType(AjustePixel)), tester.getSize(find.byType(CajaPixel)));
  });

  testWidgets('sobre azul noche, las piezas cuyo contorno no se ve llevan filo (y ocupan una unidad más)', (
    tester,
  ) async {
    const estilo = EstiloCajaPixel(relleno: ColoresUiPixel.amarillo);
    Widget caja({EstiloCajaPixel e = estilo, bool? conFilo}) =>
        CajaPixel(estilo: e, conFilo: conFilo, child: const SizedBox(width: 60, height: 30));

    await montar(tester, caja());
    expect(_filo(tester), isNull, reason: 'sin FondoPixel, como siempre');
    final sinFilo = tester.getSize(find.byType(CajaPixel));

    await montar(tester, FondoPixel(color: ColoresUiPixel.papel, child: caja()));
    expect(_filo(tester), isNull, reason: 'el azul noche se ve sobre el papel');

    await montar(tester, FondoPixel(color: ColoresUiPixel.noche, child: caja()));
    expect(_filo(tester), ColoresUiPixel.azul);
    expect(tester.getSize(find.byType(CajaPixel)), sinFilo + const Offset(6, 6));

    // Con el tema oscuro de la app, igual.
    await montar(tester, FondoPixel(color: const Color(0xFF0B1543), child: caja()));
    expect(_filo(tester), ColoresUiPixel.azul);

    // Si ya se ve su borde (un contorno gris o un anillo de papel, como el diálogo), no le hace falta.
    await montar(
      tester,
      FondoPixel(
        color: ColoresUiPixel.noche,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            caja(
              e: const EstiloCajaPixel(relleno: ColoresUiPixel.papel, contorno: ColoresUiPixel.gris),
            ),
            caja(
              e: const EstiloCajaPixel(relleno: ColoresUiPixel.noche, anillo: ColoresUiPixel.papel),
            ),
            caja(conFilo: false),
          ],
        ),
      ),
    );
    expect([_filo(tester), _filo(tester, 1), _filo(tester, 2)], [null, null, null]);
  });

  testWidgets('el scroll del juego no se estira al llegar al final (el estirado emborronaría el pixel art)', (
    tester,
  ) async {
    await montar(
      tester,
      TemaPixel(
        child: RepaintBoundary(
          child: ColoredBox(
            color: ColoresUiPixel.cielo,
            child: ListView(
              addRepaintBoundaries: false,
              children: [
                for (var i = 0; i < 12; i++)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CajaPixel(
                      estilo: EstiloCajaPixel(relleno: ColoresUiPixel.amarillo),
                      child: SizedBox(height: 40),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      centrar: false,
    );
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    // Se tira más allá del final y se mira a mitad del gesto: ningún color a medias.
    final lista = tester.getCenter(find.byType(ListView));
    final dedo = await tester.startGesture(lista);
    for (var i = 0; i < 12; i++) {
      await dedo.moveBy(const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final colores = await coloresPintados(tester, find.byType(ListView));
    await dedo.up();
    await tester.pumpAndSettle();
    expect(
      colores.difference({
        for (final c in [ColoresUiPixel.cielo, ColoresUiPixel.noche, ColoresUiPixel.amarillo]) rgba(c),
      }),
      isEmpty,
    );
  });
}
