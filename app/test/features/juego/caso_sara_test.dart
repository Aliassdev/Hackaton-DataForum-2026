import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/texto.dart';
import 'package:tuturno/features/juego/juego_providers.dart';
import 'package:tuturno/features/juego/modelos.dart';
import 'package:tuturno/features/juego/motor.dart';

// El caso oficial de Sara (casi 16 años, difusión de imágenes íntimas): las reglas de seguridad del contenido.
// Las reglas generales de los casos (esquema 9.4, fuentes, cartas, jugar de principio a fin) están en contenido_test.dart.

void main() {
  final json = File('assets/mock/content/juego/caso-difusion-imagenes.json').readAsStringSync();
  final caso = Caso.fromJson(jsonDecode(json) as Map<String, dynamic>);
  final texto = normalizar(json);

  test('Sara, 15 años y casi 16, víctima; 9 escenas, 5 decisiones y 5 cartas', () {
    expect(caso.protagonista, 'Sara');
    expect(caso.edad, 15);
    expect(caso.rol, 'victima');
    expect(caso.escenas, hasLength(9));
    expect(caso.decisiones, 5);
    expect(caso.cartas, hasLength(5));
    expect(caso.escenas.any((e) => Lugar.desde(e.lugar) == Lugar.comisaria), isTrue);
    expect(caso.escenas.any((e) => Lugar.desde(e.lugar) == Lugar.fiscalia), isTrue);
  });

  test('se gana una carta en cada decisión acertada', () {
    var partida = Partida.nueva(caso);
    while (!partida.terminada) {
      final d = partida.decision;
      if (d != null) partida = partida.elegir(d.opciones.indexWhere((o) => o.correcta));
      partida = partida.avanzar();
    }
    expect(partida.cartasGanadas.toSet(), {for (final c in caso.cartas) c.id});
  });

  test('nunca culpa a Sara: lo correcto es no guardar ni reenviar, y la culpa es de quien difunde', () {
    final primera = caso.escenas.firstWhere((e) => e.decision != null);
    final correcta = primera.decision!.opciones.singleWhere((o) => o.correcta);
    expect(normalizar(correcta.texto), allOf(contains('no las guarda'), contains('ni las reenvia')));
    expect(normalizar(correcta.feedback), contains('la culpa es de quien las difunde'));
    final pedirlas = primera.decision!.opciones.firstWhere((o) => normalizar(o.texto).contains('que se las pase'));
    expect(pedirlas.correcta, isFalse);
    expect(pedirlas.fuente, isNot(contains('Código Penal')), reason: 'a Sara nunca se le cita un delito');
    for (final prohibida in ['culpa tuya', 'culpa suya', 'por que las envio', 'por que se hizo', 'carcel', 'prision']) {
      expect(texto, isNot(contains(prohibida)), reason: prohibida);
    }
  });

  test('Canal prioritario: por internet, no para WhatsApp; desde los 14 años, sin un adulto', () {
    final canal = caso.escenas.firstWhere((e) => normalizar(e.decision?.pregunta ?? '').contains('quiten'));
    final correcta = canal.decision!.opciones.singleWhere((o) => o.correcta);
    expect(correcta.texto, contains('por internet'));
    expect(correcta.fuente, contains('AEPD'));
    final whatsapp = canal.decision!.opciones.firstWhere((o) => o.texto.contains('grupo de mensajes'));
    expect(whatsapp.correcta, isFalse);
    expect(whatsapp.feedback, contains('WhatsApp'));
    expect(caso.carta('R-canal-prioritario')!.texto, contains('Desde los 14 años'));
  });

  test('puede denunciar ella misma; quienes difunden, de 14 a 17 años, tienen medidas y no penas', () {
    expect(caso.carta('R-denunciar-sola')!.fuente, 'LOPIVI, art. 50.2');
    final fiscalia = caso.escenas.firstWhere((e) => Lugar.desde(e.lugar) == Lugar.fiscalia);
    final menores = fiscalia.decision!.opciones.firstWhere((o) => !o.correcta && o.fuente.contains('LO 5/2000'));
    expect(menores.feedback, contains('medidas, no penas'));
  });

  test('las imágenes no se describen nunca y no se pregunta por los hechos', () {
    for (final palabra in ['desnud', 'sexting', 'novio', 'ex ', 'foto de ella', 'que paso', 'cuentame']) {
      expect(texto, isNot(contains(palabra)), reason: palabra);
    }
  });

  test('empieza en su habitación, con su madre en la suya y no en la de nadie más', () {
    expect(Lugar.desde(caso.escenas.first.lugar), Lugar.habitacion);
    final conSuMadre = caso.escenas.firstWhere((e) => e.personajes.contains('Su madre'));
    expect(Lugar.desde(conSuMadre.lugar), Lugar.habitacion);
  });

  test('es el tercer caso oficial', () {
    expect(ordenCasos.indexOf(caso.id), 2);
  });

  test('el final da ayuda con el horario bien puesto: 017 de 8:00 a 23:00', () {
    final ultima = caso.escenas.last;
    expect(Lugar.desde(ultima.lugar), Lugar.despues);
    expect(
      ultima.narracion,
      allOf(contains('017, de 8:00 a 23:00'), contains('900 293 183'), contains('900 20 20 10')),
    );
  });
}
