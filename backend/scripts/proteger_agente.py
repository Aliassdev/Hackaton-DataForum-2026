"""Protege el agente de ElevenLabs para producción (pasos en backend/DESPLIEGUE.md).

Uso, desde backend/ con el venv del backend:
    .venv/bin/python scripts/proteger_agente.py                  # enseña el cambio, no toca nada
    .venv/bin/python scripts/proteger_agente.py --aplicar        # lo aplica y lo comprueba
    .venv/bin/python scripts/proteger_agente.py --aplicar --custom-llm-url https://<usuario>-<space>.hf.space

Qué cambia con PATCH /v1/convai/agents/{agent_id} (nombres de campo de la referencia oficial de la API,
https://api.elevenlabs.io/openapi.json, comprobados el 22/10/2026):
- platform_settings.auth.enable_auth = true: agente privado. Solo se abre una conversación con un token de
  corta duración que pide el backend con la API key (GET /api/session/token). Con la APK pública el agent_id
  se puede extraer, y la lista de dominios permitidos solo protege la web.
- platform_settings.call_limits: agent_concurrency_limit (conversaciones a la vez), daily_limit
  (conversaciones al día) y bursting_enabled = false (no pasarse del plan pagando el doble).
- platform_settings.privacy: retention_days = 0, record_voice = false, delete_audio = true y
  delete_transcript_and_pii = true. ElevenLabs borra de forma programada, no al instante.
- Opcional, --custom-llm-url: conversation_config.agent.prompt.custom_llm.url = <url>/v1, conservando
  model_id, api_type y la referencia al secreto del Custom LLM.
Cada objeto (auth, call_limits, privacy, custom_llm) se envía completo, con los valores actuales y los
nuestros encima: el resultado es el mismo tanto si la API mezcla esos objetos como si los sustituye. El objeto
prompt, en cambio, solo lleva llm y custom_llm (igual que scripts/setup_agent.py): se cuenta con que la API lo
mezcle, y la comprobación final avisa si el texto del prompt (con el perfil) no se ha conservado.
Con --aplicar, después se vuelve a leer el agente y se comprueba campo a campo.

Lee ELEVENLABS_API_KEY y ELEVENLABS_AGENT_ID de backend/.env y no imprime ninguno de los dos.
"""

import argparse
import copy
import sys
from pathlib import Path
from typing import Any

import httpx
from dotenv import dotenv_values

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
API = "https://api.elevenlabs.io/v1/convai"

# Campos que admite cada objeto en la petición (esquemas AuthSettings, AgentCallLimits, PrivacyConfig y
# CustomLLM de la API). Al copiar un objeto actual solo se reenvían estos, por si la respuesta trae otros.
CAMPOS = {
    "platform_settings.auth": ("enable_auth", "allowlist", "require_origin_header", "shareable_token"),
    "platform_settings.call_limits": ("agent_concurrency_limit", "daily_limit", "bursting_enabled"),
    "platform_settings.privacy": (
        "record_voice", "retention_days", "delete_transcript_and_pii", "delete_audio",
        "apply_to_existing_conversations", "zero_retention_mode", "conversation_history_redaction",
    ),
    "conversation_config.agent.prompt.custom_llm": (
        "url", "model_id", "api_key", "auth_connection", "request_headers", "api_version", "api_type",
    ),
}
# Si un cliente pudiera cambiar esto al abrir la sesión, podría saltarse nuestro Custom LLM (y su guardrail)
OVERRIDES = "platform_settings.overrides.conversation_config_override.agent"
OVERRIDES_PELIGROSOS = (
    "prompt.prompt", "prompt.llm", "prompt.tool_ids", "prompt.knowledge_base", "prompt.native_mcp_server_ids",
)


def leer(datos: Any, ruta: str) -> Any:
    for parte in ruta.split("."):
        if not isinstance(datos, dict) or parte not in datos:
            return None
        datos = datos[parte]
    return datos


def poner(datos: dict, ruta: str, valor: Any) -> None:
    *padres, hoja = ruta.split(".")
    for parte in padres:
        datos = datos.setdefault(parte, {})
    datos[hoja] = valor


