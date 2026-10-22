# API del backend para la app

Contratos de `docs/ARQUITECTURA.md` (sección 8) tal y como están implementados. `POST /v1/chat/completions` (Custom LLM de ElevenLabs) no cambia: sigue con su secreto, sin límites y sin el filtro de orígenes.

## Errores (8.4)

Todos los endpoints de `/api/*` responden los errores así. `mensaje` siempre se puede enseñar tal cual a un chico o una chica de 11 años:

```json
{"error": {"codigo": "LLM_NO_DISPONIBLE", "mensaje": "No he podido responder ahora. Prueba otra vez o pulsa Ayuda."}}
```

| Estado | `codigo` | Cuándo |
|---|---|---|
| 403 | `ORIGEN_NO_PERMITIDO` | La petición trae `Origin` y no está en `ALLOWED_ORIGINS` ni en `ALLOWED_ORIGIN_REGEX` |
| 404 | `CONCEPTO_DESCONOCIDO` | `grade` con un `concepto_id` sin ideas clave |
| 422 | `PETICION_INVALIDA` | Cuerpo mal formado (pregunta vacía o de más de 2000 caracteres, `modo` desconocido…) |
| 429 | `DEMASIADAS_PETICIONES` | Límite por IP. Lleva `Retry-After` en segundos |
| 429 | `LIMITE_DIARIO` | Tope diario para todos. `Retry-After` hasta las 00:00 UTC |
| 500 | `ERROR_INTERNO` | Fallo inesperado |
| 502 | `ELEVENLABS_NO_DISPONIBLE` | ElevenLabs no responde o no da el token |
| 503 | `SIN_CONFIGURACION` | Faltan `ELEVENLABS_API_KEY` o `ELEVENLABS_AGENT_ID` |
| 503 | `LLM_NO_DISPONIBLE` | El LLM no responde (o falta `GROQ_API_KEY`). Se puede reintentar |

## `GET /api/session/token` (8.5)

Token de conversación (WebRTC) de corta duración para el agente privado. Para pedirlo, el backend llama a ElevenLabs (`GET https://api.elevenlabs.io/v1/convai/conversation/token?agent_id=…` con la cabecera `xi-api-key`) y solo devuelve el token:

```json
{"token": "<token de conversación>"}
```

La app lo usa así: `startSession(conversationToken: token, dynamicVariables: {...})`. Se pide un token nuevo para cada sesión. Si devuelve 503, 502 o 429, la app pasa al modo texto (`/api/agent/ask`).

`GET /api/session/signed-url` → `{"signed_url": "wss://…"}` se mantiene para el SDK de React. Los dos comparten el límite «sesion», porque cada uno abre una conversación que gasta créditos.

## `POST /api/agent/ask` (8.1, modo texto)

Lo usan la web (iPhone) y la APK cuando ElevenLabs falla. Tiene las mismas capas que la voz: guardrail → datos personales fuera → reformulación y RAG → generación → verificación frase a frase.

Petición (`perfil` es nuevo y opcional; son las mismas cuatro variables de 8.6 que van a la sesión de voz):

```json
{
  "pregunta": "Si tengo 13 años y hago algo malo, ¿me pueden juzgar?",
  "modo": "libre",
  "situacion": null,
  "historial": [{"rol": "usuario", "texto": "..."}, {"rol": "asistente", "texto": "..."}],
  "perfil": {"edad": "13", "procedimiento": "penal", "rol": "investigado", "fase": "no_lo_se"}
}
```

- `modo`: `"libre"` o `"situacion"`. `situacion`: `null`, `"testigo"`, `"victima"`, `"investigado"` (también vale `"escuchado_familia"`). En «Mi situación», ese papel manda sobre el `rol` del perfil.
- `perfil`: `"no_lo_se"` o `""` = sin dato; `"escuchado_familia"` = menor escuchado en un proceso de familia. Cualquier otro valor se ignora: no llega al prompt.
- `historial`: se usan los 4 últimos mensajes.

Respuesta:

```json
{
  "tipo": "normal",
  "respuesta": "Antes de los 14 años no te pueden juzgar en el juzgado de menores.\n\nSi tienes 14 o más...",
  "fuentes": [
    {"id": "LORPM-3", "titulo": "Régimen de los menores de catorce años", "norma": "LORPM", "articulo": "3",
     "url": "https://www.boe.es/buscar/act.php?id=BOE-A-2000-641#a3"}
  ],
  "sugerencias": [],
  "terminos": [],
  "latencia_ms": 2140
}
```

