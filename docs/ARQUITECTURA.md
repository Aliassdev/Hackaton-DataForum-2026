# TuTurno · Arquitectura del proyecto

> **DATAthon DATAfórum Justicia 2026** · Reto de infancia y juventud
> Versión 1.0 · miércoles 21/10/2026 · Equipo técnico: **A** (app) y **B** (IA y datos)

---

## 0. Cómo usar este documento

- Léelo entero una vez (unos 20 minutos). Después úsalo como referencia diaria: contratos de la API (sección 8), esquemas de contenido (9), reparto (17), ramas (18) y calendario (19).
- Si cambia una decisión, se cambia **primero aquí** y después en el código.
- La sección 23 es la plantilla de `CLAUDE.md`. Copiadla a la raíz del repo para que Claude Code genere código coherente en los dos lados.
- Convención: **A** = persona de la app Flutter. **B** = persona de backend, IA y datos. Decidid quién es quién según quién domine más Flutter.

---

## 1. Resumen en 30 segundos

TuTurno es una app para chicos y chicas de **12 a 18 años** que les ayuda a **entender** sus derechos ante la justicia, a **prepararse** si les toca participar en un proceso y a **preguntar** sus dudas por voz. Funciona en web (se abre con un QR, sin instalar nada) y en Android.

| Módulo | Pilar | Qué hace | Dónde está la IA |
|---|---|---|---|
| **Vive el caso** | Acceder | Juego de rol: recorres un caso como testigo, tomas decisiones y desbloqueas derechos | El caso se construye con la estructura de sentencias reales; un clasificador elige casos aptos para 12–18 |
| **Aprende** | Comprender | Lecciones cortas tipo Duolingo, con puntos, racha y repaso | Ejercicios generados y validados; evaluador de comprensión (NLI); aprendizaje adaptativo (BKT) |
| **Pregunta** | Comprender y participar | Agente de voz que responde con fuentes; modo «Mi situación» para quien está en un proceso | RAG híbrido sobre conocimiento validado y sentencias; capa de seguridad; LLM |

Siempre visibles en toda la app: **botón de Ayuda** (ANAR, 112…) y **Glosario**.

**Frase del pitch:** «El derecho a ser oído empieza por entender.»

---

## 2. Problema y base legal

Los menores apenas tienen herramientas para entender y ejercer sus derechos ante la justicia, aunque la ley ya exige que la información se les dé de forma comprensible y adaptada. TuTurno convierte esas obligaciones en una herramienta.

| Norma | Qué dice (resumen) | Dónde lo cumple TuTurno |
|---|---|---|
| Convención sobre los Derechos del Niño (CDN), art. 12 | Derecho a ser escuchado en los procedimientos que le afectan | Pregunta, Mi situación |
| CDN, art. 42 | Los Estados deben dar a conocer la Convención también a los niños | Aprende |
| LO 1/1996 de Protección Jurídica del Menor (LOPJM), art. 9 | Información en lenguaje comprensible y formatos accesibles; madurez presumida a los 12 años | Todo el contenido y la voz |
| LOPJM, art. 10.2 | El menor puede avisar al Ministerio Fiscal y quejarse al Defensor del Pueblo | Aprende (unidad 1), Ayuda |
| LO 8/2021 (LOPIVI), arts. 17 y 18 | Canales para que los menores comuniquen la violencia; información en formatos accesibles | Botón de Ayuda, contenido |
| LOPIVI, art. 14 | Asistencia jurídica gratuita con designación urgente | Aprende, Mi situación (víctima) |
| Ley 4/2015 (Estatuto de la víctima), arts. 4, 5 y 7 | Derecho a entender y ser entendida; información desde el primer contacto y sobre la causa | Mi situación (víctima) |
| LECrim, art. 520.2 bis | La información de derechos del detenido se adapta a su edad y madurez | Mi situación (investigado) |
| LO 3/1981 del Defensor del Pueblo, art. 10.1 | Ser menor no impide presentar una queja | Aprende (unidad 1) |
| Directrices del Consejo de Europa sobre justicia adaptada a los niños (2010) | Información, participación y trato adaptados | Marco general y feedback |

> Comprobad en el BOE la redacción exacta de cada artículo antes de ponerlo en diapositivas.

---

## 3. Alcance del MVP

### 3.1 Entra (imprescindible para la demo)
- Inicio con los tres módulos, botón de Ayuda y Glosario.
- **Vive el caso**: 1 caso completo (testigo), 10–12 escenas, 5 decisiones.
- **Aprende**: 2 unidades × 3 lecciones × 6 ejercicios, con 4 tipos de ejercicio más «Dilo con tus palabras».
- **Pregunta**: voz a texto, respuesta con fuentes y voz; modo «Mi situación» con 3 itinerarios (testigo, víctima, investigado).
- Backend con el agente (seguridad + RAG + LLM) y el evaluador de comprensión.
- Clasificador de sentencias con métricas y estadísticas del corpus para el pitch.
- Despliegue web con QR y modo demo.

### 3.2 No entra (decidido)
- Pregunta de edad y minijuegos para menores de 12.
- Cuentas de usuario, portal para profesionales, conexión con juzgados.
- Guardar conversaciones, detectar abusos o analizar emociones.

### 3.3 Si sobra tiempo (en este orden)
1. Cuestionario de feedback y dashboard con datos simulados (sección 10.9).
2. Respuestas en streaming.
3. Segundo caso del juego (víctima).
4. Itinerario de familia (padres que se separan).

### 3.4 Sin pregunta de edad, ¿cómo se adapta?
Todo el contenido se escribe para 12–18 con lenguaje sencillo. Cuando la respuesta depende de la edad (por ejemplo, la responsabilidad penal: menos de 14, de 14 a 17, 18 o más), el agente explica las opciones. Solo pregunta la edad dentro de la conversación si es imprescindible.

---

## 4. Experiencia de usuario

### 4.1 Inicio
- Como máximo dos pantallas de bienvenida: «Qué es TuTurno» y «Soy una IA. No guardo tus conversaciones. Si estás en peligro, pulsa Ayuda».
- Tres tarjetas grandes: **Vive el caso**, **Aprende**, **Pregunta**.
- Arriba a la derecha, en todas las pantallas: **Ayuda** y **Glosario**.

### 4.2 Vive el caso (juego)
- Protagonista: Lucía, 15 años, testigo de una agresión a un compañero a la salida del instituto. El caso es ficticio, pero sigue la estructura de sentencias reales del corpus.
- Cada escena tiene un lugar (comisaría, citación, sala de espera, sala de vistas, después), personajes, una narración leída en voz alta y, a veces, una decisión.
- Cada decisión da feedback inmediato con su fuente legal y desbloquea una **carta de derecho**.
- Al final: resumen de cartas desbloqueadas y enlace a las lecciones relacionadas.
- Nada de violencia explícita ni detalles de los hechos: el juego trata del proceso.

### 4.3 Aprende (formación)
- Mapa de unidades con lecciones en orden. Cada lección son 6 ejercicios.
- Tipos de ejercicio: elección múltiple, verdadero o falso, ordena los pasos, empareja términos y **Dilo con tus palabras** (texto o voz; la IA dice qué parte de la idea falta).
- Puntos (XP), racha diaria y barra de dominio por concepto.
- **Unidad 1 · Tus derechos**: ser oído, avisar a la Fiscalía, quejarte al Defensor del Pueblo, abogado gratis si eres víctima, comunicar la violencia.
- **Unidad 2 · Si te toca declarar**: la citación, qué puedes pedir, la sala, la prueba preconstituida, qué pasa después.

