import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

BACKEND_DIR = Path(__file__).resolve().parent.parent


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes")


def _ruta(name: str, default: str) -> Path:
    """Rutas relativas a backend/, para que no dependan del directorio desde el que se arranca."""
    return (BACKEND_DIR / os.getenv(name, default)).resolve()


def _int(name: str, default: int) -> int:
    return int(os.getenv(name, str(default)).strip() or default)


@dataclass(frozen=True)
class Settings:
    elevenlabs_api_key: str = os.getenv("ELEVENLABS_API_KEY", "")
    elevenlabs_agent_id: str = os.getenv("ELEVENLABS_AGENT_ID", "")
    custom_llm_secret: str = os.getenv("CUSTOM_LLM_SECRET", "")
    # Orígenes web permitidos: la versión web (GitHub Pages, la que se usa en iPhone) y, con la expresión
    # regular, cualquier puerto de localhost (flutter run -d chrome elige uno al azar). La APK no manda Origin.
    allowed_origins: tuple[str, ...] = tuple(
        o.strip()
        for o in os.getenv("ALLOWED_ORIGINS", "https://aliassdev.github.io,http://localhost:5173").split(",")
        if o.strip()
    )
    allowed_origin_regex: str = os.getenv("ALLOWED_ORIGIN_REGEX", r"https?://(localhost|127\.0\.0\.1)(:\d+)?")
    debug_llm_requests: bool = _bool("DEBUG_LLM_REQUESTS")
    content_dir: Path = _ruta("CONTENT_DIR", "../content")  # noqa: RUF009 - Path es inmutable
    guardrail_modelo_dir: Path = _ruta("GUARDRAIL_MODELO_DIR", "../artifacts/models/guardrail")  # noqa: RUF009 - Path es inmutable
    guardrail_umbral_crisis: float = float(os.getenv("GUARDRAIL_UMBRAL_CRISIS", "0.30"))
    guardrail_umbral_otros: float = float(os.getenv("GUARDRAIL_UMBRAL_OTROS", "0.50"))
    rag_index_dir: Path = _ruta("RAG_INDEX_DIR", "../artifacts/index")  # noqa: RUF009 - Path es inmutable
    # LLM: cualquier API compatible con OpenAI. Por defecto, Groq (nivel gratuito).
    llm_base_url: str = os.getenv("LLM_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
    llm_api_key: str = os.getenv("LLM_API_KEY") or os.getenv("GROQ_API_KEY", "")
    llm_modelo: str = os.getenv("LLM_MODELO", "openai/gpt-oss-120b")
    llm_modelo_reformular: str = os.getenv("LLM_MODELO_REFORMULAR", "openai/gpt-oss-20b")
    # Juez de «Dilo con tus palabras» (POST /api/learn/grade). Por defecto, el mismo que genera las respuestas.
    llm_modelo_evaluar: str = os.getenv("LLM_MODELO_EVALUAR") or os.getenv("LLM_MODELO", "openai/gpt-oss-120b")

    # Límites de peticiones (app/api/limites.py) para /api/session/*, /api/agent/ask y /api/learn/grade.
    # Por IP: ventana deslizante en memoria (Hugging Face corre un solo contenedor). Generosos porque el jurado
    # y el público pueden compartir la wifi del evento, es decir, una sola IP pública.
    # Diario: total para todos, se reinicia a las 00:00 UTC. Protege los créditos de ElevenLabs y el nivel
    # gratuito de Groq (unas 1000 peticiones al día por modelo). 0 = sin límite.
    limite_ventana_s: int = _int("LIMITE_VENTANA_S", 60)
    limite_sesion_ip: int = _int("LIMITE_SESION_IP", 10)
    limite_sesion_dia: int = _int("LIMITE_SESION_DIA", 200)
    limite_ask_ip: int = _int("LIMITE_ASK_IP", 20)
    limite_ask_dia: int = _int("LIMITE_ASK_DIA", 1000)
    limite_grade_ip: int = _int("LIMITE_GRADE_IP", 20)
    limite_grade_dia: int = _int("LIMITE_GRADE_DIA", 1000)
    # Proxies delante del backend que añaden una entrada al final de X-Forwarded-For. Hugging Face Spaces
    # añade exactamente una, la IP real del cliente, y conserva delante lo que mande el cliente (comprobado).
    # 0 = sin proxy: se usa la IP de la conexión.
    proxies_de_confianza: int = _int("PROXIES_DE_CONFIANZA", 1)


settings = Settings()
