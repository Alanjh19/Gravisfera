"""Serve the optimized Flutter build locally, with WASM worker support."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        # Prevent stale bootstrap/code when a new build replaces this directory.
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent / 'build' / 'web'
    if not (root / 'index.html').exists():
        raise SystemExit('Primero ejecuta: flutter build web --release --wasm --no-web-resources-cdn')
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(root)))
    print(f'GRAVISFERA disponible en http://localhost:{args.port}', flush=True)
    server.serve_forever()