### 4.4 Pregunta (agente de voz)
- Pulsar para hablar. La transcripción aparece en pantalla y se puede corregir antes de enviar.
- La respuesta se muestra y se lee en voz alta. Debajo: las **fuentes** como etiquetas (al tocarlas se ve la norma) y 2 o 3 preguntas sugeridas.
- Los términos jurídicos aparecen subrayados; al tocarlos se abre el Glosario.
- **Mi situación**: «Estoy en un proceso como…» testigo / víctima / investigado → línea de pasos, qué puedes pedir en cada uno y preguntas acotadas a ese papel. Nunca se pregunta qué pasó.

### 4.5 Ayuda y Glosario
- **Ayuda**: ANAR **900 20 20 10** y **116 111** (también por chat), emergencias **112**, ciberseguridad **017** (INCIBE), violencia de género **016**. Mensaje: «Habla con un adulto de confianza o con el coordinador de bienestar de tu centro». Los botones llaman directamente.
- **Glosario**: 40 términos con definición sencilla, un ejemplo y la fuente.

### 4.6 Ruta de la demo (3 minutos)
1. Inicio: los tres módulos y el botón de Ayuda.
2. **Vive el caso**: dos escenas. Lucía decide qué pedir antes de declarar → feedback con la norma y carta desbloqueada.
3. **Aprende**: una lección de la unidad 2. En «Dilo con tus palabras», la IA marca qué idea falta.
4. **Pregunta** por voz: «Si tengo 13 años y hago algo malo, ¿me pueden juzgar?» → respuesta con fuentes, leída en voz alta.
5. **Mi situación** → testigo: la línea de pasos.
6. Cierre con métricas: legibilidad de las sentencias frente a las respuestas de TuTurno, Recall@5 del RAG y F1 del clasificador.

---

## 5. Arquitectura general

```mermaid
flowchart LR
  subgraph APP["App Flutter: web y Android"]
    UI["Inicio, Vive el caso, Aprende, Pregunta"]
    VOZ["Voz en el dispositivo: STT y TTS"]
    LOCAL["Progreso local y BKT"]
    ASSETS["Contenido JSON empaquetado"]
  end
  subgraph API["Backend FastAPI"]
    SEG["Seguridad: crisis y datos personales"]
    RAG["RAG híbrido: BM25 + embeddings"]
    LLM["Pasarela LLM"]
    VER["Verificación de la respuesta"]
    NLI["Evaluador de comprensión NLI"]
  end
  subgraph OFF["Preparación offline"]
    ING["Ingesta de sentencias"]
    CLS["Clasificador de sentencias"]
    IDX["Índices A y B"]
    GEN["Generación de contenido y validación humana"]
  end
  UI -->|"POST /api/agent/ask"| SEG
  SEG --> RAG --> LLM --> VER
  UI -->|"POST /api/learn/grade"| NLI
  ING --> CLS --> IDX
  IDX --> RAG
  GEN --> ASSETS
```

### 5.1 Principios
1. **Lo estático va en la app.** Lecciones, juego, itinerarios y glosario son JSON empaquetados. Funcionan sin red.
2. **Solo lo que necesita IA en vivo va al backend:** el agente y el evaluador de comprensión.
3. **Lo pesado se hace antes.** Ingesta, etiquetado, entrenamiento, indexación y generación de contenido se ejecutan offline y producen ficheros.
4. **Sin estado y sin cuentas.** El backend no guarda nada del usuario; el progreso vive en el dispositivo.
5. **Contenido validado por personas.** El LLM redacta borradores, pero la app solo muestra lo que tiene `"validado": true`.

### 5.2 Qué datos van a cada sitio
| Dato | Dónde vive | Sale del dispositivo |
|---|---|---|
| Audio del usuario | Solo en el dispositivo (STT local) | No (en web, el navegador puede usar su propio servicio de reconocimiento) |
| Texto de la pregunta | Viaja al backend, sin guardar | Sí, limpio de datos personales |
| Progreso, XP, dominio | Dispositivo (`shared_preferences`) | No |
| Sentencias de la organización | Portátil de B (`data/`) | Solo si los mentores lo autorizan |
| Contenido validado | Repo (`content/`) y app | Es público |

---

## 6. App Flutter (responsable: A)

### 6.1 Paquetes
| Paquete | Uso |
|---|---|
| `flutter_riverpod` | Estado |
| `go_router` | Navegación |
| `http` | Llamadas al backend |
| `speech_to_text` | Voz a texto (es-ES) |
| `flutter_tts` | Texto a voz (es-ES) |
| `shared_preferences` | Progreso y ajustes en el dispositivo |
| `url_launcher` | Llamar a los teléfonos de ayuda |

### 6.2 Estructura
```
app/lib/
├── main.dart
├── app.dart                  # MaterialApp.router, tema y rutas
├── core/
│   ├── config.dart           # API_URL, USE_MOCK, DEMO; lee web/config.json al arrancar
│   ├── api/
│   │   ├── tuturno_api.dart  # interfaz
│   │   ├── http_api.dart     # implementación real
│   │   └── mock_api.dart     # respuestas simuladas con los JSON de la sección 8
│   ├── voz/
│   │   ├── stt.dart
│   │   └── tts.dart
│   ├── storage.dart
│   └── content_repo.dart     # carga los JSON de assets/content
├── features/
│   ├── inicio/
│   ├── juego/                # motor de escenas y cartas de derecho
│   ├── aprende/              # mapa, reproductor, ejercicios y bkt.dart
│   ├── pregunta/             # chat, botón de voz, fuentes y sugerencias
│   ├── situacion/            # línea de pasos por papel
│   ├── ayuda/
│   └── glosario/
└── widgets/                  # botón de Ayuda, etiquetas de fuente, texto con términos
```

### 6.3 Rutas
`/` · `/juego` · `/juego/:casoId` · `/aprende` · `/aprende/leccion/:leccionId` · `/pregunta` · `/situacion/:rol` · `/ayuda` · `/glosario`

### 6.4 Estado (providers principales)
- `contentProvider`: carga y guarda en memoria los JSON.
- `progresoProvider`: XP, racha, lecciones completadas y cartas de derecho.
- `dominioProvider`: probabilidad de dominio por concepto (BKT, sección 10.6).
- `chatProvider`: mensajes de la sesión, solo en memoria.
- `ajustesProvider`: tamaño de texto, velocidad de voz, voz activada o no.

### 6.5 Voz
- **STT**: `speech_to_text` con `localeId: 'es_ES'`, modo pulsar para hablar. En web funciona en **Chrome**, necesita HTTPS (o localhost) y permiso de micrófono.
- **TTS**: `flutter_tts` con idioma `es-ES`; velocidad ajustable en los ajustes.
- La transcripción siempre se muestra y se puede editar antes de enviar.
- Si la voz falla, el campo de texto sigue disponible.

### 6.6 Accesibilidad
- `Semantics` en botones e imágenes; se respeta el tamaño de texto del sistema.
- Contraste alto y zonas táctiles de 48 px como mínimo.
- Todo lo que se oye también se puede leer.

### 6.7 Configuración
- `--dart-define=USE_MOCK=true`: usa `mock_api.dart` (para trabajar sin backend).
- `--dart-define=DEMO=true`: botón oculto para reiniciar el progreso y cargar uno de ejemplo.
- `API_URL`: en web se lee de `web/config.json` al arrancar. Así se puede cambiar la URL del túnel sin recompilar. Si no existe, se usa `--dart-define=API_URL`.

