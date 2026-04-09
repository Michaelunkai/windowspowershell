from flask_sqlalchemy import SQLAlchemy
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from sqlalchemy import text
import os

# Database extension
db = SQLAlchemy()

# Rate limiter extension (merged from extensions.py)
limiter = Limiter(
    get_remote_address,
    storage_options={"socket_connect_timeout": 30},
    strategy="fixed-window"
)


def init_db(app):
    """Initialize the SQLAlchemy app."""
    db.init_app(app)
    
    # Only create tables if they don't exist
    # For full initialization, use scripts/db/init_db.py
    with app.app_context():
        try:
            # Check if any tables exist (compatible with newer SQLAlchemy versions)
            inspector = db.inspect(db.engine)
            tables = inspector.get_table_names()
            tables_exist = 'User' in tables
            
            if not tables_exist:
                # Use ASCII characters for Windows compatibility
                if os.name == 'nt':  # Windows
                    print("Creating database tables for first-time setup...")
                else:
                    print("🏗️ Creating database tables for first-time setup...")
                db.create_all()
                if os.name == 'nt':  # Windows
                    print("Basic tables created. Run 'python scripts/db/init_db.py' for full setup.")
                else:
                    print("✅ Basic tables created. Run 'python scripts/db/init_db.py' for full setup.")
        except Exception as e:
            if os.name == 'nt':  # Windows
                print(f"Database initialization warning: {e}")
                print("Run 'python scripts/db/init_db.py' for proper database setup.")
            else:
                print(f"⚠️ Database initialization warning: {e}")
                print("💡 Run 'python scripts/db/init_db.py' for proper database setup.")


def check_db_connection():
    """Test if the database connection works with proper error handling."""
    try:
        from sqlalchemy.exc import SQLAlchemyError
        
        # Test basic connectivity
        db.session.execute(text("SELECT 1"))
        db.session.commit()
        # Use ASCII characters for Windows compatibility
        if os.name == 'nt':  # Windows
            print("Database connection OK!")
        else:
            print("✅ Database connection OK!")
        return True
        
    except SQLAlchemyError as e:
        if os.name == 'nt':  # Windows
            print(f"Database connection failed (SQLAlchemy): {e}")
        else:
            print(f"❌ Database connection failed (SQLAlchemy): {e}")
        return False
    except Exception as e:
        if os.name == 'nt':  # Windows
            print(f"Database connection failed (General): {e}")
        else:
            print(f"❌ Database connection failed (General): {e}")
        return False
