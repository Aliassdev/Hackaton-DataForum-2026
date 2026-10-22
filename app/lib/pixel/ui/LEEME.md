# Kit de interfaz pixel de «Vive el caso»

Al entrar en «Vive el caso» se entra en un juego retro: no solo los personajes y los lugares (el motor, en `lib/pixel/motor/`), también los botones, las barras, los tickets, las cartas y la letra son pixel art. El resto de la app mantiene su identidad plana amarilla y azul; este kit es el «mundo de juego» de dentro.

Todo se pinta con código sobre una rejilla de unidades pixel, sin esquinas redondas, desenfoques ni suavizado: bordes escalonados, sombras duras y, al pulsar, la pieza baja una unidad hasta su sombra. Los colores son los de `PaletaPixel` (una prueba lo comprueba).

```dart
import 'package:tuturno/pixel/ui/ui.dart';
```

## Cómo montar la interfaz de Vive el caso

1. **La letra.** Declarar en `pubspec.yaml` la familia `PixelifySans`: `assets/fonts/PixelifySans-Regular.ttf`, `PixelifySans-SemiBold.ttf` con `weight: 600` y `PixelifySans-Bold.ttf` con `weight: 700`.
2. **Un `TemaPixel` encima de todo el juego** (en el `builder` de la rama `/juego` o en cada pantalla del juego). Es el único interruptor de la letra y pone el scroll del juego (`ScrollPixel`: sin el estirado de Android, que reescala la lista y emborrona el pixel art):

   ```dart
   TemaPixel(lecturaFacil: ajustes.lecturaFacil, child: pantallaDelJuego)
   ```

3. **Las rutas del juego, con la transición a bloques.** Mientras dura no se puede tocar nada:

   ```dart
   GoRoute(path: '/juego/:casoId', pageBuilder: (context, state) => paginaPixel(context, state, JuegoScreen(...)))
   ```

4. **La pantalla de juego**, sobre el azul noche del juego. `FondoPixel` lo pinta y avisa a las piezas: las que no se verían sobre él (contorno azul noche) llevan un filo azul alrededor.

   ```dart
   Scaffold(
     body: FondoPixel(
       color: ColoresUiPixel.noche,
       child: Column(children: [
         HudPixel(
           titulo: caso.titulo,
           progreso: escena / total,
           textoProgreso: '$escena de $total escenas',
           cartas: conseguidas,
           totalCartas: caso.cartas.length,
           onVolver: salir,
           acciones: const [GlosarioButton(), AyudaButton()], // la regla de la app: arriba a la derecha
         ),
         Expanded(
           child: ListView(
             addRepaintBoundaries: false, // ver «Nitidez»
             padding: const EdgeInsets.all(16),
             children: [
               MarcoPixel(child: EscenaPixel(fondo: sala, elementos: personajes, descripcion: 'La sala…')),
               DialogoPixel(hablante: 'Jueza', texto: frase, controlador: dialogo, onContinuar: seguir),
               MenuOpcionesPixel(
                 etiqueta: decision.pregunta,
                 opciones: [for (final o in decision.opciones) o.texto],
                 correctas: {for (final (i, o) in decision.opciones.indexed) if (o.correcta) i},
                 elegida: elegida, // null hasta que se elige
                 onElegir: (i) => setState(() => elegida = i),
               ),
             ],
           ),
         ),
       ]),
     ),
   )
   ```

   `HudPixel` se ordena solo: volver, título y acciones arriba; la barra a todo el ancho debajo, con el contador de cartas. Si al título le quedarían menos de 140 puntos (pantalla estrecha, letra grande), pasa a su propia fila.

5. **Elegir caso**: un `TicketPixel` por caso (el talón crece con la letra; si no cabe al lado, va debajo).

   ```dart
   TicketPixel(
     talon: const Column(mainAxisSize: MainAxisSize.min, children: [Text('TURNO'), RotuloPixel('A-07')]),
     onPressed: () => context.go('/juego/lucia'),
     child: const Text('Caso 1 · Lucía, 11 años'),
   )
   ```

6. **Mis cartas**: en un móvil, una columna de cartas tumbadas (`FormatoCartaPixel.horizontal`; si el texto no cabe, se ponen de pie solas); en pantallas anchas, una rejilla de cartas de pie. El dibujo puede ser un sprite del motor (`arte: SpritePixel(sprite: icono)`).

   ```dart
   CartaPixel(numero: 1, titulo: carta.titulo, texto: carta.texto, formato: FormatoCartaPixel.horizontal, onPressed: abrir)
   CartaPixel(numero: 2, titulo: carta.titulo, texto: carta.texto, bloqueada: true)
   ```

7. **Botones y barras** donde haga falta: `BotonPixel` (primario, secundario y de peligro; con `onPressed` null, desactivado) y `BarraPixel`.

`GaleriaPixelUi` enseña todo junto, con sus estados, sobre papel, sobre el fondo del juego y en una pantalla de juego de ejemplo.

## La letra (y dónde se cambia para lectura fácil)

