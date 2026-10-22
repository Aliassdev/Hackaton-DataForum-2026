import 'package:flutter/material.dart' show Material, MaterialType, Theme;
import 'package:flutter/widgets.dart';

import '../../widgets/ayuda_button.dart';
import '../motor/escena_pixel.dart';
import '../motor/lienzo_pixel.dart';
import '../motor/sprite.dart';
import 'barra_pixel.dart';
import 'boton_pixel.dart';
import 'carta_pixel.dart';
import 'dialogo_pixel.dart';
import 'estilo_pixel.dart';
import 'hud_pixel.dart';
import 'iconos_pixel.dart';
import 'marco_pixel.dart';
import 'menu_opciones_pixel.dart';
import 'pintura_pixel.dart';
import 'rotulo_pixel.dart';
import 'ticket_pixel.dart';
import 'transicion_pixel.dart';

/// Todo el kit pixel en una pantalla, para revisarlo: cada pieza en sus estados, las piezas sobre el fondo del juego
/// y una pantalla de juego de ejemplo (marco, HUD con Glosario y Ayuda, escena y diálogo). Todo se puede tocar. Usa
/// el fondo del tema (claro u oscuro).
class GaleriaPixelUi extends StatefulWidget {
  const GaleriaPixelUi({super.key});

  @override
  State<GaleriaPixelUi> createState() => _GaleriaPixelUiState();
}

class _GaleriaPixelUiState extends State<GaleriaPixelUi> {
  static const _frases = [
    ('Lucía', 'Hoy vengo al juzgado con mi tía Elena. Me han dicho que solo tendré que contarlo una vez.'),
    ('Ana', 'Hola, Lucía. Soy Ana, la psicóloga. Hablaremos en una sala tranquila y puedes parar cuando quieras.'),
    (null, 'La sala tiene sofás, cojines y un espejo grande. Lucía respira hondo.'),
  ];

  static const _pregunta = '¿Qué es este papel?';

  // La correcta no va la primera (ni el cursor empieza en ella): si no, se aprende el sitio y no la respuesta.
  static const _opciones = [
    'Una multa',
    'Una citación: dice cuándo y dónde tiene que ir a declarar',
    'Una nota del instituto',
  ];
  static const _correcta = 1;

  double _progreso = 0.4;
  int _cartas = 2;
  int _frase = 0;
  int? _elegida;
  final _dialogo = ControladorDialogoPixel();

  @override
  void dispose() {
    _dialogo.dispose();
    super.dispose();
  }

  void _cambiarProgreso(double cambio) => setState(() => _progreso = (_progreso + cambio).clamp(0.0, 1.0));

  void _elegir(int indice) => setState(() {
    _elegida = indice;
    if (indice == _correcta && _cartas < 5) _cartas++;
  });

