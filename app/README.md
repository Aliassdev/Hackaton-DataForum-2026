# TuTurno · app Flutter

App para chicos y chicas de 11 a 17 años que pasan por un proceso judicial: «Vive el caso», «Aprende» y «Pregunta». Las reglas de trabajo están en `CLAUDE.md` (aquí y en la raíz) y la arquitectura, en `docs/ARQUITECTURA.md`.

Antes de cualquier comando de `flutter`, carga el entorno y entra en `app/`:

```bash
. ~/development/tuturno-env.sh
cd app
```

## Configuración (`env/`)

La app lee cuatro valores al compilar (`--dart-define-from-file`):

| Clave | Para qué |
|---|---|
| `USE_MOCK` | `true`: respuestas simuladas, sin backend |
| `API_URL` | El backend. Da la URL firmada del agente de voz y responde a Pregunta en modo texto |
| `AGENT_ID` | El agente público de ElevenLabs. Con `API_URL` no hace falta: déjalo vacío |
| `DEMO` | `true`: borradores, atajo de «Dilo» y comprobaciones de la demo |

- `env/dev.example.json`: plantilla para desarrollar (con mock).
- `env/release.example.json`: la release, contra el backend desplegado en Hugging Face. No lleva claves: las API keys solo van en el backend.
- Las copias locales (`env/dev.json`, `env/release.json`) no se suben (`.gitignore`). Nunca subas un `AGENT_ID` ni una clave.

## Desarrollar

```bash
flutter run --dart-define=USE_MOCK=true                       # sin backend
flutter run --dart-define-from-file=env/dev.json              # tu copia local de dev.example.json
flutter analyze && flutter test
```

## Compilar la release

### APK de Android (la que instala el QR)

```bash
flutter build apk --release --dart-define-from-file=env/release.example.json
```

- Sale en `build/app/outputs/flutter-apk/app-release.apk`, universal (vale para todos los móviles). Se instala desde el archivo (hay que permitir «instalar apps desconocidas»).
- La release es `io.github.aliassdev.tuturno`, firmada con la clave de release (más abajo). Debug y profile siguen siendo `com.example.tuturno`, así que las dos conviven en el mismo móvil.
- Pregunta habla con el agente de voz: el backend da la URL firmada de cada sesión.
- Usa siempre la release para enseñar la app: en debug, las animaciones van a tirones.
- `android/app/proguard-rules.pro` lleva las reglas de R8 que necesita `shared_preferences_android` 2.5.1. Sin ellas, la release no arranca.

### Firma de la release

- La release se firma con la clave de TuTurno si existe `android/key.properties` (no se sube: está en `android/.gitignore`):
  ```properties
  storeFile=/ruta/a/tuturno-release.jks
  storePassword=…
  keyAlias=tuturno
  keyPassword=…
  ```
  Puede ser un enlace al `key.properties` que está junto al almacén de claves, fuera del repositorio (por ejemplo, en `~/development/tuturno-release/`).
- Sin `android/key.properties`, la release se firma con la clave de depuración de tu ordenador y Gradle lo avisa. Sirve para probar, pero esa APK no se puede publicar ni instalar encima de la publicada.
- Todas las versiones publicadas tienen que ir firmadas con la misma clave. Si se pierde, la app ya instalada no se podrá actualizar: guarda una copia del `.jks` y de sus contraseñas en un sitio seguro, nunca en git.
- Para comprobar la firma: `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`. El certificado de TuTurno tiene el SHA-256 `8ce8411cbee2cc60ffdc2efacee7c487eea1ee1abbd7ba214dad96279205161c`.

### APK del móvil del escenario (la del jurado)

La misma, con `DEMO` encendido. Un `--dart-define` gana a la clave del archivo:

```bash
flutter build apk --release --dart-define-from-file=env/release.example.json --dart-define=DEMO=true
```

Sin `DEMO`, «Ver borradores» no hace nada («El juzgado por dentro» sale «en revisión») y el atajo de «Dilo» no empieza en «Dilo» (y la lección puede salir cerrada). «Comprobar antes de salir» lo marca en rojo.

### Web (iPhone y ordenador)

```bash
flutter build web --release --base-href /Hackaton-DataForum-2026/app/ --dart-define-from-file=env/release.example.json --no-web-resources-cdn
```

- Se publica en GitHub Pages, en `https://aliassdev.github.io/Hackaton-DataForum-2026/app/` (por eso el `--base-href`). Con `--no-web-resources-cdn`, CanvasKit sale de nuestra web y no del CDN de Google.
- En la web, Pregunta va en modo texto contra el backend (`POST /api/agent/ask`), sin el agente de voz.
- La dirección del backend también se puede cambiar sin recompilar: `api_url` de `build/web/config.json` (junto a `index.html`) gana a `API_URL`. Vacío, se usa `API_URL`.
- El backend permite CORS desde `https://aliassdev.github.io`.

## Modo demo (Ajustes → «Para el equipo»)

En Ajustes, mantén pulsado el pie («Todo esto se guarda en tu móvil, sin cuentas.»). Aparece «Para el equipo (demo)», que el jurado no ve (se esconde al volver a entrar):

- **Preparar demo**: borra lo de este móvil, carga el progreso de ejemplo (340 XP, racha de 4 días, 2 lecciones y 2 cartas), salta la bienvenida, enciende los borradores y, si quieres, guarda el ticket de Sergio. Con su ticket va también su «Tu ticket» de Mi situación: irá con su familia, le preocupan el instituto y las preguntas, lo prefiere paso a paso y su cita es hoy a las 12:30. Así, el atajo de Mi situación enseña la guía hecha a su medida, con el modo día. Púlsalo antes de cada ensayo: cada ronda empieza igual.
- **Empezar de cero**: lo mismo, sin progreso ni ticket y con la bienvenida.
- **Ver borradores** y **Usar siempre el ejemplo en Pregunta** (si la red del recinto falla).
- **Atajos del guion**: Lucía en la escena 5 y en la 9, Sergio, Sara, Pregunta con el perfil de Sergio, Mi situación de víctima, «Dilo» de la Sala Gesell y «El juzgado por dentro». Se abren encima del inicio.
- **Comprobar antes de salir**: red, servidor (4 s), voz de Pregunta (abre y cierra en menos de 6 s), micrófono, voz en español, DEMO y el horario del 017. Solo avisa: no bloquea nada.
- **Servidor (API_URL)**: otra dirección sin recompilar (por ejemplo, un túnel), «Probar la conexión» y «Volver al de serie».
