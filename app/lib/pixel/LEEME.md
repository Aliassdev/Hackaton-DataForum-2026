# Pixel art de «Vive el caso»: guía de estilo

Dentro de «Vive el caso», los personajes y los lugares son pixel art, como en un juego retro (Stardew Valley, Undertale): con encanto, cálido, fácil de leer y nunca inquietante. Todo se dibuja con código, sin imágenes: cada sprite son filas de texto, un carácter por píxel. El motor está en `lib/pixel/motor/` (`import '../motor/motor.dart';`).

## En un minuto

```dart
// Una vez, en una variable final de nivel superior (nunca dentro de un build).
final maceta = Sprite('maceta', [
  '..NNNN..',
  '.NvvvVN.',
  '.NmmmtN.',
  '..NNNN..',
]);

SpritePixel(sprite: jueza, alto: 120, etiqueta: 'La jueza'); // un sprite suelto
EscenaPixel(fondo: sala, elementos: [...], alPulsar: (id) {}); // un lugar con personajes
```

- `.` es transparente; el resto de caracteres son las claves de la paleta (abajo).
- En debug, un sprite mal dibujado (una fila más corta, una clave que no existe, un fotograma de otro tamaño) lanza `SpriteInvalido` y dice el fotograma, la fila y la columna. En release no se comprueba nada.
- Se ve nítido solo: el motor escala con un número entero de píxeles de pantalla por píxel del dibujo y sin suavizado. No hace falta pensar en tamaños de pantalla.
- Después de cambiar un dibujo, reinicia la app (hot restart, `R`): con hot reload, una variable `final` de nivel superior que ya se ha usado no se vuelve a calcular.

## La rejilla

| Qué | Tamaño (ancho × alto) | Notas |
| --- | --- | --- |
| Chicos y chicas | 24 × 32 | Cabeza grande (unas 15 filas), cuerpo de unas 16. |
| Personas adultas | 24 × 36 o 32 × 40 | Más altas que los chicos; cabeza algo más pequeña. |
| Objetos | múltiplos de 8 (8 × 8, 16 × 16, 16 × 24) | Un banco, una mesa, una planta. |
| Fondos | 160 × 96 | El suelo empieza hacia la fila 60. |

- Los pies van abajo: la última fila del personaje es su sombra en el suelo (`x`), y la de encima, las suelas.
- El ancla (el punto que se coloca en la escena) es, por defecto, el centro del borde de abajo: los pies. Se cambia con `ancla: (x: 5, y: 9)` (por ejemplo, la punta de un bocadillo).
- En un móvil de 1080 píxeles, un fondo de 160 sale a 6 píxeles de pantalla por píxel del dibujo (unos 2,2 puntos): un detalle de 1 píxel se ve, pero no hay sitio para letras. **Nunca hay texto dentro del dibujo**: los títulos y los diálogos van fuera, con las letras del tema.

## La paleta

Una sola paleta para todo, sacada de la marca. En el código, `PaletaPixel.amarillo`, `PaletaPixel.piel3`… (con `.clave` y `.color`); en las filas, la clave. La columna «sombra» es el tono con el que se sombrea cada color.

| Clave | Color | Sombra | Uso |
| --- | --- | --- | --- |
| `N` | noche (azul noche) | | El contorno de todo, los ojos y las líneas de dentro. |
| `D` | marino | `N` | Sombra del azul; togas, uniformes. |
| `A` | azul (el eléctrico de la marca) | `D` | Ropa, bancos, carpetas. |
| `a` | azul claro | `A` | Brillo del azul. |
| `c` | cielo | `a` | Cielo, cristales. |
| `h` | hielo | `c` | Paredes claras, brillos. |
| `o` | ocre | `t` | Sombra del amarillo y del pelo rubio; corcho. |
| `Y` | amarillo (el de la marca) | `o` | Ropa, detalles; el halo de resaltar. |
| `y` | amarillo luz | `Y` | Luces, lámparas, zócalos. |
| `W` | blanco | `h` | El brillo de los ojos, papeles. |
| `P` | papel (el de la app) | `p` | Paredes, papeles. |
| `p` | crema | `o` | Papel en sombra. |
| `g` | gris claro | `G` | Metal, suelos. |
| `G` | gris | `K` | |
| `K` | gris oscuro | `N` | Ropa neutra, patas de muebles. |
| `1`…`6` | pieles, de la más clara a la más oscura | la siguiente | `3` se sombrea con `4`. |
| `7` | sombra de la piel 6 | | Solo para eso. |
| `b` | pelo canoso | `G` | |
| `u` | pelo rubio | `o` | |
| `f` | pelo pelirrojo | `R` | |
| `t` | pelo castaño claro | `T` | También, la sombra de la madera. |
| `T` | pelo castaño | `z` | |
| `z` | pelo negro | `N` | |
| `r` | coral | `R` | Ropa. Nunca sangre ni heridas. |
| `R` | teja | `z` | Bocas, ladrillos, libros. |
| `v` | verde | `V` | Plantas, ropa. |
| `V` | verde oscuro | `N` | |
| `L` | lila | `D` | Ropa, cojines. |
| `s` | rosa | `L` | Mejillas, ropa. |
| `m` | madera | `t` | Muebles y suelos. |
| `x` | sombra en el suelo (semitransparente) | | Bajo los pies; oscurece cualquier suelo. |

Las claves que se confunden al leer (`l`, `I`, `O`, `0`) no existen. Para el brillo del pelo, el tono más claro que le vaya: `m` en el castaño claro, `y` en el rubio, `K` en el negro.

