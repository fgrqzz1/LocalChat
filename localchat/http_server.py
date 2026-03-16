"""Async HTTP server that serves index.html."""

import asyncio
import logging
from asyncio import StreamReader, StreamWriter

from . import config


try:
    with open("index.html", "rb") as f:
        INDEX_HTML_BYTES = f.read()
except OSError:
    INDEX_HTML_BYTES = b"<html><body><h1>index.html not found</h1></body></html>"


async def http_handler(reader: StreamReader, writer: StreamWriter) -> None:
    try:
        request_line = await reader.readline()
        if not request_line:
            writer.close()
            await writer.wait_closed()
            return

        parts = request_line.decode("latin1").strip().split()
        if len(parts) < 2:
            writer.close()
            await writer.wait_closed()
            return

        method, path = parts[0], parts[1]

        # Читаем и игнорируем заголовки до пустой строки
        while True:
            header_line = await reader.readline()
            if not header_line or header_line in (b"\r\n", b"\n"):
                break

        if method != "GET" or path != "/":
            response_body = b"Not found"
            response = (
                b"HTTP/1.1 404 Not Found\r\n"
                b"Content-Type: text/plain; charset=utf-8\r\n"
                b"Content-Length: " + str(len(response_body)).encode("ascii") + b"\r\n"
                b"Connection: close\r\n"
                b"\r\n"
                + response_body
            )
            writer.write(response)
            await writer.drain()
            writer.close()
            await writer.wait_closed()
            return

        body = INDEX_HTML_BYTES
        response = (
            b"HTTP/1.1 200 OK\r\n"
            b"Content-Type: text/html; charset=utf-8\r\n"
            b"Content-Length: " + str(len(body)).encode("ascii") + b"\r\n"
            b"Connection: close\r\n"
            b"\r\n"
            + body
        )
        writer.write(response)
        await writer.drain()
    except Exception as e:  # noqa: BLE001
        logging.error("HTTP handler error: %s", e)
    finally:
        try:
            writer.close()
            await writer.wait_closed()
        except Exception:
            pass


async def start_http_server() -> asyncio.AbstractServer:
    server = await asyncio.start_server(http_handler, config.HTTP_HOST, config.HTTP_PORT)
    logging.info("HTTP server listening on %s:%d", config.HTTP_HOST, config.HTTP_PORT)
    return server

