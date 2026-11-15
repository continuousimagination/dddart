#!/usr/bin/env python3
"""Serve only the compiled probe, never the repository or report files."""
import functools
import http.server
from pathlib import Path
import socket
import subprocess
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
root = Path(__file__).resolve().parent / 'build'

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

addresses = set()
for interface in ('en0', 'en1'):
    try:
        result = subprocess.run(['ipconfig', 'getifaddr', interface], capture_output=True, text=True)
        if result.returncode == 0:
            addresses.add(result.stdout.strip())
    except FileNotFoundError:
        pass
try:
    addresses.update(socket.gethostbyname_ex(socket.gethostname())[2])
except OSError:
    pass
addresses = sorted(a for a in addresses if a and not a.startswith('127.'))
with http.server.ThreadingHTTPServer(('0.0.0.0', port), functools.partial(Handler, directory=str(root))) as server:
    print('\nKeep this terminal open. Put the iPhone and Mac on the same Wi-Fi.', flush=True)
    for address in addresses:
        print(f'Open on iPhone in normal Safari: http://{address}:{port}/', flush=True)
    if not addresses:
        print(f'Open http://<Mac Wi-Fi IP>:{port}/ (find the IP in Wi-Fi settings).', flush=True)
    print(f'Desktop check: http://localhost:{port}/\nStop with Control-C.\n', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
