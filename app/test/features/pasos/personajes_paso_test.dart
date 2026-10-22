import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/features/pasos/personajes_paso.dart';

// «Quién estará» con los personajes de «Vive el caso»: el de la familia o el adulto de confianza se parece a quien
// acompaña de verdad (según «Tu ticket»).

void main() {
  test('la familia o el adulto de confianza: Elena, salvo si irá con su familia (los padres de Sergio)', () {
    const persona = 'Tu familia o un adulto de confianza';
    expect(personajeDePersona(persona)?.id, 'elena', reason: 'sin ticket, el ejemplo de siempre');
    expect(personajeDePersona(persona, acompanantes: {'confianza'})?.id, 'elena');
    expect(personajeDePersona(persona, acompanantes: {'familia'})?.id, 'madre-sergio');
    expect(personajeDePersona(persona, acompanantes: {'familia'})?.como, 'Como los padres de Sergio en «Vive el caso»');
    expect(personajeDePersona(persona, acompanantes: {'familia', 'confianza'})?.id, 'elena');
  });

  test('la toga solo en la sala: fuera, la jueza no sale y el fiscal va sin toga', () {
    expect(personajeDePersona('La jueza o el juez'), isNull);
    expect(personajeDePersona('La jueza o el juez', enSala: true)?.id, 'jueza');
    expect(personajeDePersona('El fiscal')?.id, 'fiscal-despacho');
    expect(personajeDePersona('El fiscal', enSala: true)?.id, 'fiscal');
  });
}
