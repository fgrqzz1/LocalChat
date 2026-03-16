"""Application wiring: WebSocket server."""

import logging

import websockets

from . import config
from .chat import ChatServer


async def main() -> None:
    chat_server = ChatServer()

    ws_server = await websockets.serve(
        chat_server.handler,
        config.WS_HOST,
        config.WS_PORT,
        ping_interval=20,
        ping_timeout=20,
        max_size=2**20,
        process_request=None,
    )
    logging.info(
        "WebSocket server listening on %s:%d%s",
        config.WS_HOST,
        config.WS_PORT,
        config.WS_PATH,
    )

    async with ws_server:
        await ws_server.wait_closed()