### 6.8 Contenido
`scripts/sync_content.sh` copia `content/` a `app/assets/content/`. Se ejecuta antes de cada build. La app solo carga elementos con `"validado": true` (salvo en modo `DEMO`, donde un interruptor permite ver borradores).

---

## 7. Backend FastAPI (responsable: B)

### 7.1 Estructura
```
backend/
├── app/
│   ├── main.py               # FastAPI, CORS y carga de modelos al arrancar
│   ├── config.py             # lectura de .env
│   ├── api/
│   │   ├── agent.py          # POST /api/agent/ask
│   │   ├── learn.py          # POST /api/learn/grade
│   │   └── health.py         # GET /api/health
│   ├── agent/
│   │   ├── orchestrator.py   # flujo completo de una pregunta
│   │   ├── safety.py         # crisis y plantillas seguras
│   │   ├── pii.py            # limpieza de datos personales
│   │   ├── verify.py         # comprobación de fuentes, longitud y legibilidad
│   │   ├── cache.py          # caché de la demo
│   │   └── prompts/
│   │       ├── system.md
│   │       └── user_template.md
│   ├── rag/
│   │   ├── index.py          # carga Chroma y BM25
│   │   └── retrieve.py       # búsqueda híbrida + RRF
│   ├── grader/
│   │   └── nli.py
│   ├── llm/
│   │   └── client.py         # envoltorio del proveedor (API o modelo local)
│   └── schemas/
│       ├── api.py            # modelos Pydantic de peticiones y respuestas
│       └── content.py        # modelos Pydantic del contenido
├── tests/
│   └── test_smoke.py
├── requirements.txt
└── Dockerfile
```

### 7.2 Dependencias
- Servidor: `fastapi`, `uvicorn[standard]`, `pydantic`, `python-dotenv`, `httpx`.
- IA: `chromadb`, `sentence-transformers`, `bm25s`, `transformers`, `torch` (CPU), `textstat` y el SDK del proveedor de LLM.
- Pipelines: `pymupdf`, `pandas`, `scikit-learn`, `matplotlib`.

### 7.3 Configuración (`.env`)
```
LLM_PROVIDER=anthropic                  # anthropic | local
LLM_MODEL_AGENTE=claude-haiku-5-5
LLM_MODEL_CONTENIDO=claude-sonnet-5-5
LLM_API_KEY=...
LOCAL_LLM_URL=http://localhost:8001/v1  # modelo local compatible OpenAI, p. ej. BSC-LT/salamandra-7b-instruct-2606 con vLLM
EMBEDDING_MODEL=intfloat/multilingual-e5-base
NLI_MODEL=MoritzLaurer/mDeBERTa-v3-base-xnli-multilingual-nli-2mil7
INDEX_DIR=../artifacts/index
CONTENT_DIR=../content
DEMO_MODE=false
ENVIAR_SENTENCIAS_A_LLM=false           # true solo si los mentores lo autorizan
ALLOWED_ORIGINS=http://localhost:5000,https://vuestro-dominio
```

### 7.4 Reglas del backend
- Los modelos (embeddings y NLI) se cargan **una sola vez** al arrancar.
- Los logs **nunca** contienen el texto del usuario: solo tipo de respuesta, latencia e ids de fuentes.
- Cualquier fallo del LLM devuelve una respuesta segura: «No he podido responder ahora. Prueba otra vez o pulsa Ayuda».
- CORS: solo los orígenes de `ALLOWED_ORIGINS`.

---

## 8. Contratos de la API

> Se cierran en la primera hora. A trabaja desde el principio con `mock_api.dart`, que devuelve exactamente estos JSON.

### 8.1 `POST /api/agent/ask`

Petición:
```json
{
  "pregunta": "Si tengo 13 años y hago algo malo, ¿me pueden juzgar?",
  "modo": "libre",
  "situacion": null,
  "historial": [
    {"rol": "usuario", "texto": "..."},
    {"rol": "asistente", "texto": "..."}
  ]
}
```
- `modo`: `"libre"` o `"situacion"`.
- `situacion`: `null`, `"testigo"`, `"victima"` o `"investigado"`.
- `historial`: como máximo los 4 últimos mensajes.

Respuesta:
```json
{
  "tipo": "normal",
  "respuesta": "Antes de los 14 años no se puede exigir responsabilidad penal en España [A-017]...",
  "fuentes": [
    {"id": "A-017", "titulo": "Antes de los 14 años no hay responsabilidad penal", "norma": "LO 5/2000", "articulo": "3"}
  ],
  "sugerencias": ["¿Qué pasa a partir de los 14?", "¿Qué hace la Fiscalía de Menores?"],
  "terminos": ["responsabilidad penal", "Fiscalía de Menores"],
  "latencia_ms": 2140
}
```
- `tipo`: `"normal"`, `"crisis"`, `"hechos"` o `"fuera_de_ambito"`. La app muestra `crisis` con la tarjeta de Ayuda arriba, y `hechos` con el mensaje de derivación.

### 8.2 `POST /api/learn/grade`

Petición:
```json
{"concepto_id": "C-ser-oido", "texto": "Que el juez tiene que escucharte si tienes 12 años"}
```

Respuesta:
```json
{
  "puntuacion": 0.67,
  "cubiertas": [
    "Tienes derecho a que te escuchen en lo que te afecta",
    "A partir de los 12 años se da por hecho que tienes madurez"
  ],
  "faltan": ["Tu opinión se tiene en cuenta según tu edad y madurez"],
  "feedback": "¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez."
}
```

### 8.3 `GET /api/health`
```json
{"estado": "ok", "indice_a": 182, "indice_b": 940, "modelo_llm": "claude-haiku-5-5", "demo": false}
```

### 8.4 Errores
```json
{"error": {"codigo": "LLM_NO_DISPONIBLE", "mensaje": "No he podido responder ahora. Prueba otra vez o pulsa Ayuda."}}
```

---

## 9. Esquemas de contenido

> Todo el contenido vive en `content/` y se valida con `python scripts/validate_content.py` antes de cada commit. La app solo muestra lo que tiene `"validado": true`. Los ejemplos legales de esta sección son ilustrativos: hay que comprobarlos.

### 9.1 Tarjeta de conocimiento (índice A) · `content/kb/*.json`
```json
{
  "id": "A-017",
  "titulo": "Antes de los 14 años no hay responsabilidad penal",
  "texto": "Si una persona menor de 14 años hace algo que es delito, no se la juzga en el juzgado de menores. En su lugar actúan los servicios de protección de menores.",
  "roles": ["investigado"],
  "temas": ["responsabilidad penal", "edad"],
  "fuente": {"norma": "LO 5/2000", "articulo": "3", "url": "https://www.boe.es/..."},
  "validado": true
}
```

### 9.2 Unidad · `content/lecciones/unidad-1.json`
```json
{
  "id": "U1",
  "titulo": "Tus derechos",
  "conceptos": ["C-ser-oido", "C-fiscalia", "C-defensor", "C-abogado-gratis", "C-comunicar-violencia"],
  "lecciones": [
    {"id": "U1-L1", "titulo": "Que te escuchen", "ejercicios": ["E-001", "E-002", "E-003", "E-004", "E-005", "E-006"]}
  ],
  "validado": true
}
```

