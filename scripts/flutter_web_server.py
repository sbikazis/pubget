"""Small static server with Flutter web history-API fallback."""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1] / "build" / "web"


class FlutterWebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def send_head(self):
        requested = Path(self.translate_path(self.path.split("?", 1)[0]))
        if not requested.is_file() and not requested.is_dir():
            self.path = "/index.html"
        return super().send_head()


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 5000), FlutterWebHandler)
    print("Serving Flutter web on http://0.0.0.0:5000/", flush=True)
    server.serve_forever()