import 'package:flutter/material.dart';

import '../../tema.dart' show duracionTamano;
import '../motor/motor.dart' show PaletaPixel;
import 'roles_juzgado.dart';

// Colores de la marca, los mismos que los del pixel art (PaletaPixel), para que la carta y la sala sean un solo mundo.
final _amarillo = PaletaPixel.amarillo.color;
final _azul = PaletaPixel.azul.color;
final _noche = PaletaPixel.noche.color;

/// Espacios de la carta (los de la app: 4, 8, 16, 24).
const _xs = 4.0;
const _s = 8.0;
const _m = 16.0;

/// Carta de una persona de la sala, de papel plano: el icono en una pegatina amarilla, el título con la letra de los
/// títulos del tema, «Quién es», «Qué hace», un «¿Sabías que…?» y las normas de las que sale todo (al tocar «Qué dice
/// la ley» se ven las citas literales del BOE).
///
/// Mide lo que le deje el padre de ancho; de alto, lo que necesite (con letra grande, crece).
class CartaRol extends StatelessWidget {
  const CartaRol({super.key, required this.rol, this.alCerrar});

  final RolJuzgado rol;

  /// Si no es null, la carta lleva un botón de cerrar.
  final VoidCallback? alCerrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final oscuro = tema.brightness == Brightness.dark;
    final texto = tema.textTheme;
    final subtitulo = rol.subtitulo;
    final sabiasQue = rol.sabiasQue;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: oscuro ? esquema.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: oscuro ? esquema.outline : _noche, width: 2),
          // Sombra dura y corta, como la de un papel recortado.
          boxShadow: [
            BoxShadow(
              color: _noche.withValues(alpha: oscuro ? 0.6 : 0.9),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_m, _m, _s, _m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Pegatina(icono: rol.icono),
                  const SizedBox(width: _m - _xs),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: _xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(rol.titulo, style: texto.headlineSmall?.copyWith(color: esquema.onSurface)),
                          ),
                          if (subtitulo != null)
                            Text(
                              subtitulo,
                              style: texto.titleSmall?.copyWith(
                                color: esquema.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (alCerrar != null)
                    IconButton(
                      onPressed: alCerrar,
                      tooltip: 'Cerrar',
                      icon: Icon(Icons.close_rounded, color: esquema.onSurfaceVariant),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: _s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: _m),
                    _Apartado(etiqueta: 'Quién es', texto: rol.quienEs),
                    const SizedBox(height: _m),
                    _Apartado(etiqueta: 'Qué hace', texto: rol.queHace),
                    if (sabiasQue != null) ...[const SizedBox(height: _m), _SabiasQue(texto: sabiasQue)],
                    const SizedBox(height: _m),
                    _Fuentes(key: ValueKey(rol.id), fuentes: rol.fuentes),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El icono del rol en un círculo amarillo con borde azul noche, como una pegatina.
class _Pegatina extends StatelessWidget {
  const _Pegatina({required this.icono});

  final IconData icono;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _amarillo,
        shape: BoxShape.circle,
        border: Border.all(color: _noche, width: 2),
      ),
      child: Icon(icono, size: 30, color: _noche),
    ),
  );
}

/// Un apartado de la carta: la etiqueta en un ticket azul y el texto debajo.
class _Apartado extends StatelessWidget {
  const _Apartado({required this.etiqueta, required this.texto});

  final String etiqueta;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Ticket(texto: etiqueta),
          const SizedBox(height: _s - 2),
          Text(texto, style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurface, height: 1.4)),
        ],
      ),
    );
  }
}