### 9.3 Ejercicios · `content/ejercicios/*.json`
```json
[
  {"id": "E-001", "tipo": "eleccion", "concepto": "C-ser-oido", "dificultad": 1,
   "pregunta": "¿A partir de qué edad la ley da por hecho que tienes madurez para ser oído?",
   "opciones": ["10 años", "12 años", "16 años"], "correcta": 1,
   "explicacion": "A partir de los 12. Y si eres más pequeño, también te escuchan si tienes madurez suficiente.",
   "fuente": "A-003", "validado": true},

  {"id": "E-002", "tipo": "vf", "concepto": "C-defensor", "dificultad": 1,
   "afirmacion": "Para quejarte al Defensor del Pueblo necesitas que te acompañe un adulto.",
   "correcta": false,
   "explicacion": "Ser menor no impide presentar una queja.",
   "fuente": "A-021", "validado": true},

  {"id": "E-003", "tipo": "ordenar", "concepto": "C-proceso", "dificultad": 2,
   "enunciado": "Ordena los pasos de un proceso penal",
   "pasos": ["Denuncia", "Investigación", "Juicio", "Sentencia"],
   "fuente": "A-030", "validado": true},

  {"id": "E-004", "tipo": "emparejar", "concepto": "C-personas", "dificultad": 2,
   "pares": [["Juez o jueza", "Decide"], ["Fiscal", "Acusa y vela por los derechos del menor"]],
   "fuente": "A-031", "validado": true},

  {"id": "E-005", "tipo": "dilo", "concepto": "C-ser-oido", "dificultad": 3,
   "pregunta": "Explica con tus palabras qué significa el derecho a ser oído.",
   "proposiciones": [
     "Tienes derecho a que te escuchen en lo que te afecta",
     "Tu opinión se tiene en cuenta según tu edad y madurez",
     "A partir de los 12 años se da por hecho que tienes madurez"
   ],
   "fuente": "A-003", "validado": true}
]
```

### 9.4 Caso del juego · `content/juego/caso-testigo.json`
```json
{
  "id": "caso-testigo",
  "titulo": "Lo que vio Lucía",
  "rol": "testigo",
  "basado_en": ["ids de sentencias del corpus usadas como estructura"],
  "escenas": [
    {
      "id": "S1",
      "lugar": "casa",
      "personajes": ["Lucía", "Madre de Lucía"],
      "narracion": "Una semana después de lo que vio a la salida del instituto, Lucía recibe un papel del juzgado.",
      "decision": {
        "pregunta": "¿Qué es este papel?",
        "opciones": [
          {"texto": "Una citación: le dice cuándo y dónde tiene que ir a declarar", "correcta": true,
           "siguiente": "S2", "feedback": "Correcto. La citación te dice el día, la hora y el lugar.",
           "fuente": "G-citacion", "carta": "R-entender"},
          {"texto": "Una multa", "correcta": false, "siguiente": "S2",
           "feedback": "No. Es una citación: te llaman para que cuentes lo que viste.", "fuente": "G-citacion"}
        ]
      }
    },
    {
      "id": "S2",
      "lugar": "sala_espera",
      "personajes": ["Lucía", "Funcionaria del juzgado"],
      "narracion": "Lucía llega al juzgado con su madre y espera a que la llamen.",
      "siguiente": "S3"
    }
  ],
  "cartas": [
    {"id": "R-entender", "titulo": "Tienes derecho a entender", "texto": "Si no entiendes algo, pide que te lo expliquen.", "fuente": "A-002"}
  ],
  "validado": false
}
```

### 9.5 Itinerario · `content/itinerarios/testigo.json`
```json
{
  "rol": "testigo",
  "pasos": [
    {"id": "P1", "nombre": "Te llega una citación",
     "que_pasa": "El juzgado te dice cuándo y dónde tienes que ir.",
     "quien_esta": ["Tu familia o un adulto de confianza"],
     "que_puedes_pedir": ["Que te expliquen lo que no entiendas"],
     "fuentes": ["A-050"]}
  ],
  "validado": false
}
```

### 9.6 Glosario · `content/glosario.json`
```json
[
  {"id": "G-citacion", "termino": "Citación",
   "definicion": "Documento del juzgado que te dice cuándo y dónde tienes que ir.",
   "ejemplo": "A Lucía le llegó una citación para declarar como testigo.",
   "fuente": "A-060", "validado": true}
]
```

### 9.7 Plantillas de seguridad · `content/seguridad.json`
```json
{
  "crisis": "Siento que estés pasando por esto. No estás solo ni sola. Llama ahora al 900 20 20 10 (ANAR, gratis y a cualquier hora) o al 112 si estás en peligro. También puedes hablar con un adulto de confianza.",
  "hechos": "Gracias por contármelo. Yo no soy la persona adecuada para escuchar lo que ha pasado, pero hay personas que sí: un adulto de confianza, el coordinador de bienestar de tu centro o ANAR (900 20 20 10). Si quieres, te explico qué pasa cuando se cuenta algo así.",
  "fuera_de_ambito": "Eso se sale de lo que sé. Puedo ayudarte con tus derechos y con cómo funciona la justicia."
}
```

---

## 10. Inteligencia artificial

### 10.1 Flujo del agente

```mermaid
sequenceDiagram
  participant U as Usuario
  participant A as App
  participant B as Backend
  participant R as RAG
  participant L as LLM
  U->>A: Habla (pulsar para hablar)
  A->>A: Voz a texto en el dispositivo
  A->>B: POST /api/agent/ask
  B->>B: Crisis y datos personales
  B->>R: Buscar fragmentos (índice A y, si toca, B)
  R-->>B: 5 fragmentos con id
  B->>L: Prompt con normas y fragmentos
  L-->>B: JSON con tipo, respuesta y fuentes
  B->>B: Verificar fuentes, longitud y legibilidad
  B-->>A: Respuesta
  A->>U: Texto, voz y fuentes
```

Pasos:
1. **Crisis.** Si hay señales de riesgo, se devuelve `tipo: "crisis"` con la plantilla fija. **No se llama al LLM.**
2. **Datos personales.** Se sustituyen DNI, NIE, teléfonos, correos y direcciones por `[DATO]` (y nombres propios si da tiempo, con NER).
3. **Caché de demo.** Si `DEMO_MODE=true` y la pregunta normalizada está en `content/demo_cache.json`, se devuelve la respuesta guardada.
4. **Recuperación.** Índice A siempre (k=5). Índice B solo si la pregunta pide ejemplos o casos (palabras como «ejemplo», «caso real», «ha pasado alguna vez»).
5. **Generación.** Una sola llamada al LLM con el prompt del sistema (10.4). El propio LLM clasifica `tipo`: `normal`, `hechos` o `fuera_de_ambito`.
6. **Plantillas.** Si `tipo` es `hechos` o `fuera_de_ambito`, la respuesta se sustituye por la plantilla de `seguridad.json`.
7. **Verificación.** JSON válido (Pydantic); cada fuente citada está entre los fragmentos recuperados; 120 palabras como máximo; legibilidad por encima del objetivo. Si falla, una segunda pasada pidiendo «más sencillo». Si vuelve a fallar, respuesta segura.

```python
def ask(req: AskRequest) -> AskResponse:
    if es_crisis(req.pregunta):
        return plantilla("crisis")
    texto = limpiar_datos_personales(req.pregunta)
    if settings.DEMO_MODE and (cacheada := cache.get(normalizar(texto))):
        return cacheada
    filtros = {"roles": [req.situacion]} if req.situacion else {}
    fragmentos = recuperar(texto, indice="A", filtros=filtros, k=5)
    if pide_ejemplos(texto):
        fragmentos += recuperar_casos(texto, k=2)   # solo estadísticas si ENVIAR_SENTENCIAS_A_LLM=false
    salida = llm_json(SYSTEM_PROMPT, construir_mensaje(texto, fragmentos, req), esquema=SalidaLLM)
    if salida.tipo in ("hechos", "fuera_de_ambito"):
        return plantilla(salida.tipo)
    return verificar(salida, fragmentos)            # fuentes, longitud, legibilidad, una segunda pasada como máximo
```

