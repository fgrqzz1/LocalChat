"""WebSocket chat server logic."""

import asyncio
import json
import logging
import time
import uuid
from typing import Dict, Set

from websockets.server import WebSocketServerProtocol

from . import config


class ChatServer:
    def __init__(self) -> None:
        self.active_clients: Set[WebSocketServerProtocol] = set()
        self.client_info: Dict[WebSocketServerProtocol, Dict[str, str]] = {}
        self.usernames: Dict[WebSocketServerProtocol, str] = {}
        self.history = []

    async def register(self, ws: WebSocketServerProtocol) -> None:
        self.active_clients.add(ws)
        logging.info("Client connected: %s", ws.remote_address)

    async def unregister(self, ws: WebSocketServerProtocol) -> None:
        self.active_clients.discard(ws)
        self.usernames.pop(ws, None)
        info = self.client_info.pop(ws, None)
        if info:
            await self.broadcast_system(f"{info['nickname']} вышел из чата")
            await self.broadcast_users()
        logging.info("Client disconnected: %s", ws.remote_address)

    async def broadcast(self, message: dict) -> None:
        if not self.active_clients:
            return
        data = json.dumps(message)
        await asyncio.gather(
            *[self._safe_send(ws, data) for ws in list(self.active_clients)],
            return_exceptions=True,
        )

    async def _safe_send(self, ws: WebSocketServerProtocol, data: str) -> None:
        try:
            await ws.send(data)
        except Exception as e:  # noqa: BLE001
            logging.warning("Error sending to %s: %s", ws.remote_address, e)

    async def broadcast_system(self, text: str) -> None:
        msg = {
            "type": "system",
            "payload": {
                "message": text,
                "timestamp": time.time(),
            },
        }
        await self.broadcast(msg)

    async def broadcast_users(self) -> None:
        users = [
            {"user_id": info["user_id"], "nickname": info["nickname"]}
            for info in self.client_info.values()
        ]
        msg = {
            "type": "users",
            "payload": {"users": users},
        }
        await self.broadcast(msg)

    async def send_history(self, ws: WebSocketServerProtocol) -> None:
        if not self.history:
            return
        msg = {
            "type": "history",
            "payload": {"messages": self.history},
        }
        await self._safe_send(ws, json.dumps(msg))

    async def handler(self, ws: WebSocketServerProtocol) -> None:
        await self.register(ws)
        try:
            await self._handle_client(ws)
        finally:
            await self.unregister(ws)

    async def _handle_client(self, ws: WebSocketServerProtocol) -> None:
        hello_received = False
        async for raw in ws:
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                await self._safe_send(
                    ws,
                    json.dumps(
                        {
                            "type": "error",
                            "payload": {"message": "Invalid JSON"},
                        }
                    ),
                )
                continue

            msg_type = data.get("type")
            payload = data.get("payload", {})

            if msg_type == "register":
                # Поддерживаем оба формата:
                # {"type": "register", "username": "..."} (шаг 2 ТЗ)
                # и {"type": "register", "payload": {"username": "..."}} (внутренний)
                raw_username = data.get("username")
                if raw_username is None:
                    raw_username = payload.get("username", "")
                username = str(raw_username).strip()
                if not username:
                    await self._safe_send(
                        ws,
                        json.dumps(
                            {
                                "type": "error",
                                "message": "Имя пользователя не может быть пустым",
                            }
                        ),
                    )
                    continue

                if len(username) > 20:
                    await self._safe_send(
                        ws,
                        json.dumps(
                            {
                                "type": "error",
                                "message": "Имя пользователя не должно превышать 20 символов",
                            }
                        ),
                    )
                    continue

                if username in self.usernames.values():
                    await self._safe_send(
                        ws,
                        json.dumps(
                            {
                                "type": "error",
                                "message": "Это имя уже занято другим участником",
                            }
                        ),
                    )
                    continue

                self.usernames[ws] = username

                user_id = str(uuid.uuid4())
                self.client_info[ws] = {"user_id": user_id, "nickname": username}
                hello_received = True

                await self.send_history(ws)
                await self.broadcast_system(f"{username} присоединился к чату")
                await self.broadcast_users()

                await self._safe_send(
                    ws,
                    json.dumps(
                        {
                            "type": "registered",
                        }
                    ),
                )
                continue

            if msg_type == "hello":
                nickname = str(payload.get("nickname", "")).strip()
                if not nickname:
                    nickname = "Гость"
                user_id = str(uuid.uuid4())
                self.client_info[ws] = {"user_id": user_id, "nickname": nickname}
                hello_received = True

                await self.send_history(ws)
                await self.broadcast_system(f"{nickname} присоединился к чату")
                await self.broadcast_users()
                continue

            if not hello_received:
                await self._safe_send(
                    ws,
                    json.dumps(
                        {
                            "type": "error",
                            "payload": {"message": "Send hello first"},
                        }
                    ),
                )
                continue

            if msg_type == "chat":
                text = str(payload.get("message", "")).strip()
                if not text:
                    continue
                if len(text) > 1000:
                    text = text[:1000]

                info = self.client_info.get(ws)
                if not info:
                    continue

                chat_msg = {
                    "type": "chat",
                    "payload": {
                        "user_id": info["user_id"],
                        "nickname": info["nickname"],
                        "message": text,
                        "timestamp": time.time(),
                    },
                }

                self.history.append(chat_msg["payload"])
                if len(self.history) > config.HISTORY_LIMIT:
                    self.history = self.history[-config.HISTORY_LIMIT :]

                await self.broadcast(chat_msg)
            else:
                await self._safe_send(
                    ws,
                    json.dumps(
                        {
                            "type": "error",
                            "payload": {"message": "Unknown message type"},
                        }
                    ),
                )