- `tipo`: `"normal"`, `"crisis"`, `"hechos"` o `"fuera_de_ambito"`. Si no es `normal`, `respuesta` es la plantilla fija de `content/seguridad.json` en versión para pantalla (sin etiquetas de voz y con los teléfonos en cifras: 900 20 20 10, 116 111, 112), y no se llama al LLM.
- `respuesta` se lee en pantalla: cifras y párrafos cortos separados por una línea en blanco (`\n\n`).
- `fuentes`: los artículos que el LLM dice haber usado (como mucho 4), solo si están entre los recuperados. Si el LLM no lo dice, salen los 2 primeros. `url` es nuevo y opcional: enlace al artículo en el BOE (o a la norma).
- `sugerencias` y `terminos` van vacíos. Para `hechos` y `fuera_de_ambito`, la app ya pone sus sugerencias.

## `POST /api/learn/grade` (8.2)

```json
{"concepto_id": "C-ser-oido", "texto": "Que el juez tiene que escucharte si tienes 12 años"}
```

```json
{
  "puntuacion": 0.67,
  "cubiertas": ["Tienes derecho a que te escuchen en lo que te afecta", "A partir de los 12 años se da por hecho que tienes madurez"],
  "faltan": ["Tu opinión se tiene en cuenta según tu edad y madurez"],
  "feedback": "¡Muy bien! Te falta una idea: tu opinión se tiene en cuenta según tu edad y madurez.",
  "tipo": "normal"
}
```

- **Campo nuevo `tipo`** (compatible hacia atrás): `"normal"` o `"crisis"`. Antes que nada se pasa el guardrail. Si el texto suena a crisis, no se corrige y la respuesta es `{"puntuacion": 0.0, "cubiertas": [], "faltan": [], "feedback": "<plantilla de ayuda con ANAR>", "tipo": "crisis"}`. La app debería enseñar la tarjeta de Ayuda y no tocar ni el dominio (BKT) ni los puntos.
- Hay un LLM que hace de juez, pero solo devuelve en JSON estricto los números de las ideas cubiertas. La puntuación (cubiertas / total) y el feedback salen de frases fijas, así que el LLM no puede comentar lo que ha escrito el alumno. Si el JSON no vale, se le pregunta una vez más; si vuelve a fallar, 503.
- Las ideas clave están en `content/evaluador.json` (copia de los «dilo» validados de la app). Si existe `content/ejercicios/*.json` (esquema 9.3), se lee primero. Si la app cambia un «dilo», hay que cambiarlo también aquí.

## Límites de peticiones

Afectan a `/api/session/*`, `/api/agent/ask` y `/api/learn/grade`. Los valores están en `app/config.py` y se pueden cambiar con variables de entorno (0 = sin límite):

| Grupo | Por IP (cada `LIMITE_VENTANA_S`=60 s) | Diario, para todos |
|---|---|---|
| sesion (token y signed-url) | `LIMITE_SESION_IP`=60 | `LIMITE_SESION_DIA`=500 |
| ask | `LIMITE_ASK_IP`=120 | `LIMITE_ASK_DIA`=3000 |
| grade | `LIMITE_GRADE_IP`=120 | `LIMITE_GRADE_DIA`=3000 |

- Por IP es una ventana deslizante en memoria (Hugging Face corre un solo contenedor). Las IPv6 se agrupan por /64.
- En la demo toda la sala sale por la IP de la wifi del evento, así que el límite por IP es el de la sala entera. Un aula de 30 personas, en el peor momento unas 3 preguntas por minuto cada una, son unas 90 por minuto: 120 deja margen. En sesiones de voz, 60 por minuto cubre a las 30 entrando a la vez y los reintentos.
- Los topes diarios protegen los créditos: cada pregunta son dos llamadas al LLM (unos 0,001 $ en el router de Hugging Face), así que 3000 preguntas son unos 3 $. El de sesiones es el mismo que el del agente de ElevenLabs (`call_limits.daily_limit`=500). Con 120 por minuto, una sola IP tardaría 25 minutos en agotar el tope diario de preguntas.
- Los contadores viven en memoria: se reinician a las 00:00 UTC y cada vez que se reinicia el Space.
- No se guardan IP: la clave es un resumen con una sal aleatoria por arranque, y en los logs solo salen 8 caracteres de ese resumen.

