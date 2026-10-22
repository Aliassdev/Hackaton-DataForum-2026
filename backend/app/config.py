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


def _float(name: str, default: float) -> float:
    return float(os.getenv(name, str(default)).strip() or default)


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
    # Respaldo opcional (app/llm/client.py): si el principal da 429, 5xx, timeout o fallo de conexión, se prueba este
    # antes de rendirse. Por ejemplo, Groq (https://api.groq.com/openai/v1) o el mismo router de Hugging Face con
    # otro proveedor (LLM_RESPALDO_MODELO=openai/gpt-oss-120b:groq). Sin LLM_RESPALDO_API_KEY se usa LLM_API_KEY,
    # pero solo si la URL es la misma que la del principal (la clave nunca va a otro servidor).
    llm_respaldo_base_url: str = os.getenv("LLM_RESPALDO_BASE_URL", "").strip().rstrip("/")
    llm_respaldo_api_key: str = os.getenv("LLM_RESPALDO_API_KEY", "").strip()
    llm_respaldo_modelo: str = os.getenv("LLM_RESPALDO_MODELO", "").strip()
    # Plazos en segundos, contando el respaldo, para que un fallo del proveedor no deje al agente callado.
    # Voz: hasta el primer texto de la respuesta (la frase puente sale antes, en milisegundos). Texto: la respuesta
    # entera (la app corta a los 20 s). Reformulación: si tarda más, se busca solo con la pregunta original.
    llm_plazo_voz_s: float = _float("LLM_PLAZO_VOZ_S", 7.0)
    llm_plazo_texto_s: float = _float("LLM_PLAZO_TEXTO_S", 14.0)
    reformular_plazo_s: float = _float("REFORMULAR_PLAZO_S", 2.0)

    # Voz (Custom LLM de ElevenLabs).
    # Etiquetas de tono entre corchetes ([slow]) de content/seguridad.json: la voz eleven_flash_v2_5 no las entiende y las
    # leería en alto, así que con false (por defecto) se quitan de las plantillas y de lo generado. true solo con una
    # voz que las interprete (eleven_v3).
    tts_etiquetas: bool = _bool("TTS_ETIQUETAS")
    # Frase puente: si el guardrail dice «normal», se manda enseguida un primer trozo corto y neutro («Vale, te lo
    # explico.») mientras corren la reformulación, el RAG y el LLM. Nunca en crisis, hechos ni fuera de ámbito.
    voz_frase_puente: bool = _bool("VOZ_FRASE_PUENTE", True)
    # Hilos para los endpoints síncronos y el streaming (anyio usa 40 por defecto). Cada respuesta en curso ocupa uno
    # mientras espera al LLM: con el público de la demo a la vez, 40 se pueden quedar cortos.
    hilos_max: int = _int("HILOS_MAX", 100)

    # Límites de peticiones (app/api/limites.py) para /api/session/*, /api/agent/ask y /api/learn/grade.
    # Por IP: ventana deslizante en memoria (Hugging Face corre un solo contenedor). En la demo, toda la sala sale
    # por la IP de la wifi del evento, así que el límite por IP es en la práctica el de la sala entera: un aula de
    # 30 personas preguntando a la vez, unas 3 preguntas por minuto cada una en el peor momento, son unas 90 por
    # minuto; 120 deja margen. Sesiones de voz: las 30 entrando en el mismo minuto, más los reintentos.
    # Diario: total para todos, se reinicia a las 00:00 UTC (y con cada reinicio del Space). Protege los créditos
    # (ElevenLabs y el router de Hugging Face: cada pregunta son dos llamadas al LLM, alrededor de 0,001 $).
    # Sesiones: el mismo tope diario que el agente de ElevenLabs (call_limits.daily_limit=500). 0 = sin límite.
    limite_ventana_s: int = _int("LIMITE_VENTANA_S", 60)
    limite_sesion_ip: int = _int("LIMITE_SESION_IP", 60)
    limite_sesion_dia: int = _int("LIMITE_SESION_DIA", 500)
    limite_ask_ip: int = _int("LIMITE_ASK_IP", 120)
    limite_ask_dia: int = _int("LIMITE_ASK_DIA", 3000)
    limite_grade_ip: int = _int("LIMITE_GRADE_IP", 120)
    limite_grade_dia: int = _int("LIMITE_GRADE_DIA", 3000)
    # Proxies delante del backend que añaden una entrada al final de X-Forwarded-For. Hugging Face Spaces
    # añade exactamente una, la IP real del cliente, y conserva delante lo que mande el cliente (comprobado).
    # 0 = sin proxy: se usa la IP de la conexión.
    proxies_de_confianza: int = _int("PROXIES_DE_CONFIANZA", 1)


settings = Settings()