Pixelify Sans (OFL) en todos los textos del kit, a tamaños cómodos (el cuerpo, 20; nada por debajo de 18) y con mucho interlineado. Se decide en **un solo sitio**: `familiaPixel(context)` en `estilo_pixel.dart`, que lee `TemaPixel`. Con `TemaPixel(lecturaFacil: true, …)` encima, todo el juego pasa a Atkinson Hyperlegible; no hay que tocar nada más. Los nombres de las familias están en `FuentesPixel`. Si Pixelify no está declarada, se ve Atkinson.

Las cifras que llevan información (el contador de cartas, el número de una carta, el turno) van con `RotuloPixel`, una letra propia de 5 × 7 en la rejilla del kit: en Pixelify, a estos tamaños, el «5» es igual que la «S», el «8» que la «B» y el «0» que la «O». Crece con la letra del sistema y no cambia con la lectura fácil (ya se lee bien).

## Reglas

- **Unidad pixel**: `unidadPixel(context)`, 3 puntos en un móvil (2 en pantallas muy estrechas y 4 en tabletas), redondeada a un número entero de píxeles físicos. Bordes, sombras, escalones y márgenes miden unidades enteras. `TemaPixel(unidad: …)` la cambia.
- **Colores**: los de `ColoresUiPixel`, que son los de `PaletaPixel` con el mismo nombre. Contorno y sombra en `noche`; texto con contraste AA o más. La paleta no tiene rojo: el peligro y el fallo son `teja` y siempre llevan icono o texto (el rojo de la app queda para Ayuda).
- **Fondo**: di sobre qué va cada parte con `FondoPixel` (el HUD y las cartas ya lo hacen por dentro). Sobre azul noche, el tema oscuro o el marino, las piezas con contorno azul noche llevan filo (y ocupan una unidad más por cada lado); sobre papel, no.
- **Pulsar**: la pieza baja una unidad al llegar el dedo y se queda abajo al menos 120 ms, también en un toque rápido dentro de una lista con scroll. Vibraciones de `Hapticos`: toque al pulsar, selección al elegir, acierto en la respuesta correcta.
- **Accesibilidad**: zonas táctiles de 48 × 48 como mínimo; Semantics en todo lo que se toca o informa; teclado con anillo de foco amarillo y azul noche (y el foco no se pierde al decidir ni al acabar un diálogo); letra grande sin desbordes (los textos bajan de línea, el título del HUD cambia de fila, el talón crece, las cartas se ponen de pie).
- **Lector de pantalla**: el diálogo es una región en vivo (dice cada frase nueva una vez) y la opción elegida dice el resultado al momento («Tu respuesta: no es correcta. La correcta era: …»); después, las opciones son texto con su resultado, no botones desactivados. Si la app ya lee la frase en voz alta (TTS) con el lector activo (`MediaQuery.accessibleNavigationOf`), pasa `anunciar: false` a `DialogoPixel` y `MenuOpcionesPixel`, o no reproduzcas la voz, para que no se lea dos veces.
- **Movimiento**: nada en bucle. El brillo cruza el dibujo de una carta una vez al aparecer (en ola), al desbloquearse y con el foco o el ratón; el ▼ de «Continuar» parpadea unos 8 s y se queda a la vista; el cursor ► se balancea unos 8 s cada vez que cambia de opción. Con «reducir animaciones», nada se mueve: el texto sale entero, la barra salta y la transición es un fundido.
- **Contenido**: no pongas siempre la respuesta correcta la primera (ni el cursor en ella: `cursorInicial` solo pone el ►, sin resaltar). Espacio duro entre una cifra y su unidad (`11 años`). «N.º» con punto y voladita.

## Nitidez

- Todo se pinta con `pincelPixel` (sin suavizado) y `Clip.hardEdge`, y los dibujos crecen a escala entera.
- Con Skia (la web) eso basta. **Impeller** (Android e iOS) suaviza cualquier borde que no caiga justo en un píxel físico, así que cada pieza se pinta con su origen ajustado a la rejilla de la pantalla (`AjustePixel`: la mueve menos de medio píxel físico al pintarla, sin cambiar su sitio).
- El ajuste se calcula al pintar. Si lo que se mueve es una capa de más arriba que no se vuelve a pintar, se queda el ajuste de antes. Por eso **las listas del juego llevan `addRepaintBoundaries: false`** (o son un `SingleChildScrollView`). Las transiciones de Material que deslizan la página pueden dejar una pieza quieta medio píxel fuera hasta que se vuelva a pintar; la de `paginaPixel` no mueve la página.
- El texto lleva el suavizado normal de la letra: Pixelify no cae en la rejilla a ningún tamaño (su avance no es un número entero de sus píxeles).
- Para comprobarlo con Impeller: `flutter test --enable-impeller test/pixel/ui`.

## Comprobar

- `flutter analyze lib/pixel/ui test/pixel/ui` y `flutter test test/pixel/ui` (también con `--enable-impeller`).
- Capturas a tamaño de móvil (galería en tema claro, oscuro, letra grande, lectura fácil y densidad 2,625; HUD con Glosario y Ayuda a 390 y a 360 con letra 1,3; hoja de estados; fotogramas de la transición): `CAPTURAS=build/capturas flutter test test/pixel/ui/capturas_test.dart` (deja los PNG en `build/capturas/pixel_ui`).
