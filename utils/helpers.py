import os

import psycopg2
import psycopg2.extras

ALLOWED_EXTENSIONS = {"txt", "md", "pdf", "png", "jpg", "jpeg", "gif"}


def get_database_url():
    """Read the PostgreSQL connection string from the environment (never hardcoded)."""
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise RuntimeError(
            "DATABASE_URL is not set. Copy .env.example to .env and fill in your PostgreSQL connection string."
        )
    return url


def get_db_connection():
    """Open a PostgreSQL connection whose cursors return rows as dicts."""
    return psycopg2.connect(get_database_url(), cursor_factory=psycopg2.extras.RealDictCursor)


def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS
