#!/usr/bin/env python3
import http.server
import socketserver
import os
import webbrowser

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()
    
    def do_GET(self):
        if self.path == '/':
            self.path = '/static-preview.html'
        return super().do_GET()

print(f"🚀 Comparty Preview Server")
print(f"=" * 50)
print(f"📁 Serving from: {DIRECTORY}")
print(f"🌐 Server running at: http://localhost:{PORT}")
print(f"=" * 50)
print(f"✨ Open your browser and visit:")
print(f"   http://localhost:{PORT}")
print(f"")
print(f"Press Ctrl+C to stop the server")
print(f"=" * 50)

# Try to open browser automatically
try:
    webbrowser.open(f'http://localhost:{PORT}')
except:
    pass

with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n👋 Server stopped. Goodbye!")
        pass