def cambios_deseados(args: argparse.Namespace) -> dict[str, Any]:
    cambios: dict[str, Any] = {
        "platform_settings.auth.enable_auth": True,
        "platform_settings.call_limits.agent_concurrency_limit": args.simultaneas,
        "platform_settings.call_limits.daily_limit": args.diarias,
        "platform_settings.call_limits.bursting_enabled": False,
        "platform_settings.privacy.retention_days": 0,
        "platform_settings.privacy.record_voice": False,
        "platform_settings.privacy.delete_audio": True,
        "platform_settings.privacy.delete_transcript_and_pii": True,
        "platform_settings.privacy.apply_to_existing_conversations": args.aplicar_a_existentes,
    }
    if args.custom_llm_url:
        cambios["conversation_config.agent.prompt.llm"] = "custom-llm"
        cambios["conversation_config.agent.prompt.custom_llm.url"] = f"{args.custom_llm_url.rstrip('/')}/v1"
    return cambios


def cuerpo_patch(actual: dict, cambios: dict[str, Any]) -> dict:
    """Cuerpo del PATCH: cada objeto tocado va completo (valores actuales + los nuestros)."""
    cuerpo: dict = {}
    for ruta, valor in cambios.items():
        objeto = ruta.rsplit(".", 1)[0]
        if objeto in CAMPOS and leer(cuerpo, objeto) is None:
            previo = leer(actual, objeto) or {}
            poner(cuerpo, objeto, {k: copy.deepcopy(v) for k, v in previo.items() if k in CAMPOS[objeto]})
        poner(cuerpo, ruta, valor)
    custom = leer(cuerpo, "conversation_config.agent.prompt.custom_llm")
    if custom is not None:  # agente sin Custom LLM todavía: los mismos valores que pone setup_agent.py
        custom.setdefault("model_id", "tuturno")
        custom.setdefault("api_type", "chat_completions")
    return cuerpo


def _mostrar(valor: Any) -> str:
    return "?" if valor is None else str(valor).lower() if isinstance(valor, bool) else str(valor)


def mostrar_plan(actual: dict | None, cambios: dict[str, Any]) -> None:
    print("Cambios en el agente de backend/.env (actual → nuevo):")
    for ruta, valor in cambios.items():
        previo = leer(actual, ruta) if actual is not None else None
        marca = "  " if previo == valor else "* "
        print(f"  {marca}{ruta}: {_mostrar(previo)} → {_mostrar(valor)}")
    if actual is not None and "conversation_config.agent.prompt.custom_llm.url" in cambios:
        custom = leer(actual, "conversation_config.agent.prompt.custom_llm") or {}
        secreto = "se conserva" if custom.get("api_key") else "NO HAY: ejecuta antes scripts/setup_agent.py"
        print(f"    custom_llm.api_key (secreto del Custom LLM): {secreto}")


def avisar_overrides(actual: dict) -> None:
    abiertos = [o for o in OVERRIDES_PELIGROSOS if leer(actual, f"{OVERRIDES}.{o}") is True]
    if abiertos:
        print("AVISO: el agente deja que el cliente cambie " + ", ".join(abiertos)
              + ". Desactívalo en ElevenLabs (agente → Security → Overrides): la app no lo usa.")
    else:
        print("Overrides del cliente: no permiten cambiar prompt, LLM ni herramientas (bien).")
    if leer(actual, "platform_settings.auth.shareable_token"):  # el token no se imprime
        print("AVISO: el agente tiene un enlace para compartir (shareable_token): quien lo tenga puede abrir "
              "conversaciones aunque el agente sea privado. Si no lo usáis, quítalo en el panel de ElevenLabs.")


def _limpiar(texto: str, secretos: list[str]) -> str:
    for s in secretos:
        texto = texto.replace(s, "<oculto>")
    return texto[:300]


def cliente(api_key: str) -> httpx.Client:
    return httpx.Client(headers={"xi-api-key": api_key}, timeout=30)


