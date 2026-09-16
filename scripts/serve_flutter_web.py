#!/usr/bin/env python3
"""Serve the Flutter web build with client-side route fallback."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1] / "build" / "web"


class FlutterWebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        path = urlsplit(self.path).path
        requested = self.translate_path(path)
        if (
            path != "/"
            and not Path(requested).is_file()
            and "." not in Path(path).name
        ):
            self.path = "/index.html"
        super().do_GET()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 5000), FlutterWebHandler)
    print("Serving Flutter web on http://0.0.0.0:5000/", flush=True)
    server.serve_forever()