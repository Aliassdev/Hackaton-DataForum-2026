import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ajustes.dart';
import '../../core/api/tuturno_api.dart';
import '../../core/providers.dart';
import '../../core/voz/tts.dart';
import '../../tema.dart';
import '../../widgets/animaciones.dart';
import '../../widgets/iconos/iconos.dart';
import '../../widgets/marca/marca.dart';
import '../../widgets/modulos.dart';
import '../../widgets/movimiento/hapticos.dart';
import '../../widgets/tuturno_scaffold.dart';

/// Tamaños de letra que se pueden elegir (multiplican el del sistema).
const tamanosTexto = [(1.0, 'Normal'), (1.15, 'Grande'), (1.3, 'Enorme')];

const velocidadMinima = 0.3;
const velocidadMaxima = 0.7;

/// Solo direcciones http:// o https:// con servidor.
bool esUrlServidorValida(String texto) {
  final uri = Uri.tryParse(texto.trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}

/// La APK release solo habla HTTPS (el tráfico sin cifrar solo está permitido en debug) y una web servida por
/// https no puede llamar a http://: en esos casos una dirección http:// no funcionaría.
bool soloHttps({bool release = kReleaseMode, bool web = kIsWeb, String esquemaPagina = ''}) =>
    release && (!web || esquemaPagina == 'https');

/// Qué decir cuando falla «Probar la conexión», según el código de [ApiException].
String pistaConexion(String codigo) => switch (codigo) {
  'SIN_API_URL' => 'Falta la dirección del servidor. Escríbela arriba.',
  'URL_INVALIDA' => 'Escribe la dirección completa, empezando por https://',
  'TIEMPO_AGOTADO' => 'El servidor tarda demasiado en responder. Prueba otra vez.',
  'SIN_CONEXION' => 'No llego al servidor. Revisa la dirección, el túnel y la conexión del móvil.',
  'RESPUESTA_INVALIDA' => 'El servidor responde, pero no como espera TuTurno. ¿Es la dirección correcta?',
  _ => 'No he podido hablar con el servidor ($codigo).',
};

const fraseProbarVoz = 'Hola. Así sonará la voz de TuTurno cuando te lea las respuestas.';

String nombreVelocidad(double v) {
  if (v < 0.45) return 'Más lenta';
  if (v > 0.55) return 'Más rápida';
  return 'Normal';
}

/// Ajustes (sección 6.4): tamaño de letra, voz y, para la demo, el servidor; al final, «Acerca de TuTurno». Todo se
/// queda en el móvil.
class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _url = TextEditingController();
  String? _errorUrl;

  /// La sección del servidor se ve en debug, en modo DEMO, si ya hay una dirección puesta o si falta la de serie.
  /// En el resto de casos se descubre con una pulsación larga en el pie.
  var _servidorRevelado = false;

  @override
  void initState() {
    super.initState();
    _url.text = ref.read(ajustesProvider).apiUrlManual ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _cambiar(Ajustes Function(Ajustes actuales) cambio) {
    Hapticos.seleccion();
    ref.read(ajustesProvider.notifier).actualizar(cambio);
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  void _usarServidor() {
    final url = _url.text.trim();
    if (!esUrlServidorValida(url)) {
      setState(() => _errorUrl = 'Escribe una dirección que empiece por http:// o https://');
      return;
    }
    if (Uri.parse(url).scheme == 'http' && soloHttps(esquemaPagina: kIsWeb ? Uri.base.scheme : '')) {
      setState(() => _errorUrl = 'En esta versión solo funciona https://');
      return;
    }
    setState(() => _errorUrl = null);
    FocusScope.of(context).unfocus();
    _cambiar((a) => a.copyWith(apiUrlManual: () => url));
    _avisar('Listo. Ahora uso este servidor.');
  }

  void _volverAlDeSerie() {
    _url.clear();
    setState(() => _errorUrl = null);
    FocusScope.of(context).unfocus();
    _cambiar((a) => a.copyWith(apiUrlManual: () => null));
    _avisar('Vuelvo a usar el servidor de serie.');
  }

  void _probarVoz() {
    Hapticos.seleccion();
    unawaited(ref.read(ttsProvider).hablar(fraseProbarVoz, velocidad: ref.read(ajustesProvider).velocidadVoz));
  }

  void _revelarServidor() {
    if (_servidorRevelado) return;
    Hapticos.toque();
    setState(() => _servidorRevelado = true);
    _avisar('Opciones del servidor visibles.');
  }

  @override
  Widget build(BuildContext context) {
    final ajustes = ref.watch(ajustesProvider);
    final config = ref.watch(configProvider);
    final mostrarServidor =
        _servidorRevelado ||
        kDebugMode ||
        config.demo ||
        ajustes.apiUrlManual != null ||
        (config.apiUrl.trim().isEmpty && !config.useMock);
    var orden = 0;
    return TuTurnoScaffold(
      titulo: 'Ajustes',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoMaximo),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Espacio.m, Espacio.s, Espacio.m, Espacio.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Entrada(
                  orden: orden++,
                  child: _Seccion(
                    icono: const _PegatinaLetra(),
                    titulo: 'Tamaño de la letra',
                    child: _TamanoLetra(
                      actual: ajustes.tamanoTexto,
                      onCambio: (t) => _cambiar((a) => a.copyWith(tamanoTexto: t)),
                    ),
                  ),
                ),
                const SizedBox(height: Espacio.m),
                Entrada(
                  orden: orden++,
                  child: _Seccion(
                    icono: const IconoTuTurno(TuIcono.altavoz, size: Espacio.xl + Espacio.xs, decorativo: true),
                    titulo: 'Voz',
                    child: _Voz(
                      ajustes: ajustes,
                      onVoz: (v) => _cambiar((a) => a.copyWith(vozActivada: v)),
                      onVelocidad: (v) => _cambiar((a) => a.copyWith(velocidadVoz: v)),
                      onProbar: _probarVoz,
                    ),
                  ),
                ),
                if (mostrarServidor) ...[
                  const SizedBox(height: Espacio.m),
                  Entrada(
                    orden: orden++,
                    child: _Servidor(
                      controlador: _url,
                      error: _errorUrl,
                      onUsar: _usarServidor,
                      onVolver: _volverAlDeSerie,
                    ),
                  ),
                ],
                if (kDebugMode || config.demo) ...[
                  const SizedBox(height: Espacio.m),
                  Entrada(orden: orden++, child: const _ParaElEquipo()),
                ],
                const SizedBox(height: Espacio.m),
                Entrada(orden: orden++, child: const _AcercaDe()),
                const SizedBox(height: Espacio.l),
                Entrada(
                  orden: orden++,
                  child: _Pie(onPulsacionLarga: _revelarServidor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Papel de los ajustes: blanco sobre el papel cálido en claro y un azul algo más claro en oscuro, con su borde y su
/// sombra. Es un Material: las ondas de los interruptores y botones de dentro se ven.
class _Papel extends StatelessWidget {
  const _Papel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(Radios.l);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: esquinas, boxShadow: sombrasPapel(context, elevacion: 0.8)),
      child: Material(
        color: context.colores.ticket,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: esquinas,
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

/// Una sección: su pegatina, el título en letras recortadas y el contenido.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.icono, required this.titulo, required this.child});

  final Widget icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return _Papel(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: icono),
                const SizedBox(width: Espacio.s + Espacio.xs),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      titulo,
                      style: tema.textTheme.headlineSmall?.copyWith(color: context.colores.tintaTicket),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            child,
          ],
        ),
      ),
    );
  }
}

/// «Aa» en una pegatina amarilla, un poco torcida: el icono del tamaño de la letra.
class _PegatinaLetra extends StatelessWidget {
  const _PegatinaLetra();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Transform.rotate(
      angle: -0.08,
      child: SizedBox.square(
        dimension: Espacio.xl + Espacio.xs,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ColoresMarca.amarillo,
            borderRadius: BorderRadius.circular(Radios.s - Espacio.xs),
            border: Border.all(color: ColoresMarca.azulNoche, width: 2),
            boxShadow: sombrasPapel(context, elevacion: 0.5),
          ),
          // Tamaño fijo: es un dibujo, no texto que haya que leer.
          child: Center(
            child: MediaQuery.withNoTextScaling(
              child: Text(
                'Aa',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontFamily: Fuentes.titulos,
                  fontFamilyFallback: const [Fuentes.texto],
                  color: ColoresMarca.azulNoche,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TamanoLetra extends StatelessWidget {
  const _TamanoLetra({required this.actual, required this.onCambio});

  final double actual;
  final ValueChanged<double> onCambio;

  /// El tamaño guardado más parecido a uno de los que se ofrecen.
  double get _seleccionado =>
      tamanosTexto.map((t) => t.$1).reduce((a, b) => (a - actual).abs() <= (b - actual).abs() ? a : b);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lo elegido, como una pegatina amarilla (el tema del botón segmentado).
        SegmentedButton<double>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(Espacio.xxl)),
          segments: [
            for (final (valor, nombre) in tamanosTexto)
              ButtonSegment(
                value: valor,
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(nombre)),
              ),
          ],
          selected: {_seleccionado},
          onSelectionChanged: (seleccion) => onCambio(seleccion.first),
        ),
        const SizedBox(height: Espacio.m),
        AnimatedContainer(
          duration: duracion(context, Duracion.media),
          padding: const EdgeInsets.all(Espacio.m),
          decoration: BoxDecoration(
            color: tinte(context, esquema.primary),
            border: Border.all(color: bordeTinte(esquema.primary)),
            borderRadius: BorderRadius.circular(Radios.m),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Así se verá', style: tema.textTheme.labelLarge?.copyWith(color: esquema.onSurfaceVariant)),
              const SizedBox(height: Espacio.xs),
              Text('Tienes derecho a que te escuchen y a entender todo lo que pasa.', style: tema.textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _Voz extends StatelessWidget {
  const _Voz({required this.ajustes, required this.onVoz, required this.onVelocidad, required this.onProbar});

  final Ajustes ajustes;
  final ValueChanged<bool> onVoz;
  final ValueChanged<double> onVelocidad;
  final VoidCallback onProbar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final velocidad = ajustes.velocidadVoz.clamp(velocidadMinima, velocidadMaxima).toDouble();
    final etiqueta = tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Leer las respuestas en voz alta'),
          subtitle: const Text('Si preguntas con la voz, te contesto también en voz alta. Siempre lo podrás leer.'),
          value: ajustes.vozActivada,
          onChanged: onVoz,
        ),
        const SizedBox(height: Espacio.s),
        Text('Velocidad de la voz', style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        // Con TalkBack se oye qué controla: «Velocidad de la voz, Normal».
        Semantics(
          label: 'Velocidad de la voz',
          child: Slider(
            min: velocidadMinima,
            max: velocidadMaxima,
            divisions: 4,
            value: velocidad,
            label: nombreVelocidad(velocidad),
            semanticFormatterCallback: nombreVelocidad,
            onChanged: onVelocidad,
          ),
        ),
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(child: Text('Más lenta', style: etiqueta)),
              Expanded(
                child: Text('Normal', textAlign: TextAlign.center, style: etiqueta),
              ),
              Expanded(
                child: Text('Más rápida', textAlign: TextAlign.end, style: etiqueta),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.m),
        OutlinedButton.icon(
          onPressed: onProbar,
          icon: const IconoTuTurno(TuIcono.altavoz, estilo: EstiloIcono.mono, decorativo: true),
          label: const Text('Probar la voz'),
        ),
      ],
    );
  }
}

class _Servidor extends ConsumerWidget {
  const _Servidor({required this.controlador, required this.error, required this.onUsar, required this.onVolver});

  final TextEditingController controlador;
  final String? error;
  final VoidCallback onUsar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final apiUrl = ref.watch(apiUrlProvider).trim();
    final simulado = ref.watch(configProvider.select((c) => c.useMock));
    return _Papel(
      child: Theme(
        // Sin las líneas que ExpansionTile pinta al abrirse.
        data: tema.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radios.l))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radios.l))),
          tilePadding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.xs),
          childrenPadding: const EdgeInsets.fromLTRB(Espacio.l, 0, Espacio.l, Espacio.l),
          leading: const IconoTuTurno(TuIcono.web, size: Espacio.xl + Espacio.xs, decorativo: true),
          title: Text(
            'Servidor (solo para la demo)',
            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(apiUrl.isEmpty ? 'sin configurar' : apiUrl),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (simulado) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tinte(context, esquema.primary),
                  border: Border.all(color: bordeTinte(esquema.primary)),
                  borderRadius: BorderRadius.circular(Radios.s),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Espacio.s + Espacio.xs),
                  child: Text(
                    'Ahora mismo las respuestas son simuladas: la app está en modo de prueba y no usa ningún servidor.',
                    style: tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: Espacio.m),
            ],
            TextField(
              controller: controlador,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onUsar(),
              decoration: InputDecoration(
                labelText: 'Dirección del servidor',
                hintText: 'https://…',
                errorText: error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: Espacio.m),
            FilledButton.tonalIcon(
              onPressed: onUsar,
              icon: const IconoTuTurno(TuIcono.check, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text('Usar este servidor'),
            ),
            const SizedBox(height: Espacio.s),
            const _ProbarConexion(),
            const SizedBox(height: Espacio.s),
            TextButton.icon(
              onPressed: onVolver,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Volver al de serie'),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Probar la conexión»: llama a /api/health y dice qué pasa con palabras claras (para montar la demo).
class _ProbarConexion extends ConsumerStatefulWidget {
  const _ProbarConexion();

  @override
  ConsumerState<_ProbarConexion> createState() => _ProbarConexionState();
}

class _ProbarConexionState extends ConsumerState<_ProbarConexion> {
  var _probando = false;
  String? _resultado;
  var _bien = false;

  Future<void> _probar() async {
    Hapticos.seleccion();
    setState(() {
      _probando = true;
      _resultado = null;
    });
    final simulado = ref.read(configProvider).useMock;
    String texto;
    var bien = false;
    try {
      final salud = await ref.read(apiProvider).health();
      bien = salud.estado == 'ok';
      texto = bien
          ? 'Conectado: el servidor responde${simulado ? ' (respuestas simuladas)' : ''}.'
          : 'El servidor responde, pero dice «${salud.estado}».';
    } on ApiException catch (e) {
      texto = pistaConexion(e.codigo);
    } catch (_) {
      texto = pistaConexion('');
    }
    if (!mounted) return;
    Hapticos.toque();
    setState(() {
      _probando = false;
      _resultado = texto;
      _bien = bien;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resultado = _resultado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _probando ? null : _probar,
          icon: _probando
              ? const SizedBox.square(
                  dimension: Espacio.m + Espacio.xs,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: Text(_probando ? 'Probando…' : 'Probar la conexión'),
        ),
        AnimatedSize(
          duration: duracionTamano(context, Duracion.media),
          alignment: Alignment.topCenter,
          child: resultado == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Espacio.s),
                  child: Semantics(
                    liveRegion: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconoTuTurno(_bien ? TuIcono.check : TuIcono.cruz, decorativo: true),
                        const SizedBox(width: Espacio.s),
                        Expanded(
                          child: Text(
                            resultado,
                            key: const Key('resultado-conexion'),
                            style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Pie extends StatelessWidget {
  const _Pie({this.onPulsacionLarga});

  /// Descubre las opciones del servidor (para preparar la demo en una APK release).
  final VoidCallback? onPulsacionLarga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return GestureDetector(
      onLongPress: onPulsacionLarga,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const IconoTuTurno(TuIcono.candado, size: Espacio.m + Espacio.xs, decorativo: true),
          const SizedBox(width: Espacio.s),
          Flexible(
            child: Text(
              'Todo esto se guarda solo en tu móvil.',
              style: tema.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// «Acerca de TuTurno»: el icono de la app, el logotipo y lo que se queda (y lo que no) en el móvil.
class _AcercaDe extends StatelessWidget {
  const _AcercaDe();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final secundario = tema.textTheme.bodyMedium?.copyWith(color: esquema.onSurfaceVariant);
    return _Papel(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'ACERCA DE',
                style: tema.textTheme.labelLarge?.copyWith(
                  color: esquema.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: Espacio.m),
            Row(
              children: [
                const PlacaTut(lado: 72, etiqueta: null),
                const SizedBox(width: Espacio.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(fit: BoxFit.scaleDown, child: LogoTuTurno(alto: 28)),
                      const SizedBox(height: Espacio.s),
                      Text('La justicia, explicada con palabras claras.', style: tema.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espacio.m),
            Text(
              'Sin cuentas ni datos personales. Tus ajustes y tu progreso se quedan en este móvil, y la app no guarda '
              'tus conversaciones.',
              style: secundario,
            ),
            const SizedBox(height: Espacio.s),
            Text('DATAthon DATAfórum Justicia 2026 · Reto 2: infancia y juventud.', style: secundario),
          ],
        ),
      ),
    );
  }
}

/// Solo en depuración o con DEMO=true: la galería de iconos y de Tut, para revisarlos en el móvil.
class _ParaElEquipo extends StatelessWidget {
  const _ParaElEquipo();

  void _abrirGaleria(BuildContext context) {
    Hapticos.seleccion();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Iconos de TuTurno')),
          body: const GaleriaIconos(animada: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return _Papel(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Para el equipo (demo)',
                style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: Espacio.s),
            OutlinedButton.icon(
              onPressed: () => _abrirGaleria(context),
              icon: const IconoTuTurno(TuIcono.estrella, estilo: EstiloIcono.mono, decorativo: true),
              label: const Text('Ver los iconos y a Tut'),
            ),
          ],
        ),
      ),
    );
  }
}
