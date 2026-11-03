"""Apply SQL migrations in migrations/ to the PostgreSQL database in DATABASE_URL.

Each file is applied once, in filename order, and recorded in schema_migrations.
Usage:  python migrate.py
"""
import os

from dotenv import load_dotenv

load_dotenv()

from utils.helpers import get_db_connection  # noqa: E402

MIGRATIONS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "migrations")


def main():
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "CREATE TABLE IF NOT EXISTS schema_migrations ("
            " version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW())"
        )
        cur.execute("SELECT version FROM schema_migrations")
        applied = {row["version"] for row in cur.fetchall()}

        for name in sorted(f for f in os.listdir(MIGRATIONS_DIR) if f.endswith(".sql")):
            if name in applied:
                print(f"skip   {name} (already applied)")
                continue
            with open(os.path.join(MIGRATIONS_DIR, name)) as fh:
                cur.execute(fh.read())
            cur.execute("INSERT INTO schema_migrations (version) VALUES (%s)", (name,))
            print(f"apply  {name}")
    conn.close()
    print("migrations complete")


if __name__ == "__main__":
    main()
