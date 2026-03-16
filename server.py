import asyncio
import logging
import threading

from localchat.app import main
from localchat.http_server import start_http_server


logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
)


if __name__ == "__main__":
    try:
        http_thread = threading.Thread(target=start_http_server, daemon=True)
        http_thread.start()
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("Server stopped by user")

