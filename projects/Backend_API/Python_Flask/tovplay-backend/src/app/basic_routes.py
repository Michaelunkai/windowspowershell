from flask import Blueprint, jsonify

bp = Blueprint('main', __name__)

@bp.route("/")
def home():
    return jsonify({
        "message": "Welcome to TovPlay Backend API",
        "status": "running",
        "version": "1.0"
    })

@bp.route("/health")
def health():
    return jsonify({"status": "healthy"})

@bp.route("/api/health")
def api_health():
    return jsonify({"status": "healthy"})
