# Despliegue del backend en Hugging Face Spaces

Objetivo: que el backend funcione siempre y para cualquiera, sin depender de un portátil ni de un túnel.

- **Backend**: un Space Docker de Hugging Face (cuenta PRO de Jorge), con la imagen del `Dockerfile` de la raíz.
- **Android (APK)**: voz con el agente de ElevenLabs, que pasa a ser **privado**. La app pide antes de cada sesión un token de corta duración a `GET /api/session/token`. El `agent_id` se puede sacar de una APK pública, y la lista de dominios permitidos solo protege la web.
- **iPhone (web)**: modo texto, `POST /api/agent/ask` (contrato 8.1), contra el mismo pipeline, con la voz del navegador. Es también el respaldo de Android si falla ElevenLabs.

Comandos desde `backend/` con el venv del backend (en Windows, `.venv/Scripts/python` en vez de `.venv/bin/python`).

## 0. Lo que tiene que hacer una persona

| Quién | Qué |
|---|---|
| Jorge | Cuenta de Hugging Face con PRO. Crear el Space vacío en la web (New Space → SDK Docker → Blank → visibilidad **Protected**) y un token **fine-grained** con escritura solo en ese Space (Settings → Access Tokens) |
| Iker | `backend/.env` con `ELEVENLABS_API_KEY`, `ELEVENLABS_AGENT_ID`, `GROQ_API_KEY` y un `CUSTOM_LLM_SECRET` **no vacío** (por ejemplo, `python -c "import secrets; print(secrets.token_urlsafe(32))"`) |
| Los dos | Decidir el nombre del Space, por ejemplo `aliassdev/tuturno-api` (URL: `https://aliassdev-tuturno-api.hf.space`) |

Las claves de ElevenLabs y Groq no tienen por qué salir del portátil de Iker: Jorge le pasa el token de Hugging Face por un canal privado (nunca por git ni por el chat del equipo), Iker hace `hf auth login` con él y ejecuta los pasos 3 y 4. El token se revoca después.

## 1. Índice del RAG con las 12 normas y las fuentes validadas

`artifacts/` no está en git: quien despliega tiene que tener el índice construido.

```bash
cd ..   # raíz del repo
backend/.venv/bin/python -X utf8 ml/ingest_leyes.py   # 12 normas (3012 artículos, 3841 trozos) + glosario (42) + marco legal (92): 3975 trozos
backend/.venv/bin/python -X utf8 ml/build_index.py    # unos 4 minutos en CPU
backend/.venv/bin/python -X utf8 ml/eval_rag.py --pausa 0.2   # opcional: métricas del RAG (con el router basta esa pausa)
cd backend
```

Las fuentes validadas salen de `content/glosario.json` (copia del glosario validado de la app, esquema 9.6) y de `content/marco_legal.json` (las citas literales de `docs/MARCO_LEGAL.md`). Si cambia alguno de los dos, copia el glosario de la app (`app/assets/mock/content/glosario.json`) o regenera el marco legal con `backend/.venv/bin/python -X utf8 ml/fuentes_validadas.py --marco ruta/a/docs/MARCO_LEGAL.md`, y vuelve a construir el índice. Las ideas clave de «Dilo con tus palabras» se copian igual: `backend/scripts/sincronizar_evaluador.py ruta/a/app/assets/mock/content/ejercicios`.

Si existe `artifacts/models/guardrail` (BETO entrenado con `ml/train_guardrail.py`), también se despliega. Si no, el guardrail funciona solo con reglas.

## 2. Montar y revisar la carpeta del Space

```bash
.venv/bin/python scripts/desplegar_hf.py aliassdev/tuturno-api --solo-carpeta --origenes https://aliassdev.github.io
```

Monta `artifacts/space/` (Dockerfile, README del Space, `backend/app`, `content/` y el índice, unos 18 MB) y enseña las variables y los secretos que necesita el Space. No sube nada ni imprime ninguna clave. Ningún `.env` entra en la carpeta: si se colara uno, el script borra la carpeta y para.

## 3. Crear el Space, subir la configuración y el código

```bash
hf auth login   # una vez, con el token de escritura
.venv/bin/python scripts/desplegar_hf.py aliassdev/tuturno-api --subir-secretos --origenes https://aliassdev.github.io
```

