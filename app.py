from flask import Flask, render_template, request, redirect, url_for, send_from_directory
from api.routes import api_bp
from utils.helpers import init_db
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
DATABASE_PATH = os.path.join(BASE_DIR, "database", "cloudnotes.db")

app = Flask(__name__)
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["DATABASE_PATH"] = DATABASE_PATH
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024

app.register_blueprint(api_bp, url_prefix="/api")

# Flask 2.3 removed before_first_request, so set up once at startup.
init_db(DATABASE_PATH)
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

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
