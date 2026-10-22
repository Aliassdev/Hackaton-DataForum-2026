import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tuturno/pixel/ui/ui.dart';
import 'package:tuturno/tema.dart';

import 'ayudantes.dart';

/// Una pantalla con un botón grande en el centro que apunta los toques en [toques].
class _Pantalla extends StatelessWidget {
  const _Pantalla(this.nombre, this.color, [this.toques]);

  final String nombre;
  final Color color;
  final List<String>? toques;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: Center(
      child: SizedBox(
        width: 240,
        height: 120,
        child: TextButton(onPressed: () => toques?.add(nombre), child: Text(nombre)),
      ),
    ),
  );
}

Future<GoRouter> _montarRouter(WidgetTester tester, {bool reducir = false, List<String>? toques}) async {
  ponerPantalla(tester, tamanoMovil);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => _Pantalla('Inicio', ColoresUiPixel.papel, toques)),
      GoRoute(
        path: '/juego',
        pageBuilder: (context, state) =>
            paginaPixel(context, state, _Pantalla('Juego', ColoresUiPixel.amarillo, toques)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: temaTuTurno(Brightness.light),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducir),
        child: child!,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// La parte de la pantalla (de 0 a 1) que es exactamente de [color].
Future<double> _proporcion(WidgetTester tester, Color color) async {
  final capa = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final pixeles = await tester.runAsync(() async {
    final imagen = await capa.toImage(Offset.zero & tester.view.physicalSize);
    final datos = await imagen.toByteData();
    imagen.dispose();
    return datos!;
  });
  final buscado = rgba(color);
  final bytes = pixeles!;
  var cuenta = 0;
  for (var i = 0; i < bytes.lengthInBytes; i += 4) {
    if (bytes.getUint32(i, Endian.big) == buscado) cuenta++;
  }
  return cuenta / (bytes.lengthInBytes / 4);
}

void main() {
  test('es corta y, con «reducir animaciones», un fundido aún más corto', () {
    const pagina = PaginaPixel<void>(child: SizedBox());
    expect(pagina.transitionDuration, DuracionTransicionPixel.entrada);
    expect(pagina.reverseTransitionDuration, DuracionTransicionPixel.salida);
    expect(DuracionTransicionPixel.entrada, lessThanOrEqualTo(const Duration(milliseconds: 500)));
    const quieta = PaginaPixel<void>(reducirMovimiento: true, child: SizedBox());
    expect(quieta.transitionDuration, DuracionTransicionPixel.fundido);
    expect(quieta.reverseTransitionDuration, DuracionTransicionPixel.fundido);
  });

  testWidgets('entra y sale, fotograma a fotograma, sin errores; al acabar la página se usa con normalidad', (
    tester,
  ) async {
    final router = await _montarRouter(tester);
    router.push('/juego');
    // go_router procesa la ruta en una microtarea: la página nueva se construye en el segundo fotograma.
    await tester.pump();
    await tester.pump();
    expect(find.byType(TransicionPixel), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.pump(DuracionTransicionPixel.entrada ~/ 8);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Juego'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(find.text('Juego'));
    await tester.pump();

    router.pop();
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(DuracionTransicionPixel.salida ~/ 6);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Juego'), findsNothing);
  });

  testWidgets('se apaga a bloques hasta el azul noche y la página nueva aparece a bloques', (tester) async {
    final router = await _montarRouter(tester);
    router.push('/juego');
    // go_router procesa la ruta en una microtarea: la página nueva se construye en el segundo fotograma.
    await tester.pump();
    await tester.pump();
    const total = DuracionTransicionPixel.entrada;

    // Un cuarto: la mitad de los bloques ya tapan la pantalla de antes.
    await tester.pump(total * 0.25);
    final cuarto = await _proporcion(tester, ColoresUiPixel.noche);
    expect(cuarto, inInclusiveRange(0.3, 0.75));
    expect(await _proporcion(tester, ColoresUiPixel.amarillo), 0, reason: 'la nueva aún no se ve');

    // A la mitad: todo azul noche.
    await tester.pump(total * 0.25);
    expect(await _proporcion(tester, ColoresUiPixel.noche), greaterThan(0.97));

    // Al 80 %: más de la mitad de la página nueva.
    await tester.pump(total * 0.3);
    final nueva = await _proporcion(tester, ColoresUiPixel.amarillo);
    expect(nueva, inInclusiveRange(0.45, 0.85));
    await tester.pumpAndSettle();
    expect(await _proporcion(tester, ColoresUiPixel.amarillo), greaterThan(0.9));
  });

  testWidgets('a medias no se puede tocar nada: ni la página nueva (que aún no se ve) ni la de debajo', (tester) async {
    final toques = <String>[];
    final router = await _montarRouter(tester, toques: toques);
    router.push('/juego');
    await tester.pump();
    await tester.pump();
    final centro = tester.getCenter(find.byType(TransicionPixel));
    // Al 25 %: la página nueva no se ve, pero su botón está justo donde el niño aún ve el de «Inicio».
    await tester.pump(DuracionTransicionPixel.entrada * 0.25);
    await tester.tapAt(centro);
    await tester.pump();
    // Al 75 %: aún tapada en parte.
    await tester.pump(DuracionTransicionPixel.entrada * 0.5);
    await tester.tapAt(centro);
    await tester.pump();
    expect(toques, isEmpty);
    await tester.pumpAndSettle();
    // Al acabar, la página se usa con normalidad.
    await tester.tapAt(centro);
    await tester.pump();
    expect(toques, ['Juego']);
    // Al volver, igual: mientras sale, nada.
    router.pop();
    await tester.pump();
    await tester.pump(DuracionTransicionPixel.salida * 0.5);
    await tester.tapAt(centro);
    await tester.pump();
    expect(toques, ['Juego']);
    await tester.pumpAndSettle();
    await tester.tapAt(centro);
    await tester.pump();
    expect(toques, ['Juego', 'Inicio']);
  });

  testWidgets('con «reducir animaciones», un fundido sin bloques', (tester) async {
    final router = await _montarRouter(tester, reducir: true);
    router.push('/juego');
    // go_router procesa la ruta en una microtarea: la página nueva se construye en el segundo fotograma.
    await tester.pump();
    await tester.pump();
    await tester.pump(DuracionTransicionPixel.fundido ~/ 2);
    expect(find.byType(TransicionPixel), findsNothing);
    final fundido = find.ancestor(of: find.text('Juego'), matching: find.byType(FadeTransition));
    expect(fundido, findsWidgets);
    final opacidad = tester.widget<FadeTransition>(fundido.first).opacity.value;
    expect(opacidad, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('Juego'), findsOneWidget);
  });

  testWidgets('TransicionPixel con la animación parada al final pinta la página tal cual', (tester) async {
    await montar(
      tester,
      const RepaintBoundary(
        child: SizedBox(
          width: 120,
          height: 120,
          child: TransicionPixel(
            animacion: AlwaysStoppedAnimation(1),
            child: ColoredBox(color: ColoresUiPixel.azul),
          ),
        ),
      ),
    );
    expect(await contarPixeles(tester, find.byType(TransicionPixel), ColoresUiPixel.azul), 360 * 360);
    await montar(
      tester,
      const RepaintBoundary(
        child: SizedBox(
          width: 120,
          height: 120,
          child: TransicionPixel(
            animacion: AlwaysStoppedAnimation(0),
            child: ColoredBox(color: ColoresUiPixel.azul),
          ),
        ),
      ),
    );
    expect(await contarPixeles(tester, find.byType(TransicionPixel), ColoresUiPixel.azul), 0);
  });
}
