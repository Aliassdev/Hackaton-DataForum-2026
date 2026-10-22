import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/core/seguridad.dart';

void main() {
  group('pareceCrisis (red de seguridad sin conexión)', () {
    test('reconoce expresiones de peligro sin que importen tildes ni mayúsculas', () {
      expect(pareceCrisis('A veces pienso que NO QUIERO VIVIR'), isTrue);
      expect(pareceCrisis('Quiero morir'), isTrue);
      expect(pareceCrisis('quiero hacerme daño'), isTrue);
      expect(pareceCrisis('Tengo miedo de volver a casa'), isTrue);
      expect(pareceCrisis('Estoy en peligro'), isTrue);
    });

    test('las preguntas de los casos oficiales (Lucía, Sergio y Sara) no son crisis', () {
      expect(pareceCrisis('¿Por qué quieren hablar conmigo unos desconocidos en la Sala Gesell?'), isFalse);
      expect(pareceCrisis('¿Tendré que ver a los que me acosaban si hay juicio?'), isFalse);
      expect(pareceCrisis('¿Es delito pasar fotos íntimas de alguien de 15 años?'), isFalse);
      expect(pareceCrisis('Si tengo 13 años y hago algo malo, ¿me pueden juzgar?'), isFalse);
    });
  });
}
