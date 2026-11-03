import os

from dotenv import load_dotenv
from flask import Flask, jsonify, render_template, send_from_directory

# Load configuration from .env (if present) before anything reads os.environ.
load_dotenv()

from api.routes import api_bp  # noqa: E402
from utils.helpers import get_db_connection  # noqa: E402

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.environ.get("UPLOAD_FOLDER", os.path.join(BASE_DIR, "uploads"))

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("SECRET_KEY", "dev-only-change-me")
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app.register_blueprint(api_bp, url_prefix="/api")


@app.route("/")
def home():
    return render_template("index.html")


@app.route("/notes")
def notes_page():
    return render_template("notes.html")


@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory(app.config["UPLOAD_FOLDER"], filename)


@app.route("/health")
def health():
    """Liveness + database check, used to verify the deployment with curl."""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        conn.close()
        return jsonify({"status": "ok", "database": "postgresql", "pid": os.getpid()})
    except Exception as exc:  # pragma: no cover - surfaced to the operator
        return jsonify({"status": "error", "detail": str(exc)}), 503


if __name__ == "__main__":
    # Local development only. In deployment, gunicorn runs the app (see deploy/).
    app.run(
        debug=os.environ.get("FLASK_DEBUG") == "1",
        host=os.environ.get("HOST", "0.0.0.0"),
        port=int(os.environ.get("PORT", "5000")),
    )
