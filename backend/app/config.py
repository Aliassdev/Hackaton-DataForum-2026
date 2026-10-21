import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes")


@dataclass(frozen=True)
class Settings:
    elevenlabs_api_key: str = os.getenv("ELEVENLABS_API_KEY", "")
    elevenlabs_agent_id: str = os.getenv("ELEVENLABS_AGENT_ID", "")
    custom_llm_secret: str = os.getenv("CUSTOM_LLM_SECRET", "")
    allowed_origins: tuple[str, ...] = tuple(
        o.strip() for o in os.getenv("ALLOWED_ORIGINS", "http://localhost:5173").split(",") if o.strip()
    )
    debug_llm_requests: bool = _bool("DEBUG_LLM_REQUESTS")


settings = Settings()