def _pedir(http: httpx.Client, metodo: str, url: str, secretos: list[str], **kwargs: Any) -> dict:
    r = http.request(metodo, url, **kwargs)
    if r.status_code >= 400:
        sys.exit(f"ElevenLabs respondió {r.status_code} a {metodo}: {_limpiar(r.text, secretos)}")
    return r.json()


def comprobar(nuevo: dict, cambios: dict[str, Any], actual: dict) -> bool:
    print("\nComprobación después del cambio:")
    bien = True
    for ruta, valor in cambios.items():
        ok = leer(nuevo, ruta) == valor
        bien &= ok
        print(f"  {'ok' if ok else 'FALLO'}  {ruta} = {_mostrar(leer(nuevo, ruta))}")
    # Lo que no tocamos tiene que seguir igual: el texto del prompt (lleva el perfil) y el resto del Custom LLM
    for ruta in (
        "conversation_config.agent.prompt.prompt",
        "conversation_config.agent.prompt.custom_llm.model_id",
        "conversation_config.agent.prompt.custom_llm.api_key",
    ):
        if leer(actual, ruta) is not None:
            ok = leer(nuevo, ruta) == leer(actual, ruta)
            bien &= ok
            print(f"  {'ok' if ok else 'FALLO'}  {ruta}: {'se conserva' if ok else 'HA CAMBIADO'}")
    return bien


def main() -> None:
    ap = argparse.ArgumentParser(description="Hace privado el agente de ElevenLabs y limita su uso.")
    ap.add_argument("--aplicar", action="store_true", help="aplica el cambio (sin esto solo se enseña)")
    ap.add_argument("--custom-llm-url", help="URL base del backend, p. ej. https://<usuario>-<space>.hf.space")
    ap.add_argument("--simultaneas", type=int, default=5, help="conversaciones a la vez (agent_concurrency_limit)")
    ap.add_argument("--diarias", type=int, default=200, help="conversaciones al día (daily_limit)")
    ap.add_argument("--aplicar-a-existentes", action="store_true",
                    help="aplica también la retención a las conversaciones ya guardadas (las borra)")
    ap.add_argument("--sin-red", action="store_true", help="solo enseña el cambio, sin leer el agente actual")
    ap.add_argument("--env", type=Path, default=ENV_PATH, help="fichero de entorno (por defecto backend/.env)")
    args = ap.parse_args()
    if args.custom_llm_url and not args.custom_llm_url.startswith("https://"):
        sys.exit("--custom-llm-url debe empezar por https://")
    if args.simultaneas < 1 or args.diarias < 1:
        sys.exit("--simultaneas y --diarias deben ser al menos 1")

    cambios = cambios_deseados(args)
    if args.sin_red and not args.aplicar:
        mostrar_plan(None, cambios)
        print("\n--sin-red: no se ha leído ni cambiado nada.")
        return

    env = dotenv_values(args.env) if args.env.exists() else {}
    api_key, agent_id = env.get("ELEVENLABS_API_KEY"), env.get("ELEVENLABS_AGENT_ID")
    if not api_key or not agent_id:
        sys.exit(f"Faltan ELEVENLABS_API_KEY o ELEVENLABS_AGENT_ID en {args.env}")
    secretos = [api_key, agent_id]
    url_agente = f"{API}/agents/{agent_id}"

    with cliente(api_key) as http:
        actual = _pedir(http, "GET", url_agente, secretos)
        mostrar_plan(actual, cambios)
        avisar_overrides(actual)
        if not args.aplicar:
            print("\nNo se ha cambiado nada. Para aplicarlo: --aplicar")
            return
        _pedir(http, "PATCH", url_agente, secretos, json=cuerpo_patch(actual, cambios))
        nuevo = _pedir(http, "GET", url_agente, secretos)

    if not comprobar(nuevo, cambios, actual):
        sys.exit("\nAlgún campo no ha quedado como se esperaba: revísalo en el panel de ElevenLabs.")
    print("\nAgente protegido. La app debe abrir la sesión con el token de GET /api/session/token;")
    print("una sesión abierta solo con el agent_id ya no funciona.")


if __name__ == "__main__":
    main()
