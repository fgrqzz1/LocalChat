"""HTTP server that serves index.html using the standard library."""

import logging
from http.server import HTTPServer, SimpleHTTPRequestHandler

from . import config


class IndexHandler(SimpleHTTPRequestHandler):
    """Serve index.html on / and /index.html."""

    def do_GET(self) -> None:  # type: ignore[override]
        if self.path in ("/", "/index.html"):
            self.path = "/index.html"
        return super().do_GET()

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        logging.info("HTTP: " + format, *args)


def start_http_server() -> None:
    """Run blocking HTTP server in current thread."""
    httpd = HTTPServer((config.HTTP_HOST, config.HTTP_PORT), IndexHandler)
    logging.info("HTTP server listening on %s:%d", config.HTTP_HOST, config.HTTP_PORT)
    httpd.serve_forever()