/// Una etiqueta corta en mayúsculas sobre azul, como el talón de un ticket.
class _Ticket extends StatelessWidget {
  const _Ticket({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: oscuro ? _amarillo : _azul, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _s + 2, vertical: 3),
        child: Text(
          texto.toUpperCase(),
          style: tema.textTheme.labelLarge?.copyWith(
            color: oscuro ? _noche : Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _SabiasQue extends StatelessWidget {
  const _SabiasQue({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    final tinta = oscuro ? tema.colorScheme.onSurface : _noche;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(_m - _xs),
        decoration: BoxDecoration(
          color: _amarillo.withValues(alpha: oscuro ? 0.16 : 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_rounded, color: oscuro ? _amarillo : PaletaPixel.ocre.color, size: 26),
            const SizedBox(width: _s + 2),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '¿Sabías que…? ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: texto),
                  ],
                ),
                style: tema.textTheme.bodyLarge?.copyWith(color: tinta, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las normas de las que sale la carta y, al tocar «Qué dice la ley», sus citas literales.
class _Fuentes extends StatefulWidget {
  const _Fuentes({super.key, required this.fuentes});

  final List<FuenteJuzgado> fuentes;

  @override
  State<_Fuentes> createState() => _FuentesState();
}

class _FuentesState extends State<_Fuentes> {
  var _abiertas = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final texto = tema.textTheme;
    final fuentes = widget.fuentes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.menu_book_rounded, size: 20, color: esquema.onSurfaceVariant),
            ),
            const SizedBox(width: _s),
            Expanded(
              child: Text(
                'Fuente: ${fuentes.map((fuente) => fuente.etiqueta).join(' · ')}',
                style: texto.bodyMedium?.copyWith(color: esquema.onSurfaceVariant, height: 1.35),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => setState(() => _abiertas = !_abiertas),
          icon: Icon(_abiertas ? Icons.expand_less_rounded : Icons.expand_more_rounded),
          label: Text(_abiertas ? 'Ocultar qué dice la ley' : 'Qué dice la ley'),
        ),
        AnimatedSize(
          // Nunca cero: con «reducir animaciones», AnimatedSize con duración cero salta un assert en debug.
          duration: duracionTamano(context, const Duration(milliseconds: 260)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_abiertas
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final fuente in fuentes) _Cita(fuente: fuente)],
                ),
        ),
      ],
    );
  }
}

class _Cita extends StatelessWidget {
  const _Cita({required this.fuente});

