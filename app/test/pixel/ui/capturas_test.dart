// Capturas del kit pixel con las fuentes reales (Pixelify Sans), para revisar el diseño y para los PR. No se ejecuta
// por defecto:
//
//   CAPTURAS=build/capturas flutter test test/pixel/ui/capturas_test.dart
//
// Deja los PNG en <CAPTURAS>/pixel_ui (build/ no se sube a git): la galería entera por pantallas (tema claro, oscuro
// y letra grande), una hoja con los estados de cada pieza, el HUD con los botones de la app y los fotogramas de la
// transición.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/widgets/ayuda_button.dart';

import 'ayudantes.dart';

final _destino = Platform.environment['CAPTURAS'];

String _ruta(String nombre) => '$_destino/pixel_ui/$nombre.png';

/// Recorre la galería de arriba abajo y hace una captura por pantalla.
Future<void> _recorrerGaleria(WidgetTester tester, String prefijo) async {
  // Que el diálogo acabe de escribirse.
  await tester.pump(const Duration(seconds: 4));
  final posicion = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  final paso = posicion.viewportDimension - 120;
  var pagina = 1;
  for (var desplazamiento = 0.0; ; desplazamiento += paso) {
    posicion.jumpTo(desplazamiento.clamp(0, posicion.maxScrollExtent));
    // Lo que aparece al desplazar se construye ahora: que sus diálogos acaben de escribirse (y sus cartas de brillar).
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await capturarPantalla(tester, _ruta('$prefijo-${pagina++}'));
    if (desplazamiento >= posicion.maxScrollExtent) break;
  }
}

/// Una hoja con los estados de cada pieza (pulsado, foco, encima, respuestas, escribiendo…).
class _Estados extends StatefulWidget {
  const _Estados({required this.focoBoton});

  final FocusNode focoBoton;

  @override
  State<_Estados> createState() => _EstadosState();
}

class _EstadosState extends State<_Estados> {
  double _barra = 0.2;

