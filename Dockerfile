# Backend de TuTurno para un Space Docker de Hugging Face (también sirve para `docker build .` en local).
#
# Contexto de build: la raíz del repo o la carpeta que monta backend/scripts/desplegar_hf.py, con
# backend/, content/ y el índice del RAG ya construido en artifacts/index (ml/ingest_leyes.py y
# ml/build_index.py). Si existe artifacts/models/guardrail, también entra; si no, el guardrail usa solo reglas.
# Los secretos (ELEVENLABS_API_KEY, GROQ_API_KEY...) NUNCA van en la imagen: el Space los inyecta como
# variables de entorno al arrancar (Settings → Variables and secrets). Pasos en backend/DESPLIEGUE.md.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Hugging Face ejecuta el contenedor con el uid 1000: se crea ese usuario antes de instalar o copiar nada.
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    VIRTUAL_ENV=/home/user/venv \
    PATH=/home/user/venv/bin:$PATH \
    HF_HOME=/home/user/.cache/huggingface
WORKDIR /home/user/app

# 1) torch solo para CPU. Desde PyPI llegaría la versión con CUDA (varios GB que un Space CPU no usa).
#    Versión probada con el backend; se puede cambiar con --build-arg TORCH_VERSION=...
ARG TORCH_VERSION=2.14.1
RUN python -m venv "$VIRTUAL_ENV" \
 && pip install "torch==${TORCH_VERSION}" --index-url https://download.pytorch.org/whl/cpu

# 2) El resto de dependencias. torch ya está instalado y cumple el requisito, así que pip no lo cambia.
COPY --chown=user backend/requirements.txt backend/requirements.txt
RUN pip install -r backend/requirements.txt

# 3) Modelo de embeddings del RAG descargado en la build, para que no se descargue en cada arranque.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('intfloat/multilingual-e5-base')"

# 4) Contenido, índice y código. .dockerignore solo deja pasar artifacts/index y artifacts/models/guardrail.
COPY --chown=user content/ content/
COPY --chown=user artifacts/ artifacts/
RUN [ -f artifacts/index/emb.npy ] && [ -f artifacts/index/trozos.jsonl ] && [ -d artifacts/index/bm25 ] \
 || { echo "Falta el índice del RAG en artifacts/index: ejecuta ml/ingest_leyes.py y ml/build_index.py"; exit 1; }
COPY --chown=user backend/ backend/

# Al arrancar no se consulta el Hub: el modelo ya está en la caché de la imagen.
# FORWARDED_ALLOW_IPS: uvicorn solo se fía de X-Forwarded-Proto/For si la conexión llega desde una red
# privada (el proxy de Hugging Face). Nunca '*': entonces tomaría la primera entrada de X-Forwarded-For,
# que la escribe el cliente (app/api/limites.py lee la IP de la última, la que añade el proxy).
ENV HF_HUB_OFFLINE=1 \
    TOKENIZERS_PARALLELISM=false \
    FORWARDED_ALLOW_IPS=127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7

WORKDIR /home/user/app/backend
EXPOSE 7860
# --proxy-headers: el HTTPS termina en el proxy de Hugging Face; así las URL que genere FastAPI salen en https.
# --no-access-log: el registro de accesos de uvicorn guardaría la IP de cada visitante (datos personales de
# menores). Los logs propios de la app (tuturno.*) no llevan IP ni texto del usuario.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860", "--proxy-headers", "--no-access-log"]