  final FuenteJuzgado fuente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final texto = tema.textTheme;
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(top: _s),
        padding: const EdgeInsets.all(_m - _xs),
        decoration: BoxDecoration(
          color: esquema.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: _azul, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fuente.nombreNorma}, ${fuente.referencia}',
              style: texto.titleSmall?.copyWith(color: esquema.onSurface, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: _xs),
            Text(
              '«${fuente.cita}»',
              style: texto.bodyMedium?.copyWith(color: esquema.onSurface, fontStyle: FontStyle.italic, height: 1.4),
            ),
            const SizedBox(height: _xs),
            Text('BOE: ${fuente.boe}', style: texto.labelMedium?.copyWith(color: esquema.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Lo que se ve antes de tocar a nadie: cómo se juega.
class IndicacionJuzgado extends StatelessWidget {
  const IndicacionJuzgado({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return MergeSemantics(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: _amarillo, shape: BoxShape.circle),
              child: Icon(Icons.touch_app_rounded, color: _noche),
            ),
          ),
          const SizedBox(width: _m - _xs),
          Expanded(
            child: Text(
              'Toca a una persona de la sala para saber quién es y qué hace. Las chispas señalan a quien te falta '
              'por conocer. ¿No encuentras a alguien? Toca su nombre abajo y se iluminará.',
              style: tema.textTheme.bodyLarge?.copyWith(color: esquema.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un aviso sobre la sala («Hoy no hay público»), con sus fuentes.
class NotaSala extends StatelessWidget {
  const NotaSala({super.key, required this.nota});

  final NotaJuzgado nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final texto = tema.textTheme;
    final oscuro = tema.brightness == Brightness.dark;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(_m - _xs),
        decoration: BoxDecoration(
          color: oscuro ? esquema.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: oscuro ? esquema.outline : _noche, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(nota.icono, color: oscuro ? _amarillo : _azul, size: 28),
            const SizedBox(width: _m - _xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nota.titulo, style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(nota.texto, style: texto.bodyLarge?.copyWith(color: esquema.onSurface, height: 1.4)),
                  const SizedBox(height: _xs),
                  Text(
                    'Fuente: ${nota.fuentes.map((fuente) => fuente.etiqueta).join(' · ')}',
                    style: texto.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La enhorabuena cuando ya se conoce a todo el mundo.
class EnhorabuenaJuzgado extends StatelessWidget {
  const EnhorabuenaJuzgado({super.key, required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(_m),
        decoration: BoxDecoration(
          color: _amarillo,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _noche, width: 2),
          boxShadow: [BoxShadow(color: _noche, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(Icons.celebration_rounded, color: _noche, size: 40),
            const SizedBox(width: _m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Ya sabes quién es quién!', style: tema.textTheme.headlineSmall?.copyWith(color: _noche)),
                  const SizedBox(height: 2),
                  Text(
                    'Has conocido a las $total personas de la sala. Toca a cualquiera para repasar su carta.',
                    style: tema.textTheme.bodyLarge?.copyWith(color: _noche, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las personas de la sala como una colección de fichas: amarillas las que ya se conocen (al tocarlas se abre su
/// carta) y en blanco las que faltan (al tocarlas, esa persona se ilumina en la sala para encontrarla; con lector de
/// pantalla, [accesible], se abre su carta).
class FichasJuzgado extends StatelessWidget {
  const FichasJuzgado({
    super.key,
    required this.roles,
    required this.descubiertos,
    required this.alTocar,
    this.pista,
    this.accesible = false,
  });

  final List<RolJuzgado> roles;
  final Set<String> descubiertos;

  /// Se llama con el id de la ficha que se toca.
  final ValueChanged<String> alTocar;

  /// La persona que está iluminada en la sala.
  final String? pista;

  /// Con navegación accesible (TalkBack): la ficha de quien falta abre su carta en vez de iluminarle en el dibujo.
  final bool accesible;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Personas de la sala',
            style: tema.textTheme.titleMedium?.copyWith(color: tema.colorScheme.onSurface, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: _s + 2),
        Wrap(
          spacing: _s,
          runSpacing: _s,
          children: [
            for (final rol in roles)
              _Ficha(
                rol: rol,
                descubierta: descubiertos.contains(rol.id),
                iluminada: rol.id == pista,
                accesible: accesible,
                alTocar: () => alTocar(rol.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({
    required this.rol,
    required this.descubierta,
    required this.iluminada,
    required this.accesible,
    required this.alTocar,
  });

  final RolJuzgado rol;
  final bool descubierta;
  final bool iluminada;
  final bool accesible;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final oscuro = tema.brightness == Brightness.dark;
    final Color fondo;
    final Color borde;
    final Color tinta;
    if (descubierta) {
      (fondo, borde, tinta) = (_amarillo, _noche, _noche);
    } else if (iluminada) {
      (fondo, borde, tinta) = (
        oscuro ? esquema.surfaceContainerHigh : PaletaPixel.hielo.color,
        _azul,
        esquema.onSurface,
      );
    } else {
      (fondo, borde, tinta) = (
        oscuro ? esquema.surfaceContainerHigh : Colors.white,
        oscuro ? esquema.outline : esquema.outlineVariant,
        esquema.onSurfaceVariant,
      );
    }
    final forma = StadiumBorder(side: BorderSide(color: borde, width: 2));
    return Semantics(
      button: true,
      label: descubierta
          ? '${rol.titulo}. Ya sabes quién es: toca para ver su carta.'
          : accesible
          ? '${rol.titulo}. Todavía no: toca para saber quién es.'
          : '${rol.titulo}. Todavía no: toca para ver dónde está en la sala.',
      onTap: alTocar,
      excludeSemantics: true,
      child: Material(
        color: fondo,
        shape: forma,
        child: InkWell(
          customBorder: forma,
          onTap: alTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_s - 2, _xs, _m - 2, _xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: descubierta ? _noche : Colors.transparent,
                      shape: BoxShape.circle,
                      border: descubierta ? null : Border.all(color: borde, width: 2),
                    ),
                    child: Icon(
                      descubierta ? rol.icono : Icons.question_mark_rounded,
                      size: 18,
                      color: descubierta ? _amarillo : tinta,
                    ),
                  ),
                  const SizedBox(width: _s),
                  Flexible(
                    child: Text(
                      rol.corto,
                      style: tema.textTheme.labelLarge?.copyWith(color: tinta, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
