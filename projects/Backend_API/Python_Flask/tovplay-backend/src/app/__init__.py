from apscheduler.schedulers.background import BackgroundScheduler
from .services import expire_old_game_requests, update_scheduled_session_statuses
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask
from flask_migrate import Migrate
from flask_cors import CORS
from .extensions import limiter
from prometheus_flask_exporter import PrometheusMetrics

# Add config path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.config.secure_config import get_flask_config, validate_environment
from .db import check_db_connection, db, init_db
from .basic_routes import bp as basic_bp
from .routes import bp as api_bp
from .api_endpoints import db_api_bp
from .health import health_bp
from .error_handlers import setup_error_handlers
from .logging_config import setup_logging, get_logger
from .security import setup_security

migrate = Migrate()


def create_app(config_object=None, environment=None):
    # Prevent duplicate initialization in Flask's reloader
    werkzeug_reloader = os.getenv('WERKZEUG_RUN_MAIN') == 'true'

    if werkzeug_reloader and hasattr(create_app, '_app_instance'):
        return create_app._app_instance

    if hasattr(create_app, '_app_instance') and not werkzeug_reloader:
        return create_app._app_instance

    app = Flask(__name__)
    load_dotenv()

    # ---------------- CONFIG ----------------
    if config_object:
        app.config.from_object(config_object)
    else:
        try:
            environment = environment or os.getenv('FLASK_ENV', 'development')

            validation_result = validate_environment(environment)
            if not validation_result['valid']:
                for error in validation_result['errors']:
                    print(f"   - {error}")
                raise ValueError("Invalid configuration detected")

            secure_config = get_flask_config(environment)
            app.config.update(secure_config)
            app.config["JSON_SORT_KEYS"] = False

        except Exception as e:
            print(f"Failed to load secure configuration: {e}")
            print("Falling back to basic configuration...")

            app.config["JSON_SORT_KEYS"] = False
            app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("SQLALCHEMY_DATABASE_URI")
            app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
            app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
            app.config["SQLALCHEMY_ECHO"] = True

    # ---------------- TESTING SYNC ----------------
    if app.config.get("TESTING"):
        os.environ["TESTING"] = "1"

    # ---------------- METRICS ----------------
    if not app.config.get("TESTING"):
        metrics = PrometheusMetrics(app)
        metrics.info('tovplay_backend', 'TovPlay Backend API', version='1.0.0')

    # ---------------- LOGGING ----------------
    loggers = setup_logging(app)
    logger = loggers['main']

    # ---------------- DB ----------------
    init_db(app)
    migrate.init_app(app, db)

    # ---------------- SECURITY ----------------
    setup_security(app)

    # ---------------- RATE LIMITER ----------------
    app.config["RATELIMIT_STORAGE_URL"] = (
        app.config.get("REDIS_URL")
        or os.getenv("REDIS_URL", "redis://localhost:6379/0")
    )
    limiter.init_app(app)

    # ---------------- ERRORS ----------------
    setup_error_handlers(app)

    # ---------------- BLUEPRINTS ----------------
    app.register_blueprint(basic_bp)
    app.register_blueprint(api_bp)
    app.register_blueprint(db_api_bp)
    app.register_blueprint(health_bp)

    # ---------------- DB CHECK ----------------
    with app.app_context():
        logger.info("Starting TovPlay backend application")
        check_db_connection()

    # ---------------- BACKGROUND JOBS ----------------
    if not app.config.get("TESTING"):
        mark_old_requests_as_expired(app)

    create_app._app_instance = app
    return app


def mark_old_requests_as_expired(app):
    # Skip scheduler in testing mode
    if os.environ.get("TESTING"):
        return

    scheduler = BackgroundScheduler()
    scheduler.add_job(expire_old_game_requests, 'cron', hour=0, minute=0, args=[app])
    scheduler.add_job(update_scheduled_session_statuses, 'interval', minutes=5, args=[app])
    scheduler.start()