## IP real detrás de Hugging Face

Lo comprobamos el 22/10/2026 con Spaces públicos de httpbin (su `/ip` devuelve `X-Forwarded-For` tal cual le llega) y cabeceras falsificadas:

- El proxy de HF **añade la IP real al final** de `X-Forwarded-For` y **conserva delante** lo que mande el cliente. Si se envía `X-Forwarded-For: 203.0.113.7`, al contenedor le llega `203.0.113.7, <IP real>`. Esa última entrada coincide con la IP que firma el propio HF en `X-Ip-Token`.
- `X-Real-IP` y `Forwarded` llegan tal cual las escribe el cliente, así que no sirven.
- Por eso `app/api/limites.py` usa la última entrada (`PROXIES_DE_CONFIANZA=1`) y nadie puede saltarse el límite escribiendo la cabecera. `request.client.host` tampoco sirve: sin `--forwarded-allow-ips` es la IP interna del proxy, la misma para todos, y con `--forwarded-allow-ips='*'` uvicorn toma la **primera** entrada, que la escribe el cliente.
- Si el backend corre sin proxy (en local), hay que poner `PROXIES_DE_CONFIANZA=0`.

## Orígenes (CORS) en Hugging Face

El proxy de HF contesta él mismo al preflight (`OPTIONS`) y añade `Access-Control-Allow-Origin` con **cualquier** origen cuando la app no lo pone (comprobado). Si la app sí lo pone, el proxy no lo duplica. Por eso `CORSMiddleware` no basta para impedir que otra web use la API desde el navegador, y `limites.py` responde **403** si la petición trae un `Origin` no permitido. Las peticiones sin `Origin` (la APK, curl) pasan: contra los scripts protegen los límites. Por defecto se permiten `https://aliassdev.github.io` y localhost en cualquier puerto.

## Custom LLM de la voz (`POST /v1/chat/completions`)

El formato no cambia (Chat Completions de OpenAI en streaming, `data: {...}` y `data: [DONE]`). Lo que dice la voz:

- Si el último turno de la conversación no es del usuario (ElevenLabs le da la palabra al agente sin mensaje nuevo), el stream sale vacío y correcto: el agente no dice nada. Antes decía la respuesta segura y, si el mensaje anterior del usuario era de crisis, repetía la plantilla. Los mensajes de sistema no cuentan como turno.
- Si el guardrail dice «normal», el primer trozo es una frase puente («Vale, te lo explico.» o «Vale, te cuento.»), que sale en milisegundos, antes de reformular, buscar y generar. El prompt avisa al LLM y, si aun así abre con una muletilla, se quita. No sale en crisis, hechos ni fuera de ámbito, ni con saludos o agradecimientos cortos. Se desactiva con `VOZ_FRASE_PUENTE=false`.
- Sin corchetes: las etiquetas de tono de las plantillas (`[slow]`) y cualquier cosa entre corchetes de lo generado se quitan, porque `eleven_flash_v2_5` las leería (`TTS_ETIQUETAS=true` las deja).
- Si el LLM falla o se pasa del plazo (`LLM_PLAZO_VOZ_S`, 7 s contando el respaldo), la respuesta segura. Detrás de la frase puente empieza por «Perdona, …».
- Cabeceras `Cache-Control: no-cache` y `X-Accel-Buffering: no`, para que ningún proxy acumule el SSE.

## Privacidad de los logs

- Nunca va al log el texto del usuario. Tampoco la consulta jurídica reformulada (es una paráfrasis de la pregunta): solo si la hay.
- Tampoco van la API key, el `agent_id` ni el token. httpx queda en WARNING porque registra las URL y la del token lleva el `agent_id`.
- De los errores del proveedor solo se escribe el principio (`LLM 429`): en modo JSON, Groq devuelve en el cuerpo lo que había generado el modelo. Los fallos del LLM salen como `LLM principal (router.huggingface.co) ha fallado: LLM 429`, con el host y nunca la clave.
- Las líneas de acceso de uvicorn salen sin IP (filtro en `app/main.py`). El Dockerfile, además, arranca con `--no-access-log`.
