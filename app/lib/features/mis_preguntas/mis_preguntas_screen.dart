import 'package:flutter/material.dart';

import '../../tema.dart';
import '../../widgets/tuturno_scaffold.dart';

/// Mis preguntas (/mis-preguntas): lo que quieres pedir o preguntar en el proceso (producto.md §5.2).
///
/// PROVISIONAL: la oleada B la sustituye por la pantalla de verdad, con el mismo nombre de clase.
class MisPreguntasScreen extends StatelessWidget {
  const MisPreguntasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TuTurnoScaffold(
      titulo: 'Mis preguntas',
      body: ListView(
        padding: const EdgeInsets.all(Espacio.m),
        children: [
          Text('Aquí podrás apuntar lo que quieres pedir o preguntar.', style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
