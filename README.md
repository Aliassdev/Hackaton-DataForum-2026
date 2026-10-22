# TuTurno · ¡Es tu turno!

App para chicos y chicas de **11 a 17 años** que pasan por un proceso judicial: como víctimas, testigos, personas investigadas o menores a los que el juez escucha en un proceso de familia. Les explica el proceso y sus derechos con un juego en pixel art, lecciones cortas y un agente de voz. Proyecto del **DATAthon DATAfórum Justicia 2026**, reto 2, «Infancia y juventud».

> Es un prototipo. No sustituye a un abogado ni a ningún profesional, y no da consejo legal personal. El contenido jurídico de ejemplo está pendiente de revisión por juristas.

En la sala, cuando el juez te da la palabra, es tu turno. TuTurno quiere que, cuando llegue ese momento, sepas qué va a pasar, quién estará y qué puedes pedir.

---

## Los tres casos oficiales del reto

| Caso | Edad | Situación | Lo que aprende quien juega |
|---|---|---|---|
| **Lucía** | 11 | Declara en una Sala Gesell | Prueba preconstituida, no ver a la persona investigada, ir con alguien de confianza |
| **Sergio** | 13 | Acoso escolar | Fiscalía de Menores, orden de alejamiento, protocolo del instituto, conciliación solo si él quiere |
| **Sara** | casi 16 | Difusión de imágenes íntimas | No guardar ni reenviar, Canal prioritario de la AEPD (por internet, sola desde los 14), puede denunciar ella misma |

---

## Qué hace la app

### Vive el caso: el juego
- Los tres casos se juegan enteros en **pixel art**, con escenas, decisiones, explicaciones y un final.
- Cada derecho que descubres es una **carta de derecho** para tu colección.
- **El juzgado por dentro**: una sala de vistas, y otra de menores, en la que tocas a cada persona (jueza, fiscal, abogadas, Letrado de la Administración de Justicia, equipo técnico…) para saber quién es y qué hace.
- Fiel a la justicia española: toga con puñetas, estrado, balanza y sello, y nada de mazos ni de jurado en los casos de menores.

### Aprende: lecciones cortas
- Siete unidades (U1–U7), entre ellas «Quién es quién en el juzgado», «Si eres víctima o testigo: tus derechos», «Tu imagen es tuya», «Si te investigan (14–17 años)» y «Cuando el juez te escucha en familia».
- Cinco tipos de ejercicio: elegir, verdadero o falso, ordenar, emparejar y **«Dilo con tus palabras»**, que corrige qué ideas clave has explicado.
- **Aprendizaje adaptativo (BKT)**: repasa lo que menos dominas. XP y una **racha amable**, sin castigos y con días de descanso.
- Cada explicación enseña **de dónde sale**: la norma y el artículo.

### Pregunta: el agente de voz
- Hablas o escribes. **Tu voz se transcribe en tu propio móvil** y al agente solo le llega el texto. El agente contesta con voz (ElevenLabs) y por escrito.
- Antes de hablar puedes decir tu edad, el tipo de proceso, tu papel y el momento (antes, durante o después). Se puede saltar.
- Cada respuesta se apoya en artículos de ley que se buscan en ese momento, con enlace al BOE.
- Si algo suena a riesgo, sale arriba la **tarjeta de Ayuda** con ANAR y el 112. Si alguien empieza a contar lo que le pasó, se le explica con cariño que eso es mejor contárselo a los profesionales de su caso.
- Si la voz falla, la app sigue **por escrito con el mismo backend**. Si tampoco hay conexión, enseña respuestas de ejemplo bien marcadas.

### Mi situación
- Tu guía paso a paso según tu papel (víctima, testigo, investigado o escuchado en familia): qué pasa antes, durante y después, quién estará y qué puedes pedir.
- **Mis preguntas**: apunta lo que quieres preguntar a tu abogado.

### Ayuda y Glosario
- **Ayuda**, siempre arriba a la derecha: ANAR (900 20 20 10 y 116 111), emergencias (112), 017 de INCIBE (con su horario de abierto o cerrado), 016 y el Canal prioritario de la AEPD.
- **Salir rápido**: oculta la app al instante con una pantalla neutra.
- **Glosario** de 42 términos, cada uno con su definición, un ejemplo de los casos y su fuente.

### Accesibilidad e identidad
- **Lectura fácil** (todo en Atkinson Hyperlegible), **reducir animaciones**, texto grande, contraste AA, zonas táctiles de 48 px, Semantics y lectura en voz alta.
- Identidad propia: logotipo con la letra MaryKate, monograma TuT, amarillo `#FFDE59` y azul `#2643E0`, la mascota Tut y la metáfora del **ticket de turno**.