- Si el Space ya existe (creado en la web), solo lo actualiza. Si no, lo crea con SDK Docker y visibilidad **protected** (código privado y API pública en `*.hf.space`); para eso hace falta un token que pueda crear repos. Nunca `private`: ElevenLabs y la app no podrían llamar a la API.
- `--subir-secretos` lee `backend/.env` y sube como **secretos** `ELEVENLABS_API_KEY`, `ELEVENLABS_AGENT_ID`, `GROQ_API_KEY` (o `LLM_API_KEY`) y `CUSTOM_LLM_SECRET`. Como **variables** públicas sube `ALLOWED_ORIGINS`, `DEBUG_LLM_REQUESTS=false` y los límites de `app/config.py` (`LIMITE_*` y `PROXIES_DE_CONFIANZA`), con el valor de `.env` o el de `config.py`. Se suben antes que el código, para que la primera build ya los tenga.
- Sin `--subir-secretos`, ponlos a mano en Settings → Variables and secrets. Las claves van siempre como secretos, nunca como variables (las variables son públicas).
- La subida reconstruye la imagen: unos 10 minutos (torch para CPU y el modelo multilingual-e5-base, 1,1 GB, se descargan durante la build). La imagen ocupa unos 2,9 GB sin comprimir. Logs: `https://huggingface.co/spaces/aliassdev/tuturno-api?logs=build`.
- Cada build instala las mismas versiones: `pip install -r requirements.txt -c constraints.txt`. `backend/constraints.txt` fija con `==` todo lo que instala `requirements.txt` (también las dependencias de las dependencias) con las versiones probadas (Python 3.12, Linux). Si cambias `requirements.txt`, regenéralo como dice su cabecera.
- Para actualizar el backend más adelante, repite este comando (sin `--subir-secretos` si no han cambiado). El Space queda igual que la carpeta.

## 4. Comprobar el Space

```bash
URL=https://aliassdev-tuturno-api.hf.space
curl $URL/api/health                                  # {"estado":"ok"}
curl -s -o /dev/null -w '%{http_code}\n' -X POST $URL/v1/chat/completions -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hola"}]}'   # 401 sin secreto
SECRETO=$(grep '^CUSTOM_LLM_SECRET=' .env | cut -d= -f2-)   # no se imprime
curl -N -X POST $URL/v1/chat/completions -H "Authorization: Bearer $SECRETO" -H 'Content-Type: application/json' \
  -d '{"stream":true,"messages":[{"role":"system","content":"Perfil: edad=13; procedimiento=penal; rol=victima; fase=antes."},{"role":"user","content":"¿Puedo ir con alguien cuando declare?"}]}'
curl -X POST $URL/api/agent/ask -H 'Content-Type: application/json' \
  -d '{"pregunta":"¿Puedo ir con alguien cuando declare?","modo":"libre","situacion":"victima","historial":[]}'
```

La respuesta en streaming tiene que llegar en trozos `data: {...}` y acabar en `data: [DONE]`: comprueba así que el proxy de Hugging Face no corta el SSE, que era el problema del túnel rápido de Cloudflare. En los logs del Space (pestaña Logs) no debe aparecer el texto de las preguntas ni ninguna IP: uvicorn arranca con `--no-access-log` y la app solo registra categorías, fuentes y latencias.

## 5. Agente de ElevenLabs: Custom LLM en el Space y agente protegido

1. Si el agente no existe, o no tiene el secreto del Custom LLM, créalo o actualízalo apuntando al Space:
   ```bash
   .venv/bin/python scripts/setup_agent.py https://aliassdev-tuturno-api.hf.space
   ```
2. Revisa el cambio (no toca nada; solo lee el agente) y aplícalo:
   ```bash
   .venv/bin/python scripts/proteger_agente.py --custom-llm-url https://aliassdev-tuturno-api.hf.space
   .venv/bin/python scripts/proteger_agente.py --custom-llm-url https://aliassdev-tuturno-api.hf.space --aplicar
   ```
   - `platform_settings.auth.enable_auth = true` hace privado el agente: solo se abre una conversación con un token del backend.
   - `call_limits` pone 5 conversaciones a la vez y 200 al día, sin «bursting» (cambia con `--simultaneas` y `--diarias`). Para un día de demo con público, al menos `--simultaneas 10 --diarias 500` (lo que tiene ahora el agente): con 5, la sexta persona que abra la voz a la vez se queda fuera. El backend tiene además su propio tope (`LIMITE_SESION_DIA=500`).
   - `privacy` pone retención de 0 días, sin grabar voz y borrando audio y transcripción. ElevenLabs borra de forma programada, no al instante. `--aplicar-a-existentes` borra también lo ya guardado.
   - El script vuelve a leer el agente y comprueba campo a campo. Avisa si el agente deja que el cliente cambie el prompt o el LLM (overrides): eso se desactiva en el panel.
