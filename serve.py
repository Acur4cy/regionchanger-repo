#!/usr/bin/env python3
"""Minimal HTTP server with CORS for serving the Homebrew Channel repo.

webOS's web view enforces CORS on XHR, so repo.webosbrew.org sends
Access-Control-Allow-Origin: * ; our python http.server does not, which makes
the TV fail with "error while downloading repository". This server adds the
same header.
"""
import http.server
import os
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8000


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


def main():
    with socketserver.ThreadingTCPServer(("", PORT), Handler) as httpd:
        print(f"Serving repo (with CORS) on port {PORT} ... Ctrl+C to stop")
        httpd.serve_forever()


if __name__ == "__main__":
    main()