---

## Cómo funciona por dentro

```
 App Flutter (Android y web)
   │  texto (la voz se transcribe en el móvil)
   ├──────────────► ElevenLabs Agents (WebSocket, URL firmada) ──► voz del agente
   │                         │  Custom LLM (SSE)
   │                         ▼
   ├──────────────► Backend FastAPI en Hugging Face Spaces
   │  modo texto        1. Guardrail (reglas de crisis; clasificador BETO si está entrenado)
   │  y «Dilo»          2. Datos personales fuera
   │                    3. Reformulación jurídica + RAG híbrido (BM25 + multilingual-e5)
   │                    4. Generación adaptada a la edad (gpt-oss-120b)
   │                    5. Verificación frase a frase
   │                         │
   │                         ▼
   │                  Router de inferencia de Hugging Face (con respaldo)
   ▼
 Contenido validado en el móvil (casos, lecciones, glosario, itinerarios)
```

### El agente, paso a paso
1. **Guardrail**: si el mensaje es una crisis, contesta al momento con una plantilla fija (ANAR y 112), sin llamar al modelo.
2. **Datos personales fuera**: nombres, teléfonos y direcciones se quitan antes de enviar nada a una API externa.
3. **Búsqueda**: un modelo rápido traduce la duda a términos jurídicos («ver la cara del que me pegó» → «evitar la confrontación visual del testigo menor con el investigado»). Después se busca a la vez por palabras y por significado, dando más peso a unas normas u otras según el perfil (por ejemplo, la LO 5/2000 si eres investigado).
4. **Respuesta**: el modelo solo puede usar los 6 fragmentos recuperados y adapta el lenguaje a la edad (11–13, 14–15, 16–17). Si la respuesta no está en esos fragmentos, lo dice y te indica a quién preguntar.
5. **Verificación antes de hablar**: quita preguntas sobre los hechos, promesas de secreto, predicciones, duraciones de medidas y citas inventadas.

En la voz, el agente empieza con una frase puente («Vale, te lo explico.») mientras se prepara la respuesta, así que no hay silencios.

### Las fuentes
El agente responde con **12 normas**, leídas de los textos consolidados oficiales:

- Convención sobre los Derechos del Niño
- LO 1/1996, de Protección Jurídica del Menor
- LO 8/2021 (LOPIVI)
- LO 5/2000, de responsabilidad penal de los menores
- Ley de Enjuiciamiento Criminal
- Ley de Enjuiciamiento Civil
- LO 1/1982 (honor, intimidad y propia imagen)
- LO 3/2018 (LOPDGDD)
- Código Penal
- RGPD
- Estatuto de la víctima del delito (Ley 4/2015)
- Ley 1/1996 de asistencia jurídica gratuita

Usa también el **glosario validado de la app** y las **92 citas literales** de [`docs/MARCO_LEGAL.md`](docs/MARCO_LEGAL.md), comprobadas en el BOE. El contenido de la app (casos, lecciones e itinerarios) solo se muestra si tiene `"validado": true` y fuente.

### Límites que el agente nunca cruza
- Habla del **proceso**, nunca de los **hechos**, y nunca pregunta qué pasó, para no contaminar el testimonio.
- No da consejo legal personal ni predice resultados.
- No promete confidencialidad absoluta.
- Deriva a ANAR o al 112 cuando detecta riesgo.

---

## Privacidad y seguridad
- **Sin cuentas ni datos personales.** El progreso, la racha y el perfil se guardan solo en el móvil.
- La app **no guarda el chat**, y el backend **no escribe en sus logs** lo que escriben los usuarios.
- La voz se transcribe en el dispositivo y al agente solo le llega el texto.
- Las claves (ElevenLabs y el LLM) solo están en el backend, nunca en la app ni en git.
- El agente de voz no tiene un LLM de respaldo propio: si el backend no contesta, no responde nadie sin filtros.
- **Salir rápido** y **Borrar todo** en la app.

---

## Calidad medida (22/10/2026)

| Qué | Resultado |
|---|---|
| Voz: primer audio desde que se envía la pregunta | p50 0,44 s (frase puente) |
| Voz: audio de la respuesta | p50 1,13 s |
| Modo texto | p50 unos 0,8 s |
| 30 preguntas a la vez (CPU básica de Hugging Face) | 0 fallos en más de 350 peticiones |
| Pruebas adversariales (35 mensajes de chicos y chicas, con faltas y abreviaturas) | Crisis detectadas: 10 de 10 (antes de los arreglos, 3) |
| Batería de 89 formas de expresar una crisis | 88 detectadas, 0 falsos positivos en 320 mensajes de referencia |
| Búsqueda en las leyes, 13 preguntas típicas de la demo | El artículo correcto sale entre los 5 primeros en el 92 % |
| Tests automáticos | App: 1511 (Flutter) · Backend: 439 (pytest) |