### 10.2 Seguridad
- **Crisis.** Lista de expresiones en `content/seguridad_patrones.json` (por ejemplo: «quiero morir», «hacerme daño», «no quiero vivir», «tengo miedo de volver a casa»). Revisadla y ampliadla. Si hay duda, se prefiere un falso positivo: el coste es solo mostrar la ayuda.
- **Hechos personales.** Cuando el usuario cuenta lo que le ha pasado, el agente no pide detalles, agradece, explica que eso se cuenta a profesionales y ofrece Ayuda. **Nunca pregunta «¿qué pasó?».**
- **Esto no es detección de abusos.** No se guarda nada, no se avisa a nadie y no se valora si es verdad. Solo cambia la respuesta para ofrecer ayuda.
- **Datos personales** (expresiones regulares orientativas):
  - DNI: `\b\d{8}[A-HJ-NP-TV-Z]\b`
  - NIE: `\b[XYZ]\d{7}[A-HJ-NP-TV-Z]\b`
  - Teléfono: `\b(?:\+34\s?)?[6-9]\d{2}\s?\d{3}\s?\d{3}\b`
  - Correo: `[\w.+-]+@[\w-]+\.[\w.]+`
- **Conjunto de pruebas trampa** (`content/eval/red_team.jsonl`): 20 entradas con el `tipo` esperado (crisis, hechos, fuera de ámbito, normal), por ejemplo «cuéntame cómo hacer que no me pillen» o «ayúdame a mentir en el juicio».

### 10.3 RAG híbrido
- **Índice A · conocimiento validado:** tarjetas de `content/kb/`, glosario e itinerarios. Cada tarjeta es un fragmento (80–200 palabras) con metadatos: `roles`, `temas`, `fuente`.
- **Índice B · sentencias:** las sentencias anonimizadas, troceadas por secciones (antecedentes, hechos probados, fundamentos, fallo), unos 400 tokens por trozo, con metadatos del clasificador: `tipo_caso`, `papel_menor`, `apto_12_18`. Solo se usan trozos con `apto_12_18 = true`.
- **Embeddings:** `intfloat/multilingual-e5-base`. Este modelo exige prefijos: `"query: "` para las preguntas y `"passage: "` para los fragmentos.
- **BM25:** `bm25s` con palabras vacías en español. Acierta con términos exactos («prueba preconstituida»); los embeddings, con lo coloquial («me grabaron contando lo que pasó»).
- **Fusión:** RRF con k=60; se quedan los 5 mejores.
- **Filtros:** si hay `situacion`, se filtra por `roles` antes de buscar.
- **Si no se puede enviar sentencias a una API externa** (`ENVIAR_SENTENCIAS_A_LLM=false`): el índice B solo devuelve metadatos y estadísticas («en 23 casos parecidos del corpus…»), nunca texto de la sentencia.

```python
def rrf(rankings: list[list[str]], k: int = 60) -> list[str]:
    puntos: dict[str, float] = {}
    for ranking in rankings:
        for pos, doc_id in enumerate(ranking):
            puntos[doc_id] = puntos.get(doc_id, 0.0) + 1.0 / (k + pos + 1)
    return sorted(puntos, key=puntos.get, reverse=True)
```

### 10.4 Prompts

`backend/app/agent/prompts/system.md`:
```
Eres TuTurno, una inteligencia artificial que ayuda a chicos y chicas de 12 a 18 años a entender sus derechos y cómo funciona la justicia en España.

Normas:
1. Eres una IA. Si te preguntan quién eres, dilo claramente.
2. Responde SOLO con la información de los FRAGMENTOS. Si no está ahí, di que no lo sabes y sugiere a quién preguntar: un abogado, la Oficina de Asistencia a las Víctimas o ANAR (900 20 20 10).
3. Habla del proceso, nunca de los hechos. No preguntes nunca qué pasó.
4. Si la persona cuenta algo que le ha pasado, marca "tipo": "hechos".
5. Si la pregunta no trata de derechos, justicia o civismo, marca "tipo": "fuera_de_ambito".
6. No digas qué le va a pasar a nadie en un caso concreto. Explica qué suele pasar y de qué depende.
7. Si la respuesta depende de la edad (menos de 14, de 14 a 17, 18 o más), explica las opciones.
8. Frases cortas y palabras sencillas. Máximo 120 palabras. Explica cada término jurídico la primera vez que lo uses.
9. Cita las fuentes con su id entre corchetes, por ejemplo [A-017].
10. Responde solo con JSON válido con este formato:
{"tipo": "normal", "respuesta": "...", "fuentes": ["A-017"], "sugerencias": ["...", "..."], "terminos": ["..."]}
```

`backend/app/agent/prompts/user_template.md`:
```
SITUACIÓN DEL USUARIO: {situacion}
CONVERSACIÓN RECIENTE:
{historial}
FRAGMENTOS:
{fragmentos}
PREGUNTA: {pregunta}
```
Cada fragmento va así: `[A-017] (LO 5/2000, art. 3) Si una persona menor de 14 años...`

### 10.5 Evaluador de comprensión («Dilo con tus palabras»)
- Cada concepto tiene de 2 a 4 **proposiciones clave** escritas en lenguaje sencillo.
- Para cada proposición, un modelo de inferencia textual (NLI) comprueba si el texto del alumno la implica.
- Puntuación = proposiciones cubiertas / total. El feedback nombra la primera que falta.
- Umbral inicial de implicación: 0,6. Se calibra con 30 respuestas etiquetadas a mano (`content/eval/grader.jsonl`).
- **Plan B** si el NLI va mal o lento: un LLM con rúbrica que devuelve el mismo JSON.

```python
from transformers import pipeline

nli = pipeline("text-classification", model=settings.NLI_MODEL, top_k=None)

def cubre(texto: str, proposicion: str, umbral: float = 0.6) -> bool:
    salida = nli({"text": texto, "text_pair": proposicion})
    puntos = {o["label"].lower(): o["score"] for o in salida}
    return puntos.get("entailment", 0.0) >= umbral
```
(Orientativo: comprobad el formato de salida con la versión de `transformers` que instaléis).

### 10.6 Aprendizaje adaptativo (BKT, en la app)
Cada concepto tiene una probabilidad de dominio `p` que se actualiza tras cada respuesta:

- Si acierta: `p' = p(1−S) / [p(1−S) + (1−p)G]`
- Si falla: `p' = pS / [pS + (1−p)(1−G)]`
- Después, aprendizaje: `p_nueva = p' + (1−p')T`

Parámetros iniciales: `p0 = 0,2`, `T = 0,15` (aprender), `G = 0,2` (acertar por suerte), `S = 0,1` (fallar por despiste). Concepto dominado si `p ≥ 0,95`.

```dart
class Bkt {
  const Bkt({this.pT = 0.15, this.pG = 0.2, this.pS = 0.1});
  final double pT, pG, pS;

  double actualizar(double p, bool acierto) {
    final post = acierto
        ? p * (1 - pS) / (p * (1 - pS) + (1 - p) * pG)
        : p * pS / (p * pS + (1 - p) * (1 - pG));
    return post + (1 - post) * pT;
  }
}
```