3. **Coordinación con la app (A):** con el agente privado, una sesión abierta solo con el `agent_id` deja de funcionar. Aplica el paso 2 cuando la APK ya pida el token a `GET /api/session/token`. Mientras tanto, el modo texto sigue funcionando.

## 6. Comprobación final

```bash
.venv/bin/python scripts/probar_agente.py --perfil "edad=13;procedimiento=penal;rol=victima;fase=antes" "¿Puedo ir con alguien cuando declare?"
curl -s https://aliassdev-tuturno-api.hf.space/api/session/token | python -c "import json,sys; print('token' in json.load(sys.stdin))"   # True
```

`probar_agente.py` abre una sesión real (gasta créditos de ElevenLabs) y su respuesta tiene que venir del Space: en sus logs aparece la petición del Custom LLM con el perfil y las fuentes. Por último, la app: `--dart-define=API_URL=https://aliassdev-tuturno-api.hf.space` en la APK y `{"api_url": "https://aliassdev-tuturno-api.hf.space"}` en `web/config.json` (lo hace A).

## 7. Que funcione siempre

- **Sueño.** En CPU basic (gratis) el Space se duerme tras 48 horas sin visitas y se despierta con la primera petición, que tarda uno o dos minutos. Antes de la demo, abre `/api/health` unos minutos antes. Para los días del evento: `--hardware cpu-upgrade` (8 vCPU, 0,03 $/hora, no se duerme) y después vuelve a `cpu-basic` desde Settings. Con 8 vCPU la parte de CPU del RAG va unas 3 veces más rápida (ver «Concurrencia»).
- **Reinicios.** Al cambiar secretos o variables en Settings, reinicia el Space (Settings → Restart) si no lo hace solo. El disco del contenedor no persiste, pero el backend no guarda nada.
- **Límites.** Por defecto están pensados para la demo, con toda la sala detrás de la IP de la wifi del evento: 120 preguntas y 120 correcciones por minuto y por IP, 60 sesiones de voz por minuto y por IP, y topes diarios de 3000, 3000 y 500 (el porqué, en `app/config.py` y `API.md`). Si aun así aparecen respuestas 429, súbelos en Settings → Variables (`LIMITE_*`) sin reconstruir la imagen: solo hace falta reiniciar. Ojo: reiniciar también pone a cero los contadores.
- **LLM de respaldo.** Si el LLM principal da 429, 5xx, timeout o fallo de conexión, se prueba el respaldo, y durante 30 s va primero (así una caída no cuesta el timeout en cada llamada). Sin cambiar de clave, el mismo router con otro proveedor: variables `LLM_RESPALDO_BASE_URL=https://router.huggingface.co/v1` y `LLM_RESPALDO_MODELO=openai/gpt-oss-120b:groq` (sin `LLM_RESPALDO_API_KEY` se usa `LLM_API_KEY`, porque la URL es la misma). Para cubrir también una caída del router: Groq directo, con `LLM_RESPALDO_API_KEY` como **secreto**. En el Space `itsmedelatorre/tuturno-backend` está puesto el respaldo por el router (`:groq`), sin secreto nuevo.
- **Modelo de la reformulación.** En el router, `LLM_MODELO_REFORMULAR=openai/gpt-oss-120b` (Cerebras, el mismo que genera; puesto en el Space). Frente al 20b (Groq): algo más rápido con una sola pregunta (texto p50 0,77 s frente a 0,86 s), mucho más con 30 a la vez (2,8 s frente a 4,1 s), determinista (la misma pregunta da siempre la misma consulta jurídica y aprovecha la caché del codificador) y en otro proveedor que el respaldo (`:groq`), así que una caída de Groq no le afecta. En calidad, empate con el conjunto de referencia (48 preguntas): Acierto@5 0,729 frente a 0,69-0,71, Recall@5 0,552 frente a 0,55-0,57 y MRR@10 0,524 frente a 0,56-0,58 (sin reformular: 0,438 / 0,316 / 0,362).
- **Concurrencia.** Las consultas del modo denso se codifican por lotes desde un solo hilo (`Codificador` en `app/rag/retrieve.py`), con una caché de 512 vectores por resumen SHA-256 del texto (nunca el texto). En el Space (cpu-basic, 2 vCPU), 30 preguntas distintas a la vez: primera frase de la voz en p50 2,9 s (antes 6,2 s) y texto en p50 2,9 s; con las preguntas de ejemplo de la app repetidas, p50 1,7 s; 10 a la vez, p50 0,8 s, como una sola. Con 8 vCPU (emulado en local) la parte de CPU de 30 preguntas a la vez baja de 2,3 s a 0,76 s.
- **Plazos.** Contando el respaldo: `LLM_PLAZO_VOZ_S=7` hasta el primer texto de la voz, `LLM_PLAZO_TEXTO_S=14` para la respuesta del modo texto (la app espera 20 s) y `REFORMULAR_PLAZO_S=2` para la reformulación (si tarda más, se busca solo con la pregunta). Pasado el plazo, la voz dice la respuesta segura y el modo texto devuelve 503; nunca se queda callado.
- **Frase puente.** Con el guardrail en «normal», la voz empieza al instante con «Vale, te lo explico.» o «Vale, te cuento.» mientras se reformula, se busca y se genera (`VOZ_FRASE_PUENTE=false` la quita). No sale en crisis, hechos ni fuera de ámbito, ni con un saludo o un «gracias».
- **ElevenLabs y su LLM de respaldo.** El agente TuTurno tiene `backup_llm_config: {"preference": "disabled"}` (comprobado el 22/10/2026) y `cascade_timeout_seconds: 4`: si el Custom LLM falla, ElevenLabs no contesta con su propio LLM, que no tendría guardrail, RAG ni verificación. No hay que cambiarlo nunca a `default` (ni tocar otro agente de la cuenta).
- **Créditos del router de Hugging Face.** La cuenta va en prepago: sin saldo, el router devuelve `402` («You have no remaining credits»), la voz dice siempre la respuesta segura y el modo texto devuelve 503. Pasó el 22/10/2026 hacia las 12:00, y el Space quedó en pausa (`PAUSED`). Antes de la demo: saldo en https://huggingface.co/settings/billing, reiniciar el Space y comprobar una pregunta real (no basta con `/api/health`, que no llama al LLM). Para no depender de un solo proveedor: `LLM_RESPALDO_BASE_URL`/`LLM_RESPALDO_MODELO` de Groq directo con `LLM_RESPALDO_API_KEY` como secreto.
- **Etiquetas de voz.** La voz `eleven_flash_v2_5` no entiende etiquetas como `[slow]` y las leería: con `TTS_ETIQUETAS=false` (por defecto) se quitan de las plantillas y de lo generado. Ponlo a `true` solo con una voz que las interprete (`eleven_v3`).

