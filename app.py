from flask import Flask, jsonify, render_template, request, redirect, url_for, send_from_directory
from api.routes import api_bp
from utils.helpers import get_db_connection, init_db
from utils.metrics import init_metrics
from utils.logs import configure_logging, init_request_logging
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Settings come from the environment, so one image runs anywhere.
DATA_DIR = os.environ.get("DATA_DIR", BASE_DIR)
UPLOAD_FOLDER = os.path.join(DATA_DIR, "uploads")
DATABASE_PATH = os.path.join(DATA_DIR, "database", "cloudnotes.db")

configure_logging()

app = Flask(__name__)
# Fail fast: without this setting the app must not start in a half-working state.
SECRET_KEY = os.environ.get("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("Missing required environment variable: SECRET_KEY")
app.config["SECRET_KEY"] = SECRET_KEY
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["DATABASE_PATH"] = DATABASE_PATH
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

init_metrics(app)
init_request_logging(app)
app.register_blueprint(api_bp, url_prefix="/api")

# Flask 2.3 removed before_first_request, so set up once at startup.
init_db(DATABASE_PATH)
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.logger.info(
    "CloudNotes started: env=%s data_dir=%s secret_key_set=%s",
    os.environ.get("APP_ENV", "unset"), DATA_DIR, bool(app.config["SECRET_KEY"]),
)

@app.route("/debug/fail")
def debug_fail():
    # Off unless FAULT_INJECTION=true. Used only to prove the alert fires.
    if os.environ.get("FAULT_INJECTION") != "true":
        return jsonify(error="Not found"), 404
    app.logger.error("injected failure while saving note")
    return jsonify(error="Injected failure"), 500

@app.route("/health")
def health():
    # Liveness: shallow. It only proves this process can answer.
    return jsonify(status="ok")

@app.route("/ready")
def ready():
    # Readiness: checks the database, so a database problem pauses traffic.
    try:
        conn = get_db_connection(app.config["DATABASE_PATH"])
        conn.execute("SELECT 1")
        conn.close()
    except Exception:
        app.logger.exception("Readiness check failed")
        return jsonify(status="not ready"), 503
    return jsonify(status="ready")

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/notes")
def notes_page():
    return render_template("notes.html")

@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory(app.config["UPLOAD_FOLDER"], filename)

if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
