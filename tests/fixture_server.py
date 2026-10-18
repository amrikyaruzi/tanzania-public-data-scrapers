"""Tiny local web server that mimics the real sites' page structure, so the
scrapers can be tested offline: python tests/fixture_server.py"""
import http.server, re, socketserver, urllib.parse, os

ROOT = os.path.join(os.path.dirname(__file__), "fixtures", "site")

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        if u.path == "/hfrs":
            f = f"hfrs/{q['filters'][0]}_{q.get('page', ['1'])[0]}.html"
        elif u.path in ("/primary-schools/", "/primary-schools"):
            f = "primary-schools/page1.html"
        elif m := re.match(r"/primary-schools/page(\d+)/", u.path):
            f = f"primary-schools/page{m.group(1)}.html"
        elif m := re.match(r"/school/(s\d+)/", u.path):
            f = f"school_{m.group(1)}.html"
        elif u.path == "/regions":
            f = "regions.html"
        else:
            self.send_error(404); return
        body = open(os.path.join(ROOT, f), "rb").read()
        self.send_response(200); self.send_header("Content-Type", "text/html"); self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", 8765), Handler) as s:
    print("Fixture server on http://127.0.0.1:8765"); s.serve_forever()
