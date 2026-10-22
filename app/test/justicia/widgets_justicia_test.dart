import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/api/models.dart';
import 'package:tuturno/tema.dart';
import 'package:tuturno/widgets/animaciones.dart';
import 'package:tuturno/widgets/fuente_chip.dart';
import 'package:tuturno/widgets/iconos/iconos.dart';
import 'package:tuturno/widgets/justicia/justicia.dart';
import 'package:tuturno/widgets/modulos.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import '../widgets/movimiento/entorno.dart';

const _golpeSello = 'HapticFeedbackType.heavyImpact';
const _seleccion = 'HapticFeedbackType.selectionClick';

/// Pose final de un sello: torcido y a tamaño normal.
Matrix4 _puesto(double inclinacion) => Matrix4.identity()..rotateZ(inclinacion);

Color? _colorLuz(WidgetTester tester) =>
    (tester.widget<Container>(find.byKey(AvisoTurnoPalabra.claveLuz)).decoration! as BoxDecoration).color;

void main() {
  group('CartelSala', () {
    testWidgets('se lee como texto, «Sala 1. Tus derechos», con el nombre en mayúsculas y sin ser un botón', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const CartelSala(texto: 'Sala 1', detalle: 'Tus derechos'));
      expect(find.text('SALA 1 · Tus derechos'), findsOneWidget);
      expect(tester.getSemantics(find.byType(CartelSala)), matchesSemantics(label: 'Sala 1. Tus derechos'));
      semantica.dispose();
    });

    testWidgets('sin detalle se lee su nombre; con semanticLabel, lo que se pida', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const CartelSala(texto: 'INFORMACIÓN'));
      expect(find.text('INFORMACIÓN'), findsOneWidget);
      expect(tester.getSemantics(find.byType(CartelSala)), matchesSemantics(label: 'INFORMACIÓN'));

      await montar(tester, const CartelSala(texto: 'SALA 2', semanticLabel: 'Sala 2: Aprende'));
      expect(tester.getSemantics(find.byType(CartelSala)), matchesSemantics(label: 'Sala 2: Aprende'));
      semantica.dispose();
    });

    testWidgets('es papel con tinta azul noche (AA) y el icono va a una tinta, la misma', (tester) async {
      await montar(tester, const CartelSala(texto: 'SALA 2', icono: TuIcono.balanza));
      expect(PaletaMovimiento.contraste(CartelSala.papel, CartelSala.tinta), greaterThan(4.5));
      final icono = tester.widget<IconoTuTurno>(find.byType(IconoTuTurno));
      expect(icono.icono, TuIcono.balanza);
      expect(icono.estilo, EstiloIcono.mono);
      expect(icono.color, CartelSala.tinta);
      expect(icono.decorativo, isTrue);
      final texto = tester.widget<Text>(find.byType(Text));
      expect(texto.style?.color, CartelSala.tinta);
      expect(texto.style?.fontWeight, FontWeight.w800);
    });

    testWidgets('va pegado a mano (un poco girado); con inclinacion 0, recto', (tester) async {
      final giro = find.descendant(of: find.byType(CartelSala), matching: find.byType(Transform));
      await montar(tester, const CartelSala(texto: 'SALA 1'));
      expect(transformacionDe(tester, find.byType(CartelSala)), matrixMoreOrLessEquals(_puesto(-0.02)));

      await montar(tester, const CartelSala(texto: 'SALA 1', inclinacion: 0));
      expect(giro, findsNothing);
    });

    testWidgets('crece con el tamaño de letra y, si no cabe, pasa a otra línea sin desbordarse', (tester) async {
      Widget cartel() => const SizedBox(
        width: 180,
        child: Align(
          alignment: Alignment.centerLeft,
          child: CartelSala(texto: 'SALA 2', detalle: 'Si te toca declarar'),
        ),
      );
      await montar(tester, cartel());
      final normal = tester.getSize(find.byType(CartelSala)).height;
      for (final brillo in Brightness.values) {
        await montar(tester, cartel(), escalaTexto: 2, brillo: brillo);
        expect(tester.takeException(), isNull, reason: '$brillo');
      }
      expect(tester.getSize(find.byType(CartelSala)).height, greaterThan(normal * 1.5));
      expect(tester.getSize(find.byType(CartelSala)).width, lessThanOrEqualTo(180));
    });
  });

  group('SelloJusticia', () {
    test('cada tipo tiene su palabra, su icono y su texto alrededor, siempre con la marca TuTurno', () {
      expect(
        {for (final tipo in TipoSello.values) tipo: (tipo.texto, tipo.icono)},
        {
          TipoSello.leccion: ('SUPERADA', TuIcono.balanza),
          TipoSello.practica: ('REPASADO', TuIcono.ley),
          TipoSello.caso: ('COMPLETADO', TuIcono.puertaSala),
          TipoSello.turno: ('CUMPLIDO', TuIcono.ticket),
        },
      );
      expect(TipoSello.leccion.circular, 'TUTURNO · APRENDE · LECCIÓN SUPERADA · ');
      for (final tipo in TipoSello.values) {
        expect(tipo.circular, contains('TUTURNO'), reason: tipo.name);
        expect(tipo.circular, endsWith(' · '), reason: tipo.name);
        expect(tipo.lectura, isNotEmpty);
      }
    });

    testWidgets('con «reducir animaciones» aparece ya estampado, avisa una sola vez y vibra una vez', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      var golpes = 0;
      await montar(tester, reducir: true, SelloJusticia(tipo: TipoSello.leccion, alEstampar: () => golpes++));
      final sello = find.byType(SelloAnimado);
      expect(opacidadDe(tester, sello), 1);
      expect(transformacionDe(tester, sello), matrixMoreOrLessEquals(_puesto(-0.16)));
      expect(golpes, 1);
      expect(vibraciones, [_golpeSello]);
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Volver a construirlo no lo estampa otra vez.
      await montar(tester, reducir: true, SelloJusticia(tipo: TipoSello.leccion, alEstampar: () => golpes++));
      await tester.pump(const Duration(seconds: 1));
      expect(golpes, 1);
      expect(vibraciones, [_golpeSello]);
    });

    testWidgets('con movimiento, espera 250 ms, cae, avisa una sola vez y se queda torcido', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      var golpes = 0;
      await montar(tester, SelloJusticia(tipo: TipoSello.caso, alEstampar: () => golpes++));
      final sello = find.byType(SelloAnimado);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacidadDe(tester, sello), 0, reason: 'esperando el retraso');
      expect(golpes, 0);

      await tester.pump(const Duration(milliseconds: 400));
      expect(golpes, 1);
      expect(vibraciones, [_golpeSello]);

      await tester.pumpAndSettle();
      expect(golpes, 1);
      expect(opacidadDe(tester, sello), 1);
      expect(transformacionDe(tester, sello), matrixMoreOrLessEquals(_puesto(-0.16)));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('lleva el icono de su tipo en el centro y se lee «Sello: …»', (tester) async {
      final semantica = tester.ensureSemantics();
      for (final tipo in TipoSello.values) {
        await montar(tester, reducir: true, SelloJusticia(tipo: tipo, vibrar: false));
        final sello = tester.widget<Sello>(find.byType(Sello));
        expect(sello.texto, tipo.texto);
        expect(sello.textoCircular, tipo.circular);
        expect(sello.tuIcono, tipo.icono);
        expect(sello.tamano, 132);
        expect(find.bySemanticsLabel('Sello: ${tipo.lectura}'), findsOneWidget);
      }
      expect(find.bySemanticsLabel('Sello: lección superada'), findsNothing);
      await montar(tester, reducir: true, const SelloJusticia(tipo: TipoSello.leccion, vibrar: false));
      expect(find.bySemanticsLabel('Sello: lección superada'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('sin estampar no se ve, no se lee ni vibra; al estamparse, cae una vez', (tester) async {
      final semantica = tester.ensureSemantics();
      final vibraciones = registrarVibraciones(tester);
      var golpes = 0;
      Widget sello(bool estampado) =>
          SelloJusticia(tipo: TipoSello.practica, estampado: estampado, alEstampar: () => golpes++);
      await montar(tester, sello(false));
      expect(opacidadDe(tester, find.byType(SelloAnimado)), 0);
      expect(find.bySemanticsLabel('Sello: repaso hecho'), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await montar(tester, sello(true));
      await tester.pumpAndSettle();
      expect(golpes, 1);
      expect(vibraciones, [_golpeSello]);
      expect(find.bySemanticsLabel('Sello: repaso hecho'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('con color, la tinta del sello y la que se corre son de ese color', (tester) async {
      await montar(
        tester,
        reducir: true,
        const SelloJusticia(tipo: TipoSello.turno, color: ColoresMarca.azulNoche, vibrar: false),
      );
      expect(tester.widget<Sello>(find.byType(Sello)).color, ColoresMarca.azulNoche);
      expect(tester.widget<SelloAnimado>(find.byType(SelloAnimado)).colorTinta, ColoresMarca.azulNoche);

      await montar(tester, reducir: true, const SelloJusticia(tipo: TipoSello.turno, vibrar: false));
      expect(tester.widget<Sello>(find.byType(Sello)).color, isNull, reason: 'por defecto, la del tema');
    });

    testWidgets('sin animar aparece puesto y sin vibrar (un sello que ya tenías)', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      var golpes = 0;
      await montar(tester, SelloJusticia(tipo: TipoSello.turno, animar: false, alEstampar: () => golpes++));
      expect(opacidadDe(tester, find.byType(SelloAnimado)), 1);
      expect(golpes, 0);
      expect(vibraciones, isEmpty);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('se pinta en claro, en oscuro y con letra grande', (tester) async {
      for (final brillo in Brightness.values) {
        await montar(
          tester,
          brillo: brillo,
          escalaTexto: 1.6,
          reducir: true,
          Wrap(children: [for (final tipo in TipoSello.values) SelloJusticia(tipo: tipo, vibrar: false, tamano: 120)]),
        );
        expect(tester.takeException(), isNull, reason: '$brillo');
      }
    });
  });

  group('AvisoTurnoPalabra', () {
    testWidgets('activo: la luz pasa a amarillo en 240 ms, late dos veces y se para; vibra una vez', (tester) async {
      final semantica = tester.ensureSemantics();
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, const AvisoTurnoPalabra(activo: true));
      final papel = ColoresTuTurno.claro.ticket;
      expect(_colorLuz(tester), papel, reason: 'aún apagada');
      expect(vibraciones, [_seleccion]);
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 120));
      expect(_colorLuz(tester), isNot(papel));
      expect(_colorLuz(tester), isNot(ColoresMarca.amarillo));
      await tester.pump(const Duration(milliseconds: 130));
      expect(_colorLuz(tester), ColoresMarca.amarillo);
      expect(find.byType(AnilloPulso), findsOneWidget);
      expect(tester.widget<AnilloPulso>(find.byType(AnilloPulso)).veces, 2);

      // Dos latidos del anillo (2 × 1,4 s) y quieta.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(_colorLuz(tester), ColoresMarca.amarillo);
      expect(vibraciones, [_seleccion]);
      expect(
        tester.getSemantics(find.byType(AvisoTurnoPalabra)),
        matchesSemantics(label: 'Tu turno de palabra', value: 'ahora'),
      );
      semantica.dispose();
    });

    testWidgets('inactivo: la luz es un aro apagado, no late, no vibra y se lee «en espera»', (tester) async {
      final semantica = tester.ensureSemantics();
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, const AvisoTurnoPalabra(activo: false), brillo: Brightness.dark);
      expect(_colorLuz(tester), ColoresTuTurno.oscuro.ticket);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(vibraciones, isEmpty);
      expect(
        tester.getSemantics(find.byType(AvisoTurnoPalabra)),
        matchesSemantics(label: 'Tu turno de palabra', value: 'en espera'),
      );
      expect(find.text('Tu turno de palabra'), findsOneWidget);
      final icono = tester.widget<IconoTuTurno>(find.byType(IconoTuTurno));
      expect(icono.icono, TuIcono.turnoPalabra);
      semantica.dispose();
    });

    testWidgets('al activarse se enciende y vibra una sola vez; al apagarse, la luz se apaga', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, const AvisoTurnoPalabra(activo: false));
      await montar(tester, const AvisoTurnoPalabra(activo: true));
      await tester.pumpAndSettle();
      expect(_colorLuz(tester), ColoresMarca.amarillo);
      expect(vibraciones, [_seleccion]);

      await montar(tester, const AvisoTurnoPalabra(activo: true));
      await tester.pumpAndSettle();
      expect(vibraciones, [_seleccion], reason: 'sigue activo: no vuelve a vibrar');

      await montar(tester, const AvisoTurnoPalabra(activo: false));
      await tester.pumpAndSettle();
      expect(_colorLuz(tester), ColoresTuTurno.claro.ticket);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('con «reducir animaciones», la luz se enciende de golpe y no late (sí vibra una vez)', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, reducir: true, const AvisoTurnoPalabra(activo: true));
      expect(_colorLuz(tester), ColoresMarca.amarillo);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(vibraciones, [_seleccion]);
    });

    testWidgets('con vibrar en false no vibra', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, const AvisoTurnoPalabra(activo: true, vibrar: false));
      await tester.pumpAndSettle();
      expect(vibraciones, isEmpty);
    });

    testWidgets('la compacta es más pequeña; las dos crecen con la letra sin desbordarse', (tester) async {
      await montar(tester, const AvisoTurnoPalabra(activo: false));
      final normal = tester.getSize(find.byType(AvisoTurnoPalabra));
      await montar(tester, const AvisoTurnoPalabra(activo: false, compacto: true));
      final compacta = tester.getSize(find.byType(AvisoTurnoPalabra));
      expect(compacta.height, lessThan(normal.height));
      expect(compacta.width, lessThan(normal.width));
      for (final compacto in [false, true]) {
        await montar(
          tester,
          escalaTexto: 2,
          SizedBox(
            width: 220,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AvisoTurnoPalabra(activo: false, compacto: compacto),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'compacto: $compacto');
      }
    });
  });

  group('Modulo y TarjetaModulo', () {
    test('cada módulo tiene el cartel de su sala; Ayuda no es un módulo: se queda fuera de la metáfora', () {
      expect(
        {for (final modulo in Modulo.values) modulo: modulo.sala},
        {Modulo.juego: 'SALA 1', Modulo.aprende: 'SALA 2', Modulo.pregunta: 'INFORMACIÓN'},
      );
      expect(Modulo.values.map((modulo) => modulo.titulo), isNot(contains('Ayuda')));
    });

    for (final modulo in Modulo.values) {
      testWidgets('la tarjeta de ${modulo.titulo} lleva arriba su cartel «${modulo.sala}» y se lee con él', (
        tester,
      ) async {
        final semantica = tester.ensureSemantics();
        await montar(
          tester,
          SizedBox(
            width: 380,
            child: TarjetaModulo(modulo: modulo, onTap: () {}),
          ),
        );
        final tarjeta = find.byType(TarjetaModulo);
        final cartel = find.descendant(of: tarjeta, matching: find.byType(CartelSala));
        expect(cartel, findsOneWidget);
        expect(tester.widget<CartelSala>(cartel).texto, modulo.sala);
        expect(tester.getBottomLeft(cartel).dy, lessThan(tester.getTopLeft(find.text(modulo.titulo)).dy));
        // El cartel no trae icono: el único de la tarjeta sigue siendo el del módulo, en el talón.
        final icono = tester.widget<IconoTuTurno>(find.descendant(of: tarjeta, matching: find.byType(IconoTuTurno)));
        expect(icono.icono, modulo.tuIcono);
        final datos = tester.getSemantics(tarjeta).getSemanticsData();
        expect(datos.label, contains(modulo.sala!));
        expect(datos.label, contains(modulo.titulo));
        expect(datos.flagsCollection.isButton, isTrue);
        semantica.dispose();
      });
    }

    testWidgets('con letra grande, las tarjetas crecen y no se desbordan, en claro y en oscuro', (tester) async {
      for (final brillo in Brightness.values) {
        await montar(
          tester,
          brillo: brillo,
          escalaTexto: 2,
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                children: [for (final modulo in Modulo.values) TarjetaModulo(modulo: modulo, onTap: () {})],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$brillo');
      }
    });
  });

  group('FuenteChip', () {
    const fuente = Fuente(id: 'lo1-1996-art9', titulo: 'Derecho a ser oído', norma: 'LO 1/1996', articulo: '9.1');

    testWidgets('el chip y su hoja llevan el libro de la ley («De dónde sale»), nunca el mazo', (tester) async {
      final vibraciones = registrarVibraciones(tester);
      await montar(tester, const FuenteChip(fuente: fuente));
      final chip = find.byType(FuenteChip);
      expect(
        tester.widget<IconoTuTurno>(find.descendant(of: chip, matching: find.byType(IconoTuTurno))).icono,
        TuIcono.ley,
      );
      expect(find.byIcon(Icons.gavel_rounded), findsNothing);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(vibraciones, [_seleccion]);
      expect(find.text('De dónde sale la respuesta'), findsOneWidget);
      final iconos = tester.widgetList<IconoTuTurno>(find.byType(IconoTuTurno)).map((icono) => icono.icono);
      expect(iconos.where((icono) => icono == TuIcono.ley), hasLength(2), reason: 'el del chip y el de la hoja');
      expect(find.byIcon(Icons.gavel_rounded), findsNothing);
    });

    testWidgets('con número, el chip enseña el número en lugar del icono', (tester) async {
      await montar(tester, const FuenteChip(fuente: fuente, numero: 2));
      expect(find.byType(NumeroFuente), findsOneWidget);
      expect(find.descendant(of: find.byType(FuenteChip), matching: find.byType(IconoTuTurno)), findsNothing);
    });
  });
}