---

## Estructura del repositorio

```
app/        App Flutter (Android y web): lib/, test/, assets/ (fuentes, marca, contenido de ejemplo)
backend/    API FastAPI: Custom LLM de la voz, modo texto, evaluador de «Dilo», sesiones y límites
ml/         Ingesta de las leyes, índice del RAG, evaluaciones y entrenamiento del guardrail
content/    Leyes registradas, pesos por perfil, plantillas de seguridad, glosario, evaluador y evaluaciones
fuentes/    Textos oficiales de las leyes (PDF del BOE, EUR-Lex y ONU)
docs/       ARQUITECTURA.md (diseño completo) y MARCO_LEGAL.md (base legal comprobada)
scripts/    Sincronización del contenido
Dockerfile  Imagen del backend para Hugging Face Spaces
```

---

## Puesta en marcha

### App (desde `app/`)
```bash
flutter pub get
cp env/dev.example.json env/dev.json       # rellena API_URL o AGENT_ID (no se sube a git)
flutter run --dart-define-from-file=env/dev.json          # en un Android conectado
flutter run -d chrome --dart-define=USE_MOCK=true         # web, sin backend
flutter build web --release
flutter analyze && flutter test
```
Con `API_URL` apuntando al backend, la voz pide una URL firmada y el modo texto y «Dilo» usan el backend real. Más detalle en [`app/CLAUDE.md`](app/CLAUDE.md).

### Backend en local (desde la raíz)
```bash
python -m venv backend/.venv
backend/.venv/bin/pip install torch --index-url https://download.pytorch.org/whl/cpu
backend/.venv/bin/pip install -r backend/requirements.txt -c backend/constraints.txt
cp backend/.env.example backend/.env       # claves: nunca en git
backend/.venv/bin/python -X utf8 ml/ingest_leyes.py && backend/.venv/bin/python -X utf8 ml/build_index.py
cd backend && .venv/bin/python -m uvicorn app.main:app --port 8000
cd backend && .venv/bin/python -m pytest -q
```

### Despliegue
- **Backend**: un Space Docker de Hugging Face (`backend/scripts/desplegar_hf.py`). Guía completa en [`backend/DESPLIEGUE.md`](backend/DESPLIEGUE.md).
- **Agente de ElevenLabs**: `backend/scripts/setup_agent.py` (Custom LLM apuntando al Space) y `backend/scripts/proteger_agente.py` (agente privado, límites y retención).
- **Contrato de la API**: [`backend/API.md`](backend/API.md), resumen de la sección 8 de `docs/ARQUITECTURA.md`.

---

## Documentación
- [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md): experiencia de usuario, arquitectura, contratos de la API, esquemas de contenido, IA y calendario.
- [`docs/MARCO_LEGAL.md`](docs/MARCO_LEGAL.md): base legal con citas literales comprobadas en el BOE.
- [`backend/API.md`](backend/API.md) y [`backend/DESPLIEGUE.md`](backend/DESPLIEGUE.md): API y despliegue del backend.
- [`app/CLAUDE.md`](app/CLAUDE.md): estructura de la app, rutas, tipografía y reglas.

---

## Estado y próximos pasos
En desarrollo para la demo:
- Mi situación más personalizada: perfil ampliado, tu camino según tu edad y tu papel, y tu día con cuenta atrás.
- Guardado **opcional** de las conversaciones, solo en el móvil, cifradas y borradas solas a los 7 días.
- Más contexto en las conversaciones de voz: entender los «sí» y «cuéntame más», y conservar el hilo si se reconecta.
- Distribución con un QR: APK para Android y versión web para iPhone y para quien no quiera instalar.

---

## Equipo
- **Jorge Alias Alvarez**: app Flutter, experiencia, identidad y contenido.
- **Iker Argüelles Eduarte**: backend, agente de voz e IA (guardrail, RAG y evaluaciones).

## Créditos y licencias
- Letra **MaryKate**, de Sakura Hatsuki (fluffybanana101), con licencia freeware. La versión del repo está ampliada con las letras del español; ver `app/assets/fonts/MaryKate-CREDITOS.txt`.
- **Nunito**, **Pixelify Sans** y **Atkinson Hyperlegible**: SIL Open Font License.
- Leyes: textos consolidados del BOE, RGPD de EUR-Lex y Convención sobre los Derechos del Niño de la ONU.