  void _probarTransicion() {
    final reducir = MediaQuery.disableAnimationsOf(context);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: reducir ? DuracionTransicionPixel.fundido : DuracionTransicionPixel.entrada,
        reverseTransitionDuration: reducir ? DuracionTransicionPixel.fundido : DuracionTransicionPixel.salida,
        transitionsBuilder: transicionPixel,
        pageBuilder: (context, animation, secondaryAnimation) => const _PantallaDeJuego(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final tinta = Theme.of(context).colorScheme.onSurface;
    final (hablante, frase) = _frases[_frase];
    return FondoPixel(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: ScrollPixel(
          child: ListView(
            // Sin una capa por pieza: al desplazar, cada pieza se vuelve a pintar ajustada a los píxeles (AjustePixel).
            addRepaintBoundaries: false,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            children: [
              Text('Kit pixel', style: estiloTextoPixel(context, TipoTextoPixel.grande, color: tinta)),
              SizedBox(height: u),
              Text(
                'La interfaz de Vive el caso: un juego de 8 bits dentro de TuTurno.',
                style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: tinta),
              ),
              _Seccion(
                titulo: 'Botones',
                children: [
                  Wrap(
                    spacing: 3 * u,
                    runSpacing: 3 * u,
                    children: [
                      BotonPixel(etiqueta: 'Empezar', icono: const IconoPixel(GlifoPixel.flecha), onPressed: () {}),
                      BotonPixel(
                        etiqueta: 'Mis cartas',
                        icono: const IconoPixel(GlifoPixel.carta),
                        variante: VarianteBotonPixel.secundario,
                        onPressed: () {},
                      ),
                      BotonPixel(etiqueta: 'Salir del caso', variante: VarianteBotonPixel.peligro, onPressed: () {}),
                      const BotonPixel(etiqueta: 'Bloqueado', icono: IconoPixel(GlifoPixel.candado), onPressed: null),
                      BotonPixel(
                        icono: const IconoPixel(GlifoPixel.altavoz),
                        semantica: 'Escuchar otra vez',
                        variante: VarianteBotonPixel.secundario,
                        onPressed: () {},
                      ),
                    ],
                  ),
                  SizedBox(height: 3 * u),
                  BotonPixel(etiqueta: 'Continuar', expandido: true, onPressed: () {}),
                ],
              ),
              _Seccion(
                titulo: 'Barras',
                children: [
                  BarraPixel(
                    valor: _progreso,
                    etiqueta: 'Progreso del caso',
                    textoValor: '${(_progreso * 10).round()} de 10 escenas',
                  ),
                  SizedBox(height: 3 * u),
                  const BarraPixel(
                    valor: 0.6,
                    segmentos: 5,
                    etiqueta: 'Cartas de la colección',
                    textoValor: '3 de 5 cartas',
                    color: ColoresUiPixel.azulClaro,
                    luz: ColoresUiPixel.cielo,
                    sombraColor: ColoresUiPixel.azul,
                  ),
                  SizedBox(height: 3 * u),
                  Row(
                    children: [
                      Expanded(
                        child: BotonPixel(
                          etiqueta: 'Menos',
                          variante: VarianteBotonPixel.secundario,
                          expandido: true,
                          onPressed: _progreso <= 0 ? null : () => _cambiarProgreso(-0.1),
                        ),
                      ),
                      SizedBox(width: 3 * u),
                      Expanded(
                        child: BotonPixel(
                          etiqueta: 'Más',
                          expandido: true,
                          onPressed: _progreso >= 1 ? null : () => _cambiarProgreso(0.1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Diálogo',
                children: [
                  DialogoPixel(
                    hablante: hablante,
                    texto: frase,
                    controlador: _dialogo,
                    onContinuar: () => setState(() => _frase = (_frase + 1) % _frases.length),
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Opciones',
                children: [
                  Text(_pregunta, style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: tinta)),
                  SizedBox(height: 2 * u),
                  MenuOpcionesPixel(
                    etiqueta: _pregunta,
                    opciones: _opciones,
                    correctas: const {_correcta},
                    elegida: _elegida,
                    cursorInicial: 0,
                    onElegir: _elegir,
                  ),
                  if (_elegida != null) ...[
                    SizedBox(height: 3 * u),
                    BotonPixel(
                      etiqueta: 'Otra vez',
                      variante: VarianteBotonPixel.secundario,
                      onPressed: () => setState(() => _elegida = null),
                    ),
                  ],
                ],
              ),
              _Seccion(
                titulo: 'Ticket',
                children: [
                  TicketPixel(
                    semantica: 'Tu turno: A 07. Vive el caso, caso 1: Lucía.',
                    onPressed: () {},
                    talon: const Column(mainAxisSize: MainAxisSize.min, children: [Text('TURNO'), RotuloPixel('A-07')]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Vive el caso',
                          style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: ColoresUiPixel.noche),
                        ),
                        SizedBox(height: u),
                        // Espacio duro: «11 años» no se parte.
                        const Text('Caso 1 · Lucía, 11 años'),
                      ],
                    ),
                  ),
                ],
              ),
              _Seccion(titulo: 'Cartas', children: [const _Cartas()]),
              _Seccion(titulo: 'Sobre el fondo del juego', children: [const _SobreElFondo()]),
              _Seccion(
                titulo: 'Marco y HUD',
                children: [
                  MarcoPixel(
                    titulo: 'Vive el caso',
                    child: ColoredBox(
                      color: ColoresUiPixel.noche,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HudPixel(
                            titulo: 'El caso de Lucía',
                            progreso: _progreso,
                            textoProgreso: '${(_progreso * 10).round()} de 10 escenas',
                            cartas: _cartas,
                            totalCartas: 5,
                            onVolver: () {},
                          ),
                          EscenaPixel(
                            fondo: _salaDeEspera,
                            colorMarco: ColoresUiPixel.noche,
                            descripcion: 'La sala de espera del juzgado',
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(2 * u, 2 * u, 2 * u, 3 * u),
                            child: DialogoPixel(
                              hablante: 'Funcionaria',
                              texto: 'Te llamarán por tu nombre. Mientras, puedes esperar aquí.',
                              onContinuar: () {},
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 5 * u),
                  Text(
                    'Con los botones de la app (Glosario y Ayuda):',
                    style: estiloTextoPixel(context, TipoTextoPixel.cuerpo, color: tinta),
                  ),
                  SizedBox(height: 2 * u),
                  HudPixel(
                    key: const ValueKey('hud con acciones'),
                    titulo: 'El caso de Lucía',
                    progreso: _progreso,
                    textoProgreso: '${(_progreso * 10).round()} de 10 escenas',
                    cartas: _cartas,
                    totalCartas: 5,
                    onVolver: () {},
                    acciones: const [GlosarioButton(), AyudaButton()],
                  ),
                ],
              ),
              _Seccion(
                titulo: 'Transición',
                children: [
                  BotonPixel(
                    etiqueta: 'Entrar en el juego',
                    icono: const IconoPixel(GlifoPixel.estrella),
                    onPressed: _probarTransicion,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un apartado de la galería: un título con su marca pixel y las piezas debajo.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final tinta = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(top: 10 * u),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Row(
              children: [
                const CajaPixel(
                  estilo: EstiloCajaPixel(relleno: ColoresUiPixel.amarillo, esquina: 0, sombra: null, profundidad: 0),
                  conFilo: false,
                  child: SizedBox.square(dimension: 12),
                ),
                SizedBox(width: 3 * u),
                Expanded(
                  child: Text(titulo, style: estiloTextoPixel(context, TipoTextoPixel.titulo, color: tinta)),
                ),
              ],
            ),
          ),
          SizedBox(height: 4 * u),
          ...children,
        ],
      ),
    );
  }
}

/// Una carta desbloqueada y una bloqueada: de pie y en dos columnas si cada una tiene 200 puntos (con la letra del
/// sistema) y, si no (un móvil), tumbadas y en una columna, para que el texto se lea bien.
class _Cartas extends StatelessWidget {
  const _Cartas();

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final escala = escalaTextoPixel(context);
    List<Widget> cartas(FormatoCartaPixel formato) => [
      CartaPixel(
        numero: 1,
        titulo: 'Derecho a entender',
        texto: 'Si no entiendes algo, pide que te lo expliquen.',
        formato: formato,
        onPressed: () {},
      ),
      CartaPixel(
        numero: 2,
        titulo: 'Ir acompañada',
        texto: 'Puedes estar con un adulto de confianza.',
        formato: formato,
        bloqueada: true,
      ),
    ];
    return LayoutBuilder(
      builder: (context, restricciones) {
        if (restricciones.maxWidth >= (400 + 3 * u) * escala) {
          final dos = cartas(FormatoCartaPixel.vertical);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dos[0]),
              SizedBox(width: 3 * u),
              Expanded(child: dos[1]),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, carta) in cartas(FormatoCartaPixel.horizontal).indexed) ...[
              if (i > 0) SizedBox(height: 4 * u),
              carta,
            ],
          ],
        );
      },
    );
  }
}

/// Las piezas sobre el azul noche del juego: las que no se verían llevan su filo.
class _SobreElFondo extends StatelessWidget {
  const _SobreElFondo();

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    return FondoPixel(
      color: ColoresUiPixel.noche,
      child: Padding(
        padding: EdgeInsets.all(4 * u),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 3 * u,
              runSpacing: 3 * u,
              children: [
                BotonPixel(etiqueta: 'Seguir', icono: const IconoPixel(GlifoPixel.flecha), onPressed: () {}),
                BotonPixel(
                  icono: const IconoPixel(GlifoPixel.altavoz),
                  semantica: 'Escuchar otra vez',
                  variante: VarianteBotonPixel.secundario,
                  onPressed: () {},
                ),
                BotonPixel(etiqueta: 'Salir', variante: VarianteBotonPixel.peligro, onPressed: () {}),
                const BotonPixel(etiqueta: 'Bloqueado', onPressed: null),
              ],
            ),
            SizedBox(height: 4 * u),
            const BarraPixel(valor: 0.3, etiqueta: 'Progreso', textoValor: '3 de 10 escenas'),
            SizedBox(height: 4 * u),
            const MenuOpcionesPixel(
              opciones: ['Quedarme callado', 'Pedir que me lo expliquen', 'Irme a casa'],
              correctas: {1},
              elegida: 0,
              onElegir: null,
            ),
            SizedBox(height: 4 * u),
            const TicketPixel(talon: RotuloPixel('B-12'), child: Text('Caso 2 · Sergio, 13 años')),
            SizedBox(height: 4 * u),
            const CartaPixel(
              numero: 4,
              titulo: 'Fiscalía de Menores',
              texto: 'Protege a los chicos y chicas mientras dura el proceso.',
              formato: FormatoCartaPixel.horizontal,
              color: ColoresUiPixel.verdeOscuro,
              luz: ColoresUiPixel.verde,
              sombraColor: ColoresUiPixel.noche,
              brillo: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// La pantalla a la que lleva la transición de ejemplo: una escena del juego con su HUD, el diálogo y una decisión,
/// sobre el azul noche del juego.
class _PantallaDeJuego extends StatefulWidget {
  const _PantallaDeJuego();

  @override
  State<_PantallaDeJuego> createState() => _PantallaDeJuegoState();
}

class _PantallaDeJuegoState extends State<_PantallaDeJuego> {
  static const _pregunta = '¿Qué puede pedir Lucía antes de entrar?';
  static const _correcta = 1;
  int? _elegida;

  @override
  Widget build(BuildContext context) {
    final u = unidadPixel(context);
    final volver = Navigator.of(context).pop;
    // Material: los botones de la app (Glosario y Ayuda) lo necesitan para su efecto al tocarlos.
    return Material(
      type: MaterialType.transparency,
      child: FondoPixel(
        color: ColoresUiPixel.noche,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HudPixel(
              titulo: 'El caso de Lucía',
              progreso: _elegida == null ? 0.1 : 0.2,
              textoProgreso: _elegida == null ? '1 de 10 escenas' : '2 de 10 escenas',
              cartas: _elegida == _correcta ? 1 : 0,
              totalCartas: 5,
              onVolver: volver,
              acciones: const [GlosarioButton(), AyudaButton()],
            ),
            Expanded(
              child: ScrollPixel(
                child: ListView(
                  addRepaintBoundaries: false,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    MarcoPixel(
                      child: EscenaPixel(
                        fondo: _salaDeEspera,
                        colorMarco: ColoresUiPixel.noche,
                        descripcion: 'La sala de espera del juzgado',
                      ),
                    ),
                    SizedBox(height: 5 * u),
                    DialogoPixel(hablante: 'Lucía', texto: 'Ya estoy dentro. ¿Qué puedo pedir?', onContinuar: () {}),
                    SizedBox(height: 5 * u),
                    MenuOpcionesPixel(
                      etiqueta: _pregunta,
                      opciones: const ['Irme sin decir nada', 'Que me acompañe mi tía'],
                      correctas: const {_correcta},
                      elegida: _elegida,
                      onElegir: (indice) => setState(() => _elegida = indice),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una sala de espera sencilla, dibujada con el motor, para la pantalla de ejemplo.
final Sprite _salaDeEspera = () {
  const ancho = 96;
  const alto = 54;
  final sala = LienzoPixel(ancho, alto, 'P')
    // Zócalo azul hielo y suelo de madera con sus tablas.
    ..rect(0, 29, ancho, 9, 'h')
    ..lineaH(0, 29, ancho, 'c')
    ..rect(0, 38, ancho, alto - 38, 'm')
    ..lineaH(0, 38, ancho, 'N');
  for (var y = 42, fila = 0; y < alto; y += 4, fila++) {
    sala.lineaH(0, y, ancho, 't');
    for (var x = fila.isEven ? 5 : 11; x < ancho; x += 12) {
      sala.lineaV(x, y - 3, 3, 't');
    }
  }
  // Ventana con cielo, nube y brillos.
  sala
    ..rect(8, 7, 24, 18, 'c')
    ..rect(12, 11, 7, 2, 'W')
    ..rect(14, 10, 3, 1, 'W')
    ..rect(22, 18, 6, 2, 'h')
    ..marco(8, 7, 24, 18, 'N')
    ..lineaV(19, 7, 18, 'N')
    ..lineaH(8, 15, 24, 'N')
    ..rect(7, 25, 26, 2, 'p')
    ..lineaH(7, 26, 26, 'o');
  // Puerta de la sala, con su cartel de la justicia.
  sala
    ..rect(66, 13, 18, 25, 'D')
    ..rect(68, 15, 14, 9, 'A')
    ..rect(68, 26, 14, 10, 'A')
    ..marco(66, 13, 18, 25, 'N')
    ..marco(68, 15, 14, 9, 'N')
    ..marco(68, 26, 14, 10, 'N')
    ..rect(79, 25, 2, 2, 'Y')
    ..rect(63, 3, 24, 8, 'Y')
    ..marco(63, 3, 24, 8, 'N')
    ..lineaH(64, 4, 22, 'y')
    ..pegar(['....N....', 'NNNNNNNNN', 'N...N...N', 'NN..N..NN', '...NNN...'], 70, 5);
  // Banco de madera.
  sala
    ..rect(36, 30, 24, 2, 'm')
    ..marco(36, 29, 24, 4, 'N')
    ..rect(37, 30, 22, 2, 'm')
    ..rect(38, 33, 2, 5, 'N')
    ..rect(56, 33, 2, 5, 'N')
    ..lineaH(37, 30, 22, 'o');
  // Planta.
  sala.pegar(['..v.v..', '.vvVvv.', 'vvVvVvv', '.vVvVv.', '..NNN..', '.NRRRN.', '.NRRRN.', '..NNN..'], 87, 30);
  return Sprite('sala de espera de la galería', sala.filas);
}();
