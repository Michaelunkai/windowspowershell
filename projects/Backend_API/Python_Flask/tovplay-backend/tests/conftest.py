import json
import os
import pytest
from sqlalchemy import text
from src.app import create_app, db


def _require_test_db(uri: str) -> None:
    if not uri:
        raise RuntimeError(
            "SQLALCHEMY_DATABASE_URI is not set. "
            "Set it to your *TEST* Postgres DB, e.g. postgresql://.../tovplay_test"
        )

    lowered = uri.lower()
    if "45.148.28.196" in lowered or ("/tovplay" in lowered and "/tovplay_test" not in lowered):
        raise RuntimeError(
            f"Refusing to run tests against non-test database URI: {uri}\n"
            "Point SQLALCHEMY_DATABASE_URI to a dedicated test DB (example: tovplay_test)."
        )


def _ensure_audit_log_table_exists():
    db.session.execute(text("""
        CREATE TABLE IF NOT EXISTS universalauditlog (
            id BIGSERIAL PRIMARY KEY,
            operation_type TEXT,
            table_name TEXT,
            executed_by TEXT,
            operation_status TEXT,
            affected_rows INTEGER,
            recovery_data JSONB,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
    """))
    db.session.commit()


def _disable_protection_if_present():
    try:
        db.session.execute(text("""
            DO $$
            BEGIN
                IF EXISTS (
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_name = 'ProtectionStatus'
                ) THEN
                    EXECUTE 'UPDATE "ProtectionStatus" SET protection_enabled = false WHERE id = 1';
                END IF;
            END $$;
        """))
        db.session.commit()
    except Exception:
        db.session.rollback()


def _truncate_all_tables():
    tables = []
    for t in db.metadata.sorted_tables:
        if t.name == "alembic_version":
            continue
        tables.append(f'"{t.name}"')

    if not tables:
        return

    db.session.execute(
        text(f"TRUNCATE TABLE {', '.join(tables)} RESTART IDENTITY CASCADE;")
    )
    db.session.commit()


@pytest.fixture
def app():
    uri = (os.environ.get("SQLALCHEMY_DATABASE_URI") or "").strip()
    _require_test_db(uri)

    # ---- REQUIRED ENV VARS (services.py reads JWT from env) ----
    os.environ["SQLALCHEMY_DATABASE_URI"] = uri
    os.environ["TESTING"] = "1"
    os.environ["JWT_SECRET_KEY"] = "K9pQ3nV1xM7zR2sT8wY4uI6oP0aS5dF9gH1jL3cB7"
    os.environ["JWT_ALGORITHM"] = "HS256"

    # IMPORTANT: clear cached app instance between tests
    if hasattr(create_app, "_app_instance"):
        delattr(create_app, "_app_instance")

    class TestConfig:
        TESTING = True
        WTF_CSRF_ENABLED = False
        SQLALCHEMY_DATABASE_URI = uri
        SQLALCHEMY_TRACK_MODIFICATIONS = False

        SECRET_KEY = "test-flask-secret-key"
        JWT_SECRET_KEY = os.environ["JWT_SECRET_KEY"]
        JWT_ALGORITHM = "HS256"

    app = create_app(config_object=TestConfig)

    with app.app_context():
        db.create_all()
        _ensure_audit_log_table_exists()
        _disable_protection_if_present()
        _truncate_all_tables()

        yield app

        db.session.remove()

        try:
            _truncate_all_tables()
        except Exception:
            db.session.rollback()


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def runner(app):
    return app.test_cli_runner()


@pytest.fixture
def mock_users():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    data_path = os.path.join(base_dir, "data", "test_users.json")
    with open(data_path, "r", encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture(autouse=True)
def mock_external_services(mocker):
    mocker.patch("src.app.services.send_verification_email", return_value=True)
    mocker.patch("src.app.routes.signup_signin.send_verification_email", return_value=True)