### Latencia medida (22/10/2026)

En local, con el modelo real por el router de Hugging Face (`openai/gpt-oss-120b`, que sirve Cerebras; la reformulación con `openai/gpt-oss-20b`, que sirve Groq) y el índice de 12 normas: 8 preguntas de los casos de Lucía, Sergio y Sara, 3 rondas (24 medidas por fila). Voz: `/v1/chat/completions` en streaming, con el secreto; texto: `/api/agent/ask`.

| | Antes (sin `include_reasoning`) | Ahora | Ahora, reformulando con el 120b |
|---|---|---|---|
| Voz: primer texto | p50 1,32 s · máx 2,37 s | p50 0,001 s · máx 0,005 s (frase puente) | p50 0,002 s · máx 0,007 s |
| Voz: primera frase de la respuesta | p50 1,32 s · máx 2,37 s | p50 1,03 s · máx 1,47 s | p50 0,73 s · máx 1,03 s |
| Texto: respuesta completa | p50 1,43 s · máx 1,84 s | p50 1,16 s · máx 1,72 s | p50 0,94 s · máx 1,26 s |

- Tal cual estaba, con el router no funcionaba: Cerebras rechaza `include_reasoning` con un 400, así que la voz decía siempre la respuesta segura y el modo texto devolvía 503. Ahora ese parámetro solo va a Groq.
- Lo que más pesa son las dos llamadas al LLM (reformulación y respuesta). En el router, el 120b (Cerebras) contesta antes que el 20b (Groq): `LLM_MODELO_REFORMULAR=openai/gpt-oss-120b` (−0,3 s en voz y texto en local; en el Space, ver «Modelo de la reformulación»).
- Con el principal colgado y el respaldo configurado, solo la primera pregunta tarda (4,5 s hasta la primera frase); las siguientes van directas al respaldo (p50 1,35 s). Sin respaldo, la respuesta segura llega a los 6 s.
- 24 peticiones a la vez (12 de voz y 12 de texto): ningún fallo; la frase puente sale en 0,1 s como mucho, la primera frase de la respuesta en p50 2,05 s (máx. 2,35 s) y el texto en p50 2,06 s (máx. 2,54 s).
- Ganancias en el código: conexión persistente con el proveedor (~0,1 s por llamada), reformulación en paralelo con la búsqueda de la pregunta, OpenBLAS con un hilo y torch con las CPU reales del contenedor (la búsqueda con las dos consultas bajó de 270 ms a 50 ms en una máquina de 32 núcleos) y más hilos para atender a la vez (`HILOS_MAX=100`).