## Cómo se dibuja

- **Contorno de 1 píxel en azul noche** (`N`) alrededor de toda la silueta de personajes y objetos: nunca negro, nunca de 2 píxeles. Por dentro, las líneas también en `N` (o en la sombra del color).
- **Luz de arriba a la izquierda**: el brillo, arriba a la izquierda (el pelo, el hombro); la sombra, abajo y a la derecha, con el tono de la columna «sombra». La sombra en el suelo (`x`) va justo debajo de los pies.
- **Los fondos se leen menos que los personajes**: paredes y suelos sin contorno y con poco contraste; el contorno, solo en los objetos importantes (ventanas, muebles). Así los personajes destacan.
- **Solo colores de la paleta**, sin degradados ni antialiasing a mano. Sin píxeles sueltos que no formen nada.
- **Caras**: ojos de 2 × 2 en `N` con el brillo `W` arriba a la izquierda, mejillas `s` y boca de 2 píxeles en `R` (mira el chico de `test/pixel/motor/muestras.dart`). Expresiones tranquilas y amables.
- **Diversidad**: tonos de piel y pelo variados, cuerpos y edades distintas, gafas, pañuelos, sillas de ruedas… Las variantes de un mismo personaje se hacen con `recolorear` y `PaletaPixel.cambio`, que cambia un color y su sombra a la vez:

  ```dart
  final amiga = chica.recolorear({
    ...PaletaPixel.cambio(PaletaPixel.piel3, PaletaPixel.piel6),
    ...PaletaPixel.cambio(PaletaPixel.castanoClaro, PaletaPixel.negro),
    'm': 'K', // el brillo del pelo
  }, nombre: 'amiga');
  ```

### Temas delicados

- Nada de violencia, heridas, sangre, armas ni esposas. El coral es ropa, no otra cosa.
- Los agresores no aparecen. La persona investigada, si sale, es una figura neutra: ropa gris, cara tranquila, sin rasgos de enfado ni de miedo.
- Nadie llora ni da miedo: los personajes están serenos, escuchan o sonríen un poco.

## Fotogramas y animaciones en reposo

Dos o tres fotogramas como mucho: respirar, parpadear, flotar. Con «reducir animaciones», el sprite se queda en el primer paso de su animación (la pose de descanso). El reloj solo repinta cuando cambia algo, así que no gasta batería ni bloquea `pumpAndSettle` en las pruebas.

```dart
const quieto = [ /* 32 filas */ ];
final respira = ['........................', ...quieto.sublist(0, 18), ...quieto.sublist(19)]; // la cabeza baja 1 píxel
final parpadea = retocar(quieto, {9: '...NtT333333333334TTN...'}); // los ojos, una raya

final chico = Sprite.animado('chico', [quieto, respira, parpadea], animacion: AnimacionPixel.reposo());
```

- `AnimacionPixel.reposo()`: respira y, cada tres respiraciones, parpadea (fotogramas 0, 1 y 2).
- `AnimacionPixel.parpadeo()`, `AnimacionPixel.respiracion()`: solo una de las dos cosas.
- `AnimacionPixel.balanceo()`: el dibujo sube un píxel y baja, sin dibujar otro fotograma (bocadillos, objetos que flotan).
- O a mano: `AnimacionPixel([PasoPixel(0, ms: 900), PasoPixel(1, ms: 120, dy: -1)])`.
- `retocar(base, {fila: 'nueva fila'})` copia un fotograma cambiando solo unas filas.

En una escena, cada personaje va desfasado: no parpadean todos a la vez.

## Escenas

```dart
EscenaPixel(
  fondo: sala, // 160 × 96
  descripcion: 'La sala de espera del juzgado', // para los lectores de pantalla
  alPulsar: (id) => abrirDialogo(id),
  elementos: [
    ElementoEscena(sprite: jueza, x: 40, y: 88, id: 'jueza', etiqueta: 'La jueza. Toca para hablar con ella'),
    ElementoEscena(sprite: chico, x: 84, y: 93, id: 'tu', etiqueta: 'Tú', resaltado: true),
    ElementoEscena(sprite: mesa, x: 40, y: 92), // delante de la jueza: va después
  ],
)
```

- `x` e `y` son píxeles del fondo, donde va el ancla (los pies). Se pintan en el orden de la lista: el último queda delante. Pon detrás los que están más arriba (y menor).
- Los elementos con `id` se pueden tocar: su zona es su sprite (48 × 48 puntos como mínimo) y los lectores de pantalla los leen como botones con su `etiqueta`.
- `espejo: true` da la vuelta al sprite (que se miren entre ellos). `resaltado: true` le pone un halo amarillo para señalar a quién tocar.
- La escena se escala entera, centrada; lo que sobra alrededor es del color del papel (o `colorMarco`, por ejemplo azul noche en el tema oscuro). En una columna ocupa todo el ancho.
- Para pintar fondos grandes sin escribir 96 filas a mano, `LienzoPixel`: `rect`, `marco`, `lineaH`, `lineaV`, `linea`, `pegar` (un dibujo pequeño; sus `.` no tapan) y `mosaico` (una tesela repetida). Mira `_pintarSala` en `test/pixel/motor/muestras.dart`.

## Comprobar

- `flutter analyze lib/pixel test/pixel` y `flutter test test/pixel`.
- Capturas a tamaño de móvil: `CAPTURAS=build/capturas flutter test test/pixel/motor/capturas_test.dart` (deja los PNG en `build/capturas`). Míralas antes de dar un dibujo por bueno.