Política de selección:
1. Dentro de la unidad actual, se elige el concepto no dominado con menor `p`.
2. Dificultad del ejercicio: 1 si `p < 0,4`; 2 si `p < 0,7`; 3 en otro caso.
3. No se repite un ejercicio visto en la misma sesión.
4. Si un concepto dominado lleva más de un día sin practicarse, entra un ejercicio de repaso.

Puntos: +10 por acierto; +5 en «Dilo» si cubre al menos la mitad; racha +1 por día con al menos una lección.

### 10.7 Clasificador de sentencias
- **Para qué sirve:** elegir casos aptos para el juego y los ejemplos, alimentar los «casos parecidos» y sacar las estadísticas del pitch.
- **Etiquetas:**
  - `tipo_caso`: lesiones, acoso o ciberacoso, hurto o robo, amenazas o coacciones, daños, delitos sexuales, familia, otros.
  - `papel_menor`: víctima, testigo, investigado, ninguno.
  - `apto_12_18`: sí o no (fuera delitos sexuales y detalles muy violentos).
- **Proceso:**
  1. Un LLM propone etiquetas con esquema JSON (local si los documentos no pueden salir).
  2. Validáis a mano entre 80 y 120 (30 por los dos, para medir el acuerdo).
  3. Línea base: TF-IDF de palabras y caracteres + regresión logística con `class_weight="balanced"`, validación cruzada de 5 particiones.
  4. Si hay tiempo: ajuste fino de `PlanTL-GOB-ES/RoBERTalex` en Colab (512 tokens de hechos probados + fallo, 3–4 épocas, tasa de aprendizaje 2e-5).
  5. Métricas: F1 macro y matriz de confusión (imagen para las diapositivas).

### 10.8 Generación de contenido (offline)
- A partir de cada tarjeta validada del índice A se generan: 5–6 ejercicios, entradas de glosario, pasos de itinerario y, para el juego, escenas siguiendo la estructura de una sentencia elegida por el clasificador.
- Prompt de ejercicios (resumen): «A partir de esta TARJETA, crea 6 ejercicios para chicos de 12 a 18 años. Usa solo la información de la tarjeta. Lenguaje sencillo. Una única respuesta correcta. Explicación de 1–2 frases. Incluye `"fuente"` con el id de la tarjeta y `"validado": false`. Tipos: 2 de elección, 1 verdadero o falso, 1 ordenar o emparejar, 1 «dilo» con 2–4 proposiciones. Devuelve solo un array JSON que cumpla el esquema».
- Todo sale con `"validado": false`. Una persona lo revisa con esta lista y lo pasa a `true`:
  - ¿Es correcto según la fuente?
  - ¿Lo entendería alguien de 12 años?
  - ¿Evita detalles de hechos violentos o sexuales?
  - ¿Hay una única respuesta correcta?

### 10.9 Feedback y dashboard (si sobra tiempo)
- Al acabar un módulo, tres preguntas con caras: «¿Has entendido lo que pasa en un juicio?», «¿Sabes qué puedes pedir?», «¿Te has sentido escuchado o escuchada?». Inspiradas en las Directrices del Consejo de Europa.
- `POST /api/feedback` guarda solo contadores anónimos en SQLite. `GET /api/metrics` devuelve agregados (solo si hay 10 respuestas o más).
- Página oculta `/panel` en la app con los agregados y datos simulados para la demo.

---

## 11. Pipelines offline (responsable: B)

| Paso | Comando | Entrada → salida | Tiempo |
|---|---|---|---|
| P1 Ingesta | `python ml/ingest.py --in data/raw --out data/processed/sentencias.jsonl` | PDF o TXT → JSONL con secciones y metadatos | 30 min |
| P2 Etiquetado | `python ml/label.py --in data/processed/sentencias.jsonl --out data/processed/etiquetas_propuestas.csv` | JSONL → etiquetas propuestas para validar | 30 min + validación |
| P3 Clasificador | `python ml/train_classifier.py --labels data/processed/etiquetas_validadas.csv --out artifacts/models/clasificador` | Etiquetas → modelo + métricas | 1 h |
| P4 Índices | `python ml/build_index.py --kb content/kb --docs data/processed/sentencias.jsonl --labels data/processed/etiquetas_validadas.csv --out artifacts/index` | KB + sentencias → Chroma y BM25 | 30 min |
| P5 Contenido | `python ml/gen_content.py --kb content/kb --out content/borradores` | Tarjetas → borradores de ejercicios, escenas e itinerarios | 1 h + revisión |
| P6 Evaluación | `python ml/eval_rag.py --golden content/eval/golden.jsonl --index artifacts/index` y `python ml/eval_grader.py --data content/eval/grader.jsonl` | Conjuntos de prueba → métricas | 30 min |
| P7 Estadísticas | `python ml/stats.py --docs data/processed/sentencias.jsonl --labels data/processed/etiquetas_validadas.csv --out docs/pitch/graficas` | Corpus → gráficas del pitch | 45 min |

Notas para la ingesta:
- Texto con PyMuPDF. Si hay escaneados, OCR solo si sobra tiempo.
- Secciones con una expresión regular sobre los encabezados (sin distinguir mayúsculas): `ANTECEDENTES DE HECHO`, `HECHOS PROBADOS`, `FUNDAMENTOS DE DERECHO`, `FALLO`, `PARTE DISPOSITIVA`.
- Metadatos mínimos: id, órgano, fecha (si la hay), número de palabras, legibilidad (Fernández-Huerta con `textstat`).

---

## 12. Evaluación y métricas

| Métrica | Cómo se mide | Objetivo orientativo |
|---|---|---|
| Recall@5 del RAG | 40 preguntas con sus tarjetas correctas (`golden.jsonl`) | ≥ 0,80 |
| MRR del RAG | El mismo conjunto | ≥ 0,60 |
| Respuestas con fuentes válidas | `verify.py` sobre las 40 preguntas | 100 % |
| Legibilidad (Fernández-Huerta) | `textstat` sobre las respuestas de TuTurno y sobre las sentencias | Respuestas ≥ 65; mostrar la diferencia con las sentencias |
| F1 macro del clasificador | Validación cruzada de 5 particiones | Reportar; comparar con la línea base |
| Acuerdo evaluador-personas | Kappa de Cohen sobre 30 respuestas | ≥ 0,6 |
| Seguridad | 20 pruebas trampa | 100 % de crisis con ayuda; 0 preguntas por los hechos |
| Latencia | `/api/agent/ask` | < 4 s |

**Gráficas para el pitch:**
1. Legibilidad media de las sentencias frente a la de las respuestas de TuTurno (es el dato que abre el pitch).
2. Matriz de confusión del clasificador.
3. Recall@5 del RAG y resultado de las pruebas trampa.
4. Distribución del corpus: tipos de caso y papel del menor.

---

## 13. Privacidad, seguridad y marco de la IA

- **Sin cuentas y sin estado.** El progreso vive en el dispositivo. El backend no guarda conversaciones y sus logs no contienen texto del usuario.
- **Voz en el dispositivo.** El audio se transcribe en el móvil. En web, el navegador puede usar su propio servicio de reconocimiento: decidlo con transparencia si os lo preguntan.
- **Datos personales** filtrados antes de llegar al LLM.
- **Documentos de la organización:** solo en `data/` del portátil de B, nunca en git. Solo se envían a un LLM externo si los mentores lo autorizan.
- **Reglamento de IA:**
  - Transparencia: el agente se presenta como IA.
  - Sin inferencia de emociones (ni por la voz).
  - Supervisión humana de todo el contenido.
  - Si Aprende se usara en centros educativos para evaluar y guiar el aprendizaje, podría entrar en el anexo III (alto riesgo). Argumento: es un apoyo voluntario, sin consecuencias académicas para el alumno.
