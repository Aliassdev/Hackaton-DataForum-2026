import 'package:flutter/material.dart';

import '../../tema.dart';
import '../../widgets/tuturno_scaffold.dart';

/// «Enseñar en grande» (/mis-preguntas/ensenar): tus preguntas en letra muy grande, para enseñárselas a quien te
/// atienda (producto.md §5.2).
///
/// PROVISIONAL: la oleada B la sustituye por la pantalla de verdad, con el mismo nombre de clase.
class EnsenarScreen extends StatelessWidget {
  const EnsenarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TuTurnoScaffold(
      titulo: 'Enseñar en grande',
      body: ListView(
        padding: const EdgeInsets.all(Espacio.m),
        children: [
          Text(
            'Aquí verás tus preguntas en letra grande, para enseñarlas.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
