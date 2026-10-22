import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entrada.dart';
import '../../core/providers.dart';
import '../../core/texto.dart';
import 'fuentes_paso.dart';
import 'modelos.dart';

/// Carpeta de los itinerarios dentro del contenido (assets/content, o assets/mock/content mientras esté vacía).
const carpetaItinerarios = 'itinerarios';

/// Un papel que puede ser nombre de fichero: minúsculas y guiones bajos (testigo, victima, escuchado_familia…).
final _rolValido = RegExp(r'^[a-z][a-z_]*$');

/// Itinerario de [rol] ('testigo', 'victima', 'investigado'…), leído de `itinerarios/<rol>.json` con
/// [contentProvider]. null si no hay, si no está validado o si no le queda ningún paso.
///
/// Solo quedan los pasos con alguna cita en sus fuentes, las mismas que enseña «De dónde sale» (CitaPaso.de; una
/// fuente que solo tiene «;» no cuenta): el contenido jurídico no se enseña sin fuente. En modo DEMO con borradores
/// se enseña todo, también lo que no está validado o no tiene fuente, como el resto del contenido
/// (ContentRepo.visible).
final itinerarioProvider = FutureProvider.family<Itinerario?, String>(
  (ref, rol) async {
    final repo = ref.watch(contentProvider);
    final clave = normalizar(rol.trim());
    if (!_rolValido.hasMatch(clave)) return null;
    final itinerario = Itinerario.tryParse(await repo.json('$carpetaItinerarios/$clave.json'), rol: clave);
    if (itinerario == null) return null;
    if (normalizar(itinerario.rol) != clave) {
      // Un fichero con otro papel dentro es un error de contenido: mejor no enseñar pasos que no le tocan.
      debugPrint('Pasos: $carpetaItinerarios/$clave.json es del papel «${itinerario.rol}»; no se enseña');
      return null;
    }
    final visibles = [
      for (final paso in itinerario.pasos)
        if (repo.visible(validado: itinerario.validado, fuente: _citasDe(paso))) paso,
    ];
    return visibles.isEmpty ? null : itinerario.conPasos(visibles);
  },
  // Un fallo inesperado no se arregla solo: la línea de pasos ofrece «Reintentar».
  retry: (_, _) => null,
);

/// Las citas de las fuentes de [paso], en un solo texto. Vacío si no hay ninguna de verdad.
String _citasDe(Paso paso) => [for (final cita in CitaPaso.de(paso.fuentes)) cita.original].join('; ');

/// Fase del formulario de entrada con la que se marca «Estás aquí» en la línea de [rol].
/// Si en el formulario se eligió otro papel, null: está mirando un papel que no es el suyo y no se le dice dónde está.
Fase? faseDeEntrada(Entrada entrada, String rol) {
  final suyo = entrada.rol;
  if (suyo != null && suyo != RolEntrada.noLoSe && suyo.valor != normalizar(rol.trim())) return null;
  return entrada.fase;
}
