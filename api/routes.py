from flask import Blueprint, jsonify, request, current_app
from werkzeug.utils import secure_filename
from utils.helpers import get_db_connection, allowed_file
import os

api_bp = Blueprint("api", __name__)


@api_bp.route("/notes", methods=["GET"])
def get_notes():
    conn = get_db_connection(current_app.config["DATABASE_PATH"])
    current_app.logger.info("listing notes")
    notes = conn.execute("SELECT id, title, body, filename, created_at FROM notes ORDER BY created_at DESC").fetchall()
    conn.close()
    return jsonify([dict(note) for note in notes])


@api_bp.route("/notes", methods=["POST"])
def create_note():
    current_app.logger.info("saving note")
    title = request.form.get("title", "Untitled Note")
    body = request.form.get("body", "")
    filename = None

    uploaded_file = request.files.get("attachment")
    if uploaded_file and allowed_file(uploaded_file.filename):
        filename = secure_filename(uploaded_file.filename)
        destination = os.path.join(current_app.config["UPLOAD_FOLDER"], filename)
        uploaded_file.save(destination)

    conn = get_db_connection(current_app.config["DATABASE_PATH"])
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO notes (title, body, filename) VALUES (?, ?, ?)",
        (title, body, filename),
    )
    conn.commit()
    note_id = cursor.lastrowid
    conn.close()
    current_app.logger.info("note saved", extra={"fields": {"note_id": note_id}})

    return jsonify({"id": note_id, "title": title, "body": body, "filename": filename}), 201


@api_bp.route("/notes/<int:note_id>", methods=["GET"])
def get_note(note_id):
    conn = get_db_connection(current_app.config["DATABASE_PATH"])
    note = conn.execute("SELECT id, title, body, filename, created_at FROM notes WHERE id = ?", (note_id,)).fetchone()
    conn.close()
    if note is None:
        return jsonify({"error": "Note not found"}), 404
    return jsonify(dict(note))


@api_bp.route("/notes/<int:note_id>", methods=["DELETE"])
def delete_note(note_id):
    conn = get_db_connection(current_app.config["DATABASE_PATH"])
    cursor = conn.cursor()
    cursor.execute("DELETE FROM notes WHERE id = ?", (note_id,))
    conn.commit()
    deleted = cursor.rowcount
    conn.close()
    if deleted == 0:
        return jsonify({"error": "Note not found"}), 404
    return jsonify({"message": "Note deleted"}), 200
