"""Prueba de punta a punta por texto: abre una sesión con el agente (como hará la app),
pasa el perfil como dynamic variables, envía una pregunta y muestra la respuesta.

Uso, desde backend/:
    .venv/Scripts/python scripts/probar_agente.py "¿Qué pasa si me llaman a declarar?"
"""

import asyncio
import json
import sys
from pathlib import Path

import httpx
import websockets
from dotenv import dotenv_values

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
PERFIL = {"edad": "13", "procedimiento": "penal", "rol": "testigo", "fase": "antes"}


async def main(pregunta: str) -> None:
    env = dotenv_values(ENV_PATH)
    r = httpx.get(
        "https://api.elevenlabs.io/v1/convai/conversation/get-signed-url",
        params={"agent_id": env["ELEVENLABS_AGENT_ID"]},
        headers={"xi-api-key": env["ELEVENLABS_API_KEY"]},
        timeout=10,
    )
    r.raise_for_status()

    async with websockets.connect(r.json()["signed_url"]) as ws:
        await ws.send(json.dumps({"type": "conversation_initiation_client_data", "dynamic_variables": PERFIL}))
        enviada = False
        respuestas = 0
        async for raw in ws:
            msg = json.loads(raw)
            tipo = msg.get("type")
            if tipo == "ping":
                await ws.send(json.dumps({"type": "pong", "event_id": msg["ping_event"]["event_id"]}))
            elif tipo == "agent_response":
                respuestas += 1
                print(f"Agente: {msg['agent_response_event']['agent_response']}")
                if not enviada:
                    print(f"Tú: {pregunta}")
                    await ws.send(json.dumps({"type": "user_message", "text": pregunta}))
                    enviada = True
                elif respuestas >= 2:
                    return
            elif tipo == "conversation_initiation_metadata":
                print(f"Sesión abierta: {msg['conversation_initiation_metadata_event']['conversation_id']}")


if __name__ == "__main__":
    # Opcional: --perfil "edad=15;procedimiento=ninguno;rol=victima;fase=antes"
    args = sys.argv[1:]
    if "--perfil" in args:
        i = args.index("--perfil")
        PERFIL.update(dict(p.split("=", 1) for p in args[i + 1].split(";")))
        del args[i : i + 2]
    asyncio.run(asyncio.wait_for(main(args[0] if args else "¿Qué pasa si me llaman a declarar?"), 60))
