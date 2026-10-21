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


@dataclass(frozen=True)
class Settings:
    elevenlabs_api_key: str = os.getenv("ELEVENLABS_API_KEY", "")
    elevenlabs_agent_id: str = os.getenv("ELEVENLABS_AGENT_ID", "")
    custom_llm_secret: str = os.getenv("CUSTOM_LLM_SECRET", "")
    allowed_origins: tuple[str, ...] = tuple(
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "http://localhost:5173").split(",") if o.strip()
    )
    debug_llm_requests: bool = _bool("DEBUG_LLM_REQUESTS")
    content_dir: Path = _ruta("CONTENT_DIR", "../content")
    guardrail_modelo_dir: Path = _ruta("GUARDRAIL_MODELO_DIR", "../artifacts/models/guardrail")
    guardrail_umbral_crisis: float = float(os.getenv("GUARDRAIL_UMBRAL_CRISIS", "0.30"))
    guardrail_umbral_otros: float = float(os.getenv("GUARDRAIL_UMBRAL_OTROS", "0.50"))
    rag_index_dir: Path = _ruta("RAG_INDEX_DIR", "../artifacts/index")
    # LLM: cualquier API compatible con OpenAI. Por defecto, Groq (nivel gratuito).
    llm_base_url: str = os.getenv("LLM_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
    llm_api_key: str = os.getenv("LLM_API_KEY") or os.getenv("GROQ_API_KEY", "")
    llm_modelo: str = os.getenv("LLM_MODELO", "openai/gpt-oss-120b")
    llm_modelo_reformular: str = os.getenv("LLM_MODELO_REFORMULAR", "openai/gpt-oss-20b")


settings = Settings()
