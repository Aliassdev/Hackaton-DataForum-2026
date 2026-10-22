import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/app.dart';
import 'package:tuturno/core/config.dart';
import 'package:tuturno/core/providers.dart';

void main() {
  testWidgets('la app arranca con la configuración de mock', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          configProvider.overrideWithValue(const AppConfig(apiUrl: '', useMock: true, demo: false)),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const TuTurnoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Glosario'), findsOneWidget);
    expect(find.text('Ayuda'), findsOneWidget);
  });
}