### En el Space, de punta a punta (22/10/2026)

Space `itsmedelatorre/tuturno-backend` en cpu-basic (2 vCPU; en el log, «torch con 2 hilos»), con respaldo por el router y la reformulación con el 120b. Medido desde España.

| | p50 | máx | n |
|---|---|---|---|
| Voz (`/v1/chat/completions`): primer trozo (frase puente) | 0,23 s | 0,43 s | 24 |
| Voz: primera frase de la respuesta | 0,77 s | 2,29 s | 24 |
| Texto (`/api/agent/ask`): respuesta completa | 0,77 s | 1,26 s | 24 |
| Agente de ElevenLabs (WebSocket, solo texto): primer audio desde el envío | 0,44 s | 0,61 s | 18 |
| Agente: audio de la respuesta, detrás de la frase puente | 1,13 s | 1,68 s | 18 |
| Agente: `agent_response` (texto completo) | 1,91 s | 2,31 s | 18 |

- Ningún fallo en más de 350 peticiones (sin contar las ráfagas para provocar el 429). En las conversaciones con el agente: ningún hueco de audio de 0,25 s o más (la frase puente suena mientras llega la respuesta), ninguna interrupción ni corrección, ninguna respuesta segura y ningún cierre inesperado.
- En el servidor, la primera frase verificada sale en p50 0,5-0,65 s desde la pregunta. El resto es la red y ElevenLabs.
- Comprobado también: 401 sin el secreto, 403 con un origen no permitido, 200 en `/api/session/token` y `/api/session/signed-url`, 429 con `Retry-After` al pasar de 120 preguntas por minuto desde una IP, plantilla de crisis sin LLM y ningún texto de usuario ni IP en los logs.

## 8. Problemas frecuentes

| Síntoma | Causa probable |
|---|---|
| La build falla | Mira el log de build. Falta `artifacts/index` en la carpeta (paso 1) o una dependencia nueva no tiene rueda para Linux (se instala sin compilar) |
| El agente no contesta y el Space registra 401 | El secreto del Custom LLM en ElevenLabs no coincide con `CUSTOM_LLM_SECRET` del Space |
| La web recibe 403 | Su dominio no está en `ALLOWED_ORIGINS` |
| `/api/session/token` devuelve 503 | Faltan `ELEVENLABS_API_KEY` o `ELEVENLABS_AGENT_ID` en los secretos del Space |
| La primera respuesta tarda | El Space estaba dormido (sección 7) |
| La voz contesta siempre «Ahora mismo no he podido responderte» | El LLM falla: en los logs, `LLM principal (...) ha fallado: LLM 401` (clave), `LLM 400` (modelo o parámetro) o `sin respuesta` (red). Configura el respaldo (sección 7) |
| La voz lee «slow» o lo que va entre corchetes | `TTS_ETIQUETAS=true` con una voz que no entiende etiquetas |

## 9. Lo que nunca hay que hacer

- Subir `.env`, `data/` o `artifacts/` a git, o poner una clave como variable (las variables son públicas).
- Dejar `CUSTOM_LLM_SECRET` vacío en el Space: `/v1/chat/completions` quedaría abierto y cualquiera gastaría el LLM.
- Arrancar uvicorn con `--forwarded-allow-ips '*'`: tomaría como IP del cliente la que escribe el propio cliente. El Dockerfile solo confía en redes privadas (`FORWARDED_ALLOW_IPS`).
- Hacer el Space `private`: ElevenLabs y la app recibirían 404.
