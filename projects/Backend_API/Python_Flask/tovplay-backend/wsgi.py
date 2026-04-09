#!/usr/bin/env python3
"""
TovPlay Backend Application Entry Point
Unified entry for both development (flask run) and production (gunicorn/WSGI)
"""

import os
import sys
import threading

# Get the directory of the current file (wsgi.py)
current_dir = os.path.dirname(os.path.abspath(__file__))

# Add the 'src' directory to the Python path
sys.path.insert(0, os.path.join(current_dir, 'src'))

from src.app import create_app


def start_ws_server(app):
    """Start websocket server in a background thread."""
    from src.api import realtime_backend
    realtime_backend.start_servers(app)


# Create the Flask app
app = create_app()


if __name__ == "__main__":
    # Development mode: run with WebSocket server

    # Only start the websocket server in the main Flask process (not the reloader)
    if os.environ.get("WERKZEUG_RUN_MAIN") == "true":
        ws_thread = threading.Thread(target=start_ws_server, args=(app,), daemon=True)
        ws_thread.start()

    # Get configuration from environment variables
    host = "0.0.0.0"
    port = int(os.getenv("PORT", 5001))
    debug = os.getenv("FLASK_ENV", "development") == "development"

    print(f"[STARTING] TovPlay Backend on http://{host}:{port}")
    print(f"[DEBUG] Debug mode: {debug}")
    print(f"[DATABASE] Database connected: {bool(app.config.get('SQLALCHEMY_DATABASE_URI'))}")
    print("[READY] Application ready! Press Ctrl+C to stop")

    # Start the development server
    app.run(host=host, port=port, debug=debug, threaded=True)