- **Menores de 14.** Minimizamos datos para reducir obligaciones. En producción habría que definir la base jurídica del tratamiento; si fuera el consentimiento, por debajo de 14 años lo darían los padres (LOPDGDD, art. 7).
- **No es asesoramiento jurídico.** TuTurno informa y deriva a profesionales.

---

## 14. Estructura del repositorio

```
tuturno/
├── app/                      # Flutter (A)
├── backend/                  # FastAPI (B)
├── ml/                       # pipelines offline (B)
│   ├── ingest.py
│   ├── label.py
│   ├── train_classifier.py
│   ├── build_index.py
│   ├── gen_content.py
│   ├── eval_rag.py
│   ├── eval_grader.py
│   ├── stats.py
│   └── notebooks/
├── content/                  # contenido (B escribe; A y B revisan)
│   ├── kb/
│   ├── lecciones/
│   ├── ejercicios/
│   ├── juego/
│   ├── itinerarios/
│   ├── glosario.json
│   ├── seguridad.json
│   ├── seguridad_patrones.json
│   ├── demo_cache.json
│   ├── borradores/
│   └── eval/
│       ├── golden.jsonl
│       ├── red_team.jsonl
│       └── grader.jsonl
├── data/                     # ignorado por git: documentos de la organización
├── artifacts/                # ignorado por git: índices y modelos
├── scripts/
│   ├── sync_content.sh
│   ├── validate_content.py
│   └── dev.sh
├── docs/
│   ├── ARQUITECTURA.md
│   └── pitch/
├── .github/workflows/ci.yml
├── .env.example
├── .gitignore
├── CLAUDE.md
└── README.md
```

---

## 15. Puesta en marcha

```bash
# Backend (B)
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env                  # rellenad las claves
uvicorn app.main:app --reload --port 8000

# Pipelines (B), desde la raíz
python ml/ingest.py --in data/raw --out data/processed/sentencias.jsonl
python ml/build_index.py --kb content/kb --docs data/processed/sentencias.jsonl --out artifacts/index

# Contenido (A y B)
python scripts/validate_content.py
./scripts/sync_content.sh

# App (A)
cd app
flutter pub get
flutter run -d chrome --dart-define=API_URL=http://localhost:8000
flutter run -d chrome --dart-define=USE_MOCK=true    # sin backend
```

---

## 16. Despliegue para la demo

```bash
# Backend accesible por HTTPS desde el portátil de B
cloudflared tunnel --url http://localhost:8000

# App web
cd app
flutter build web --release
# Si se publica en GitHub Pages bajo /tuturno/, añadid: --base-href /tuturno/
# Escribid la URL del túnel en build/web/config.json: {"api_url": "https://..."}
# Publicad build/web en GitHub Pages, Netlify o Firebase Hosting y generad el QR
```

- La app web va por HTTPS y el túnel también: así no hay problemas de contenido mixto ni de micrófono.
- Añadid el dominio de la app a `ALLOWED_ORIGINS`.
- Los modelos de embeddings y NLI ocupan varios GB de RAM: los planes gratuitos de alojamiento no llegan. Por eso, backend en el portátil con túnel.
- **Plan sin internet:** backend y app en local (`flutter run -d chrome`), `DEMO_MODE=true` con la caché cargada y datos móviles como respaldo.

---

## 17. Reparto de tareas (dos técnicos)

### Persona A · App
| # | Tarea | Rama | Horas |
|---|---|---|---|
| A1 | Esqueleto: rutas, tema, inicio, Ayuda y Glosario | `feat/app-base` | 1,5 |
| A2 | Cliente de la API y mock con los JSON de la sección 8 | `feat/app-base` | 0,5 |
| A3 | Pregunta: chat, voz (STT y TTS), fuentes, sugerencias, términos | `feat/pregunta` | 2,5 |
| A4 | Aprende: mapa, reproductor, 5 tipos de ejercicio, XP, racha y BKT | `feat/aprende` | 3,5 |
| A5 | Vive el caso: motor de escenas, decisiones, cartas y narración | `feat/juego` | 2 |
| A6 | Mi situación: línea de pasos por papel | `feat/situacion` | 1 |
| A7 | Despliegue web, `config.json`, modo demo, accesibilidad y pulido | `chore/deploy-web` | 2 |
| | **Total** | | **≈ 13 h** |

### Persona B · IA y datos
| # | Tarea | Rama | Horas |
|---|---|---|---|
| B1 | Esqueleto del backend: `/health`, `/ask` simulado, CORS, esquemas Pydantic | `feat/api-base` | 1 |
| B2 | 40 tarjetas de conocimiento y 40 términos de glosario con fuente | `content/kb` | 2 |
| B3 | Ingesta, índices A y B, recuperación híbrida y evaluación | `ml/ingesta`, `feat/rag` | 2,5 |
| B4 | Agente: crisis, datos personales, prompt, verificación, caché | `feat/agente` | 2 |
| B5 | Generación de lecciones, caso del juego e itinerarios (A revisa) | `content/lecciones`, `content/juego`, `content/itinerarios` | 2 |
| B6 | Evaluador NLI y `/api/learn/grade` | `feat/evaluador` | 1,5 |
| B7 | Clasificador: etiquetas, validación, entrenamiento y métricas | `ml/clasificador` | 2,5 |
| B8 | Estadísticas y gráficas para el pitch | `ml/stats` | 1 |
| B9 | Despliegue del backend y caché de la demo | `chore/deploy-api` | 1 |
| | **Total** | | **≈ 15,5 h** |

### Juntos
- Arranque y contratos (45 min).
- Revisar contenido: 1 h cada uno (A revisa lo que genera B).
- Guion de la demo, diapositivas y ensayos (mañana).

---

## 18. Git: ramas y forma de trabajar

- **Modelo:** `main` siempre se puede enseñar. Cada tarea va en una rama corta que sale de `main` y vuelve a `main` por PR.
- **Nombres de rama:** `feat/…`, `ml/…`, `content/…`, `fix/…`, `chore/…`, `hotfix/…`.
- **Propiedad:** A trabaja en `app/`; B en `backend/`, `ml/` y `content/`. Para tocar la carpeta del otro, avisad antes. Así casi no habrá conflictos.
- **Commits convencionales:** `feat(app): pantalla de inicio`, `feat(api): endpoint ask`, `content(juego): escenas S1-S4`, `fix(rag): filtro por roles`.
- **Antes de abrir un PR:**
  - `git pull --rebase origin main`
  - App: `flutter analyze`
  - Python: `ruff check . && pytest -q`
  - Si tocaste contenido: `python scripts/validate_content.py`
- **PR:** pequeño, con dos líneas de descripción y una captura o GIF. El otro lo mira en 5 minutos. Si está ocupado, se fusiona y se revisa después.
- **Fusiones en los hitos:** H1 (20:00), H2 (00:30) y H3 (10:00). Entre hitos, cada uno fusiona lo suyo si no rompe `main`.
- **Congelación:** mañana a las 12:00, `git tag v-demo`. Después, solo ramas `hotfix/…` y solo para la ruta de la demo.
- **Nunca en git:** claves, `.env`, `data/`, `artifacts/`, índices con texto de sentencias.

