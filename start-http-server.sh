#!/bin/bash
cd /Users/seunghoonoh/Desktop/wave-tree-news-hub
/usr/bin/python3 << 'EOF'
import http.server
import socketserver
import os

os.chdir('/Users/seunghoonoh/Desktop/wave-tree-news-hub')
PORT = 8000

Handler = http.server.SimpleHTTPRequestHandler
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Server running on port {PORT}")
    httpd.serve_forever()
EOF
