import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/textos.dart';
import 'package:tuturno/features/juego/widgets/carta.dart';

import 'fakes.dart';

/// Pantalla muy alta: la lista de casos se construye a medida que se ve y así está entera a la vista.
const _alto = Size(412, 3200);

const _todos = {'caso-prueba.json': casoPrueba, 'caso-extra.json': casoExtra, 'caso-borrador.json': casoBorrador};

void main() {
  testWidgets('enseña los casos validados, con protagonista, edad, papel, planteamiento y progreso', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(casos: _todos),
    );

    expect(find.text(tituloElegirCaso), findsOneWidget);
    expect(find.text('Nora y la prueba'), findsOneWidget);
    expect(find.text('Nora, 12 años'), findsOneWidget);
    expect(find.text('Testigo'), findsOneWidget);
    expect(find.text('Hoy le explican cómo será su día en el juzgado.'), findsOneWidget);
    expect(find.text('0 de 3 cartas'), findsNWidgets(2), reason: 'en la cabecera y en la tarjeta del caso');
    expect(find.text('Alba y el juzgado'), findsOneWidget);
    expect(find.text('Borrador oculto'), findsNothing, reason: 'sin "validado": true no se enseña');
    expect(find.text(ctaEmpezar), findsNWidgets(2));
    expect(find.text(estadoNuevo), findsNWidgets(2));
  });

  testWidgets('el caso oficial de Lucía sale el primero', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(
        casos: {'caso-extra.json': casoExtra, 'caso-sala-gesell.json': casoOficialDeEjemplo()},
      ),
    );
    final lucia = tester.getTopLeft(find.text('Lucía y la sala de la entrevista'));
    final alba = tester.getTopLeft(find.text('Alba y el juzgado'));
    expect(lucia.dy, lessThan(alba.dy));
    expect(find.text('Lucía, 11 años'), findsOneWidget);
    expect(find.text('Víctima'), findsNWidgets(2));
  });

  testWidgets('la colección enseña las cartas conseguidas y las bloqueadas en gris', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(preferencias: progresoGuardado(cartas: ['R-acompanada'], xp: 10)),
    );

    expect(find.text(tituloColeccion), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('1 de 3 cartas'), findsNWidgets(2), reason: 'en la cabecera y en la tarjeta del caso');
    expect(find.byType(CartaDerecho), findsOneWidget);
    expect(find.text('Puedes ir con alguien de confianza'), findsOneWidget);
    expect(find.byType(CartaBloqueada), findsNWidgets(2));
    expect(find.text('Por descubrir'), findsNWidgets(2));
    expect(find.text('Tienes derecho a entender'), findsNothing, reason: 'una carta bloqueada no se destripa');
    expect(find.text('10 puntos'), findsOneWidget);
  });

  testWidgets('una carta conseguida se abre en grande con su texto y su fuente', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(preferencias: progresoGuardado(cartas: ['R-acompanada'])),
    );

    await pulsar(tester, find.byType(CartaDerecho));

    expect(find.text('Una persona que tú elijas.'), findsOneWidget);
    expect(find.text('LECrim, art. 433'), findsWidgets);
    await pulsar(tester, find.text('Cerrar'));
    expect(find.text('Una persona que tú elijas.'), findsNothing);
  });

  testWidgets('una carta bloqueada dice dónde se consigue y deja ir a jugar', (tester) async {
    await abrirJuego(tester, tamano: _alto, overrides: await overridesJuego());

    await pulsar(tester, find.byType(CartaBloqueada).first);
    expect(find.text(textoCartaBloqueada('Nora')), findsOneWidget);

    await pulsar(tester, find.text('Jugar'));
    expect(find.text('Caso de Nora'), findsOneWidget);
  });

  testWidgets('al tocar un caso se abre; a medias dice «Seguir» y por qué escena vas', (tester) async {
    await abrirJuego(tester, tamano: _alto, overrides: await overridesJuego());

    await pulsar(tester, find.text('Nora y la prueba'));
    expect(find.text('Caso de Nora'), findsOneWidget);
    final contenedorApp = contenedor(tester);
    await contenedorApp.read(partidaProvider('caso-prueba').notifier).elegir(0);
    await contenedorApp.read(partidaProvider('caso-prueba').notifier).avanzar();
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.text('Caso de Nora'))).pop();
    await tester.pumpAndSettle();

    expect(find.text(ctaSeguirCaso), findsOneWidget);
    expect(find.text('Escena 2 de 4'), findsOneWidget);
    expect(find.text('1 de 3 cartas'), findsWidgets);

    await pulsar(tester, find.text('Nora y la prueba'));
    expect(find.text('Nora llega al juzgado con calma.'), findsOneWidget, reason: 'sigue donde lo dejó');
  });

  testWidgets('un caso terminado dice «Terminado» y se vuelve a jugar desde el principio', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(
        preferencias: progresoGuardado(cartas: ['R-entender'], casos: ['caso-prueba']),
      ),
    );
    expect(find.text(estadoTerminado), findsOneWidget);
    expect(find.text(ctaOtraVez), findsOneWidget);
    expect(find.text('1 de 1 caso'), findsOneWidget);

    await pulsar(tester, find.text('Nora y la prueba'));
    expect(find.text('Nora tiene 12 años. Hoy le explican cómo será su día en el juzgado.'), findsOneWidget);
  });

  testWidgets('sin casos, un estado vacío amable', (tester) async {
    await abrirJuego(
      tester,
      tamano: _alto,
      overrides: await overridesJuego(casos: const {}),
    );
    expect(find.text(sinCasosTitulo), findsOneWidget);
    expect(find.text(sinCasosMensaje), findsOneWidget);
  });

  testWidgets('con letra grande y en modo oscuro no se desborda', (tester) async {
    await abrirJuego(
      tester,
      escalaTexto: 1.3,
      oscuro: true,
      tamano: const Size(360, 740),
      overrides: await overridesJuego(
        casos: {'caso-sala-gesell.json': casoOficialDeEjemplo(), 'caso-prueba.json': casoPrueba},
        preferencias: progresoGuardado(cartas: ['R-ser-escuchada', 'R-entender']),
      ),
    );
    await tester.scrollUntilVisible(find.text(notaCasosInventados), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text(notaCasosInventados), findsOneWidget);
    expect(find.byType(CartaDerecho), findsNWidgets(2));
  });
}
