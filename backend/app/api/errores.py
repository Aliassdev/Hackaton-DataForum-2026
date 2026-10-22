"""Errores de la API con el formato de la sección 8.4: {"error": {"codigo": "...", "mensaje": "..."}}.

El mensaje siempre se puede enseñar a un chico o una chica de 11 años: la app lo muestra tal cual.
/v1/chat/completions no los usa (lo llama ElevenLabs, no la app) y sigue con los errores de FastAPI.
"""

import traceback

from fastapi import Request
from fastapi.exception_handlers import request_validation_exception_handler
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.llm.client import ErrorLLM

MENSAJE_SEGURO = "No he podido responder ahora. Prueba otra vez o pulsa Ayuda."
MENSAJE_PETICION_INVALIDA = "No he podido leer tu mensaje. Prueba a escribirlo de otra forma o más corto."


class ErrorApi(Exception):
    def __init__(self, estado: int, codigo: str, mensaje: str = MENSAJE_SEGURO, cabeceras: dict[str, str] | None = None):
        super().__init__(codigo)
        self.estado = estado
        self.codigo = codigo
        self.mensaje = mensaje
        self.cabeceras = cabeceras


def cuerpo_error(codigo: str, mensaje: str) -> dict:
    return {"error": {"codigo": codigo, "mensaje": mensaje}}


def resumen_error(e: BaseException) -> str:
    """Para el log: «ErrorLLM: LLM 429» o el tipo de la excepción. Nunca el cuerpo que devuelve el proveedor
    (en modo JSON, Groq incluye ahí lo que había generado el modelo, que puede repetir el texto del usuario)
    ni el mensaje de una excepción cualquiera; sí el archivo y la línea donde ocurrió."""
    if isinstance(e, ErrorLLM):
        return f"ErrorLLM: {str(e).split(':')[0][:80]}"
    pila = traceback.extract_tb(e.__traceback__)
    donde = f" en {pila[-1].filename.rsplit('/', 1)[-1]}:{pila[-1].lineno}" if pila else ""
    return f"{type(e).__name__}{donde}"


async def manejar_error_api(_: Request, exc: ErrorApi) -> JSONResponse:
    return JSONResponse(cuerpo_error(exc.codigo, exc.mensaje), status_code=exc.estado, headers=exc.cabeceras)


async def manejar_validacion(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Cuerpo mal formado en /api/*: formato 8.4. En el resto (el Custom LLM), el error normal de FastAPI."""
    if request.url.path.startswith("/api/"):
        return JSONResponse(cuerpo_error("PETICION_INVALIDA", MENSAJE_PETICION_INVALIDA), status_code=422)
    return await request_validation_exception_handler(request, exc)
