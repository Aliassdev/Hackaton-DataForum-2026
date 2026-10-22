import 'package:flutter_test/flutter_test.dart';
import 'package:tuturno/widgets/movimiento/movimiento.dart';

import 'entorno.dart';

void main() {
  testWidgets('cada vibración pide a la plataforma el tipo que le corresponde', (tester) async {
    final vibraciones = registrarVibraciones(tester);
    await Hapticos.seleccion();
    await Hapticos.toque();
    await Hapticos.acierto();
    await Hapticos.sello();
    expect(vibraciones, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
