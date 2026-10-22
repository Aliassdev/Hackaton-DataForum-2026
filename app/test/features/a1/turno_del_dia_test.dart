import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuturno/core/progreso.dart';
import 'package:tuturno/core/providers.dart';
import 'package:tuturno/features/inicio/nivel.dart';
import 'package:tuturno/features/inicio/turno_del_dia.dart';

/// Jueves 22/10/2026: toca lección; el 23, carta; el 24, puntos; y vuelta a empezar.
final _jueves = DateTime(2026, 10, 22, 10);

void main() {
  late SharedPreferences prefs;
  var ahora = _jueves;

  setUp(() async {
    ahora = _jueves;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Un contenedor nuevo con las mismas preferencias: como abrir la app otra vez, que empieza en el inicio y enseña el
  /// turno del día (ahí se apunta lo que había al empezar el día).
  ProviderContainer abrir() {
    final contenedor = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), relojProvider.overrideWithValue(() => ahora)],
    );
    addTearDown(contenedor.dispose);
    contenedor.read(turnoDelDiaProvider);
    return contenedor;
  }

  TurnoDelDia turno(ProviderContainer c) => c.read(turnoDelDiaProvider);
  ProgresoNotifier progreso(ProviderContainer c) => c.read(progresoProvider.notifier);

  group('Turno del día', () {
    test('el primer día: turno 1, la misión del día y sin cumplir', () {
      final t = turno(abrir());
      expect(t.numero, 1);
      expect(t.mision, Mision.leccion);
      expect(t.cumplida, isFalse);
      expect(t.porCelebrar, isFalse);
      expect(t.numeroVisto, isNull);
    });

    test('las misiones van rotando por días y solo llevan a Aprende y a Vive el caso', () {
      final vistas = <Mision>[];
      for (var d = 0; d < 6; d++) {
        ahora = _jueves.add(Duration(days: d));
        vistas.add(turno(abrir()).mision);
      }
      expect(vistas, [Mision.leccion, Mision.carta, Mision.puntos, Mision.leccion, Mision.carta, Mision.puntos]);
      for (final mision in Mision.values) {
        expect(['/aprende', '/juego'], contains(mision.ruta), reason: mision.name);
      }
    });

    test('con un caso terminado, en vez de cartas toca sumar puntos', () {
      ahora = DateTime(2026, 10, 23, 10);
      expect(Mision.delDia(ahora, const Progreso()), Mision.carta);
      expect(Mision.delDia(ahora, const Progreso(casosTerminados: {'caso-testigo'})), Mision.puntos);
    });

    test('completar una lección cumple la misión de lección', () async {
      final c = abrir();
      await progreso(c).completarLeccion('U1-L1');
      expect(turno(c).cumplida, isTrue);
      expect(turno(c).porCelebrar, isTrue);
    });

    test('repetir hoy una lección ya hecha también cuenta', () async {
      final c = abrir();
      await progreso(c).completarLeccion('U1-L1');
      ahora = _jueves.add(const Duration(days: 3));
      final otroDia = abrir();
      expect(turno(otroDia).mision, Mision.leccion);
      expect(turno(otroDia).cumplida, isFalse);
      await progreso(otroDia).completarLeccion('U1-L1');
      expect(turno(otroDia).cumplida, isTrue);
    });

    test('conseguir una carta cumple la misión de carta', () async {
      ahora = DateTime(2026, 10, 23, 10);
      final c = abrir();
      expect(turno(c).mision, Mision.carta);
      await progreso(c).completarLeccion('U1-L1');
      expect(turno(c).cumplida, isFalse);
      await progreso(c).desbloquearCarta('C-oido');
      expect(turno(c).cumplida, isTrue);
    });

    test('ganar 30 XP cumple la misión de puntos (los que ya había no cuentan)', () async {
      ahora = DateTime(2026, 10, 24, 10);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final c = abrir();
      await progreso(c).sumarXp(500);
      // Los 500 se sumaron después de abrir el inicio: cuentan.
      expect(turno(c).cumplida, isTrue);

      ahora = DateTime(2026, 10, 27, 10);
      final otroDia = abrir();
      expect(turno(otroDia).mision, Mision.puntos);
      expect(turno(otroDia).cumplida, isFalse);
      await progreso(otroDia).sumarXp(20);
      expect(turno(otroDia).cumplida, isFalse);
      await progreso(otroDia).sumarXp(10);
      expect(turno(otroDia).cumplida, isTrue);
    });

    test('al día siguiente, el número sube si se cumplió la misión y se queda si no', () async {
      final c = abrir();
      await progreso(c).completarLeccion('U1-L1');
      expect(turno(c).numero, 1);

      ahora = _jueves.add(const Duration(days: 1));
      expect(turno(abrir()).numero, 2);

      // El viernes no se hace nada: el sábado el número sigue siendo el 2 (sin perder nada).
      ahora = _jueves.add(const Duration(days: 2));
      expect(turno(abrir()).numero, 2);
    });

    test('si se reinicia el progreso (modo DEMO), el turno vuelve a empezar', () async {
      final c = abrir();
      await progreso(c).completarLeccion('U1-L1');
      ahora = _jueves.add(const Duration(days: 1));
      final otroDia = abrir();
      expect(turno(otroDia).numero, 2);

      await progreso(otroDia).reiniciar();
      expect(turno(otroDia).numero, 1);
      expect(turno(otroDia).cumplida, isFalse);
    });

    test('el sello se celebra una sola vez y se recuerda', () async {
      final c = abrir();
      await progreso(c).completarLeccion('U1-L1');
      c.read(turnoDelDiaProvider.notifier).marcarCelebrada();
      expect(turno(c).celebrada, isTrue);
      expect(turno(c).porCelebrar, isFalse);

      final otraVez = abrir();
      expect(turno(otraVez).cumplida, isTrue);
      expect(turno(otraVez).porCelebrar, isFalse);
    });

    test('el último número enseñado se guarda para que el panel gire desde ahí', () {
      final c = abrir();
      c.read(turnoDelDiaProvider.notifier).marcarVisto(1);
      expect(turno(c).numeroVisto, 1);
      expect(turno(abrir()).numeroVisto, 1);
    });

    test('un registro guardado que no se entiende no rompe nada', () async {
      SharedPreferences.setMockInitialValues({TurnoDelDiaNotifier.clave: '{esto no es json'});
      prefs = await SharedPreferences.getInstance();
      final t = turno(abrir());
      expect(t.numero, 1);
      expect(t.mision, Mision.leccion);
    });

    test('el registro se guarda y se lee igual', () {
      final registro = RegistroTurno(
        dia: DateTime(2026, 10, 22),
        mision: Mision.carta,
        base: const Recuento(lecciones: 2, cartas: 1, casos: 0, xp: 120),
        turnos: 4,
        celebrada: true,
        visto: 5,
      );
      final leido = RegistroTurno.decodificar(registro.codificar())!;
      expect(leido.codificar(), registro.codificar());
      expect(leido.dia, DateTime(2026, 10, 22));
      expect(leido.turnos, 4);
      expect(leido.visto, 5);
    });
  });

  group('Racha', () {
    test('se enseña si la última lección fue hoy, ayer o anteayer con día de descanso; si no, empieza de cero', () {
      final hoy = DateTime(2026, 10, 22);
      Progreso con(DateTime? ultimo) => Progreso(racha: 4, ultimoDiaConLeccion: ultimo);
      expect(rachaViva(con(DateTime(2026, 10, 22)), hoy), 4);
      expect(rachaViva(con(DateTime(2026, 10, 21)), hoy), 4);
      // Un día sin lección, con el día de descanso de la semana (racha amable): sigue.
      expect(rachaViva(con(DateTime(2026, 10, 20)), hoy), 4);
      expect(
        rachaViva(
          Progreso(racha: 4, ultimoDiaConLeccion: DateTime(2026, 10, 20), descansoUsado: DateTime(2026, 10, 18)),
          hoy,
        ),
        0,
        reason: 'el descanso de esta semana ya se gastó',
      );
      expect(rachaViva(con(DateTime(2026, 10, 19)), hoy), 0);
      expect(rachaViva(con(null), hoy), 0);
      expect(leccionHoy(con(DateTime(2026, 10, 22, 9)), hoy), isTrue);
      expect(leccionHoy(con(DateTime(2026, 10, 21)), hoy), isFalse);
    });

    test('los días se cuentan bien aunque cambie la hora (horario de verano)', () {
      expect(indiceDia(DateTime(2026, 3, 30)) - indiceDia(DateTime(2026, 3, 28)), 2);
      expect(indiceDia(DateTime(2026, 10, 26)) - indiceDia(DateTime(2026, 10, 24)), 2);
      expect(indiceDia(DateTime(2026)), 0);
    });
  });

  group('Niveles', () {
    test('cada nivel empieza en su umbral y tiene un título sin género', () {
      expect(Nivel.de(0).numero, 1);
      expect(Nivel.de(0).titulo, 'Ticket en mano');
      expect(Nivel.de(49).numero, 1);
      expect(Nivel.de(50).numero, 2);
      expect(Nivel.de(140).titulo, 'Detective de derechos');
      expect(Nivel.de(750).titulo, 'Leyenda de TuTurno');
      expect(Nivel.de(1000).numero, 8);
      expect(Nivel.de(1000).titulo, 'Leyenda de TuTurno');
      expect(Nivel.de(-5).numero, 1);
      // Títulos que valen igual para chicos y chicas (nada de «el experto» o «la experta»).
      expect(Nivel.titulosNivel, [
        'Ticket en mano',
        'Mente curiosa',
        'Detective de derechos',
        'Voz con poder',
        'Estrella de los derechos',
        'Brújula de la justicia',
        'Leyenda de TuTurno',
      ]);
    });

    test('el progreso dentro del nivel y lo que falta para el siguiente', () {
      final nivel = Nivel.de(85);
      expect(nivel.numero, 2);
      expect(nivel.desde, 50);
      expect(nivel.hasta, 120);
      expect(nivel.progreso(85), closeTo(0.5, 0.001));
      expect(nivel.faltan(85), 35);
      expect(nivel.siguiente.titulo, 'Detective de derechos');
    });
  });
}