  @override
  void initState() {
    super.initState();
    // La barra sube un poco más tarde, para que la captura la pille a medio camino.
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _barra = 0.9);
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final tinta = Theme.of(context).colorScheme.onSurface;
    Widget titulo(String texto) => Padding(
      padding: EdgeInsets.only(top: 5 * u, bottom: 2 * u),
      child: Text(texto, style: estiloTextoPixel(context, TipoTextoPixel.etiqueta, color: tinta)),
    );
    return FondoPixel(
      color: Theme.of(context).colorScheme.surface,
      child: ScrollPixel(
        child: ListView(
          addRepaintBoundaries: false,
          padding: const EdgeInsets.all(16),
          children: [
            titulo('Reposo · pulsado · foco'),
            Wrap(
              spacing: 4 * u,
              runSpacing: 3 * u,
              children: [
                BotonPixel(etiqueta: 'Reposo', onPressed: () {}),
                BotonPixel(key: const ValueKey('pulsado'), etiqueta: 'Pulsado', onPressed: () {}),
                BotonPixel(etiqueta: 'Foco', focusNode: widget.focoBoton, onPressed: () {}),
              ],
            ),
            titulo('Con el ratón encima'),
            Wrap(
              spacing: 4 * u,
              runSpacing: 3 * u,
              children: [
                BotonPixel(key: const ValueKey('encima'), etiqueta: 'Encima', onPressed: () {}),
                BotonPixel(
                  key: const ValueKey('encima 2'),
                  etiqueta: 'Encima',
                  variante: VarianteBotonPixel.secundario,
                  onPressed: () {},
                ),
                BotonPixel(
                  key: const ValueKey('encima 3'),
                  etiqueta: 'Salir',
                  variante: VarianteBotonPixel.peligro,
                  onPressed: () {},
                ),
              ],
            ),
            titulo('Barra subiendo'),
            BarraPixel(key: const ValueKey('barra'), valor: _barra),
            titulo('Respuesta correcta'),
            const MenuOpcionesPixel(
              opciones: ['Quedarme callada', 'Pedir que me lo expliquen'],
              correctas: {1},
              elegida: 1,
              onElegir: null,
            ),
            titulo('Respuesta incorrecta'),
            const MenuOpcionesPixel(
              opciones: ['Quedarme callada', 'Pedir que me lo expliquen', 'Irme a casa'],
              correctas: {1},
              elegida: 0,
              onElegir: null,
            ),
            titulo('Escribiendo'),
            const DialogoPixel(
              hablante: 'Jueza',
              texto: 'Gracias por venir, Lucía. Vamos a ir despacio, y puedes parar cuando quieras.',
              onContinuar: null,
            ),
            titulo('Brillo del dibujo'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CartaPixel(
                    key: const ValueKey('carta 1'),
                    numero: 3,
                    titulo: 'Grabar una sola vez',
                    texto: 'Tu declaración se puede grabar para no repetirla.',
                    icono: GlifoPixel.estrella,
                    color: ColoresUiPixel.verdeOscuro,
                    luz: ColoresUiPixel.verde,
                    sombraColor: ColoresUiPixel.noche,
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: 3 * u),
                Expanded(
                  child: CartaPixel(
                    key: const ValueKey('carta 2'),
                    numero: 15,
                    titulo: 'Derecho a entender',
                    texto: 'Si no entiendes algo, pide que te lo expliquen.',
                    color: ColoresUiPixel.teja,
                    luz: ColoresUiPixel.coral,
                    sombraColor: ColoresUiPixel.negro,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            titulo('Ticket pulsado'),
            TicketPixel(
              key: const ValueKey('ticket'),
              onPressed: () {},
              talon: const RotuloPixel('N.º 1'),
              child: const Text('Caso 1 · Lucía, 11 años'),
            ),
            SizedBox(height: 8 * u),
          ],
        ),
      ),
    );
  }
}

/// Un HUD con los botones de verdad de la app (Glosario y Ayuda) encima de un trozo de escena.
Widget _hudConAcciones() => const Align(
  alignment: Alignment.topCenter,
  child: HudPixel(
    titulo: 'El caso de Lucía',
    progreso: 0.4,
    textoProgreso: '4 de 10 escenas',
    cartas: 2,
    totalCartas: 5,
    onVolver: _nada,
    acciones: [GlosarioButton(), AyudaButton()],
  ),
);

void _nada() {}

void main() {
  setUpAll(() async {
    if (_destino != null) await cargarFuentesPixel();
  });

  testWidgets('galería en tema claro', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    await _recorrerGaleria(tester, 'galeria-claro');
  }, skip: _destino == null);

  testWidgets('galería en tema oscuro', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false, brillo: Brightness.dark);
    await _recorrerGaleria(tester, 'galeria-oscuro');
  }, skip: _destino == null);

  testWidgets('galería con letra grande (1,3) en un móvil pequeño', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false, escalaTexto: 1.3, tamano: const Size(360, 780));
    await _recorrerGaleria(tester, 'galeria-letra-grande');
  }, skip: _destino == null);

  testWidgets('galería con lectura fácil (Atkinson Hyperlegible)', (tester) async {
    await montar(tester, const TemaPixel(lecturaFacil: true, child: GaleriaPixelUi()), centrar: false);
    await tester.pump(const Duration(seconds: 4));
    await capturarPantalla(tester, _ruta('galeria-lectura-facil'));
  }, skip: _destino == null);

  testWidgets('galería con densidad 2,625 (nitidez)', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false, dpr: 2.625, tamano: const Size(412, 892));
    await tester.pump(const Duration(seconds: 4));
    await capturarPantalla(tester, _ruta('galeria-densidad-2625'));
  }, skip: _destino == null);

  for (final (nombre, tamano, escala) in [
    ('hud-390-letra-1', const Size(390, 844), 1.0),
    ('hud-360-letra-1_3', const Size(360, 780), 1.3),
  ]) {
    testWidgets('HUD con Glosario y Ayuda ($nombre)', (tester) async {
      await montar(tester, _hudConAcciones(), centrar: false, tamano: tamano, escalaTexto: escala);
      await capturarPantalla(tester, _ruta(nombre));
    }, skip: _destino == null);
  }

  for (final brillo in Brightness.values) {
    testWidgets('estados de cada pieza (${brillo.name})', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      final foco = FocusNode();
      addTearDown(foco.dispose);
      // Tres ratones (como tres ordenadores) para ver las tres variantes con el ratón encima a la vez.
      final ratones = [
        for (var i = 0; i < 3; i++)
          TestGesture(
            dispatcher: tester.sendEventToBinding,
            pointer: 900 + i,
            kind: PointerDeviceKind.mouse,
            device: 50 + i,
          ),
      ];
      for (final raton in ratones) {
        await raton.addPointer(location: Offset.zero);
        addTearDown(raton.removePointer);
      }
      await montar(tester, _Estados(focoBoton: foco), centrar: false, brillo: brillo);
      foco.requestFocus();
      await tester.pump();
      for (final (i, clave) in ['encima', 'encima 2', 'encima 3'].indexed) {
        await ratones[i].moveTo(tester.getCenter(find.byKey(ValueKey(clave))));
      }
      // El diálogo, a medio escribir; la barra, a medio subir.
      await tester.pump(const Duration(milliseconds: 950));
      // El dedo se queda abajo lo bastante (dentro de un scroll, el «abajo» espera 100 ms a saber si es arrastre).
      final dedo = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('pulsado'))));
      await tester.pump(const Duration(milliseconds: 160));
      await capturarPantalla(tester, _ruta('estados-${brillo.name}-1'));
      await dedo.up();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('ticket')), 300);
      // Que el scroll esté quieto antes de mirar.
      await tester.pumpAndSettle();
      // El ratón encima de las cartas las hace brillar; el dedo, en el ticket.
      await ratones[0].moveTo(tester.getCenter(find.byKey(const ValueKey('carta 1'))));
      await ratones[1].moveTo(tester.getCenter(find.byKey(const ValueKey('carta 2'))));
      await tester.pump(const Duration(milliseconds: 100));
      final dedoTicket = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('ticket'))));
      // El brillo, a medio cruzar el dibujo (dura 0,9 s); el ticket, abajo.
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await capturarPantalla(tester, _ruta('estados-${brillo.name}-2'));
      await dedoTicket.up();
      await tester.pump(const Duration(seconds: 5));
    }, skip: _destino == null);
  }

  testWidgets('fotogramas de la transición a bloques', (tester) async {
    await montar(tester, const GaleriaPixelUi(), centrar: false);
    await tester.pump(const Duration(seconds: 4));
    await tester.scrollUntilVisible(find.text('Entrar en el juego'), 400);
    await tester.ensureVisible(find.text('Entrar en el juego'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar en el juego'));
    await tester.pump();
    const total = DuracionTransicionPixel.entrada;
    var transcurrido = Duration.zero;
    for (final (i, fraccion) in [0.15, 0.35, 0.62, 0.85].indexed) {
      final objetivo = total * fraccion;
      await tester.pump(objetivo - transcurrido);
      transcurrido = objetivo;
      await capturarPantalla(tester, _ruta('transicion-${i + 1}'));
    }
    await tester.pump(const Duration(seconds: 3));
    await capturarPantalla(tester, _ruta('transicion-5-juego'));
  }, skip: _destino == null);
}