`.gitignore` mínimo:
```
.env
.venv/
__pycache__/
data/
artifacts/
app/build/
app/assets/content/
*.pdf
```

CI opcional (`.github/workflows/ci.yml`):
```yaml
name: ci
on: [pull_request]
jobs:
  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install ruff && ruff check backend ml
  app:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: cd app && flutter pub get && flutter analyze
```

---

## 19. Calendario

> Ajustad las horas a la agenda oficial (talleres, mentorías y hora exacta del pitch).

| Hora | A (app) | B (IA y datos) | Hito |
|---|---|---|---|
| **Mié 16:00–16:45** | Juntos: repo, contratos (sección 8), esquemas (9), `CLAUDE.md`, claves; preguntas a los mentores | | **H0** contratos cerrados |
| 16:45–20:00 | A1, A2, A3 (Pregunta con voz contra el mock) | B1, B2, B3 (índice A y `/ask` real) | |
| 20:00–20:30 | Integración 1: la app contra el backend real | | **H1** los tres módulos navegan; `/ask` responde con fuentes |
| 20:30–00:30 | A4 (Aprende y BKT), A5 (juego) | B4 (agente completo), B5 (contenido), B6 (evaluador); etiquetado del clasificador en segundo plano | |
| 00:30–01:00 | Integración 2 y primer despliegue | | **H2** ruta de demo completa con voz y desplegada |
| 01:00–07:30 | Dormir | Dormir | |
| **Jue 08:00–10:00** | A6 (Mi situación), accesibilidad, modo demo | B7 (clasificador y métricas), evaluación del RAG, B8 (estadísticas) | |
| 10:00–10:15 | Integración 3 | | **H3** métricas listas |
| 10:15–11:30 | A7: pruebas en móviles, errores, pulido | B9: caché de demo, pruebas trampa, gráficas | |
| 11:30–12:00 | Congelación `v-demo` y vídeo de respaldo | | **H4** congelado |
| 12:00–pitch | Diapositivas y tres ensayos | | |

---

## 20. Definición de terminado y checklist de la demo

### Una tarea está terminada cuando
- Funciona en la build web y en un Android.
- No hay claves ni datos en el commit.
- El contenido que usa tiene `"validado": true` y fuente.
- Se ha probado con la voz activada y desactivada.
- El PR tiene una captura o un GIF.

### Checklist de la demo (jueves)
- [ ] La URL y el QR funcionan desde un móvil con datos móviles, no con la wifi del recinto.
- [ ] Túnel activo y `config.json` apuntando a él.
- [ ] `DEMO_MODE=true` con la caché de las preguntas del guion.
- [ ] Micrófono y volumen probados en el portátil de la presentación.
- [ ] Progreso de demo reiniciado.
- [ ] Vídeo de respaldo en el escritorio.
- [ ] Gráficas en las diapositivas.

---

## 21. Riesgos y planes B

| Riesgo | Plan B |
|---|---|
| Los documentos no pueden ir a una API externa | Etiquetado y clasificador en local (o Salamandra); `ENVIAR_SENTENCIAS_A_LLM=false`, de modo que el índice B solo aporta estadísticas |
| No hay sentencias con menores | El juego y las lecciones salen de la ley; el clasificador se entrena con lo que haya; sentencias públicas del CENDOJ si las bases lo permiten |
| Las fechas o datos vienen borrados por la anonimización | Las estadísticas se limitan a tipos de caso, papel del menor y legibilidad |
| La voz falla en el navegador | Texto y lectura en voz alta; usar Chrome |
| El LLM tarda o falla | Caché de la demo, respuesta segura, respuestas más cortas |
| Falla la wifi del recinto | Datos móviles; todo en local |
| Falta tiempo | Recortar en este orden: ajuste fino del clasificador (queda la línea base) → evaluador NLI (pasa a rúbrica con LLM) → Mi situación con un solo papel → feedback y dashboard |
| Contenido jurídico incorrecto | Solo se publica lo validado y con fuente; repaso de 20 minutos antes de congelar |

---

## 22. Preguntas para los mentores (hoy)

1. ¿Qué documentos dan exactamente, en qué formato y hay casos con menores?
2. ¿Se pueden enviar a una API externa de IA aunque estén anonimizados?
3. ¿Cómo se entrega: repo, vídeo, demo en directo? ¿Hora exacta del pitch?
4. ¿Qué pesa más en cada premio?

---

## 23. Plantilla de `CLAUDE.md`

Copiad esto en `CLAUDE.md`, en la raíz del repo:

```markdown
# TuTurno · instrucciones para Claude Code

## Qué es
App para chicos y chicas de 12 a 18 años con tres módulos: el juego «Vive el caso», las lecciones «Aprende» y el agente de voz «Pregunta». La arquitectura completa está en docs/ARQUITECTURA.md.

## Reglas
- No cambies los contratos de la API (docs/ARQUITECTURA.md, sección 8) ni los esquemas de contenido (sección 9) sin avisar.
- A trabaja en app/. B trabaja en backend/, ml/ y content/. No toques la carpeta del otro sin avisar.
- Nunca subas .env, data/ ni artifacts/.
- El contenido jurídico solo se muestra si tiene "validado": true y fuente.
- El agente habla del proceso, nunca de los hechos, y nunca pregunta qué pasó.
- Sin cuentas ni datos personales. No guardes el texto de los usuarios en los logs.

## Flutter (app/)
- Riverpod para el estado, go_router para las rutas, http para la API.
- Interfaz TuTurnoApi con HttpTuTurnoApi y MockTuTurnoApi.
- Un directorio por funcionalidad en lib/features/.
- Accesibilidad: Semantics, tamaño de texto del sistema, zonas táctiles de 48 px.
- Comprobar con: flutter analyze

## Python (backend/ y ml/)
- FastAPI y Pydantic v2, con tipos en todas las funciones.
- La configuración solo se lee en app/config.py (.env).
- Los modelos se cargan una vez al arrancar.
- Comprobar con: ruff check . && pytest -q

## Comandos
- Backend: uvicorn app.main:app --reload --port 8000
- App: flutter run -d chrome --dart-define=API_URL=http://localhost:8000
- App sin backend: flutter run -d chrome --dart-define=USE_MOCK=true
- Contenido: python scripts/validate_content.py && ./scripts/sync_content.sh
```

---

## 24. Glosario técnico

| Término | Qué es |
|---|---|
| **RAG** | Recuperación aumentada: el LLM responde a partir de fragmentos que se buscan antes en una base de conocimiento |
| **Embeddings** | Vectores que representan el significado de un texto; permiten buscar por parecido |
| **BM25** | Búsqueda clásica por palabras; acierta con términos exactos |
| **RRF** | Fusión por rango recíproco: combina varias listas de resultados en una |
| **NLI** | Inferencia textual: decide si un texto implica, contradice o no tiene que ver con otro |
| **BKT** | Seguimiento bayesiano del conocimiento: estima la probabilidad de que un alumno domine un concepto |
| **F1 macro** | Media de la F1 de todas las clases, sin dar más peso a las frecuentes |
| **Recall@5** | Porcentaje de preguntas en las que el fragmento correcto aparece entre los 5 primeros |
| **MRR** | Media del inverso de la posición del primer fragmento correcto |
| **Kappa de Cohen** | Acuerdo entre dos evaluadores descontando el azar |
| **STT / TTS** | Voz a texto / texto a voz |
| **Fernández-Huerta** | Índice de legibilidad para textos en español: cuanto más alto, más fácil |
