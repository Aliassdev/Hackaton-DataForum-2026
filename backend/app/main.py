import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.agent.evaluador import conceptos
from app.agent.safety import get_guardrail
from app.api import agent, health, learn, llm, session
from app.api.errores import ErrorApi, manejar_error_api, manejar_validacion
from app.config import settings
from app.rag.retrieve import get_recuperador

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
# httpx registra cada petición con su URL a nivel INFO, y la del token de ElevenLabs lleva el agent_id.
logging.getLogger("httpx").setLevel(logging.WARNING)


class SinIpEnAccesos(logging.Filter):
    """uvicorn escribe la IP del cliente en cada línea de acceso: se quita (es un dato personal).
    Se mantienen el método, la ruta y el código de estado."""

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.args, tuple) and len(record.args) == 5:
            record.args = ("-", *record.args[1:])
        return True


logging.getLogger("uvicorn.access").addFilter(SinIpEnAccesos())


@asynccontextmanager
async def lifespan(_: FastAPI):
    get_guardrail()  # los modelos se cargan una sola vez, al arrancar
    get_recuperador()
    conceptos()
    yield


app = FastAPI(title="TuTurno backend", lifespan=lifespan)
# En Hugging Face el proxy contesta él mismo al preflight y refleja cualquier origen: el filtro real de
# orígenes está en app/api/limites.py. CORS sigue haciendo falta en local y fuera de HF.
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.allowed_origins),
    allow_origin_regex=settings.allowed_origin_regex or None,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)
app.add_exception_handler(ErrorApi, manejar_error_api)
app.add_exception_handler(RequestValidationError, manejar_validacion)

app.include_router(health.router)
app.include_router(session.router)
app.include_router(agent.router)
app.include_router(learn.router)
app.include_router(llm.router)
