import os

from flask import Blueprint, current_app, jsonify, request
from werkzeug.utils import secure_filename

from utils.helpers import allowed_file, get_db_connection

api_bp = Blueprint("api", __name__)


def _serialize(note):
    note = dict(note)
    if note.get("created_at") is not None:
        note["created_at"] = note["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    return note


@api_bp.route("/notes", methods=["GET"])
def get_notes():
    conn = get_db_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, title, body, filename, created_at FROM notes ORDER BY created_at DESC")
        notes = cur.fetchall()
    conn.close()
    return jsonify([_serialize(note) for note in notes])


@api_bp.route("/notes", methods=["POST"])
def create_note():
    title = request.form.get("title") or "Untitled Note"
    body = request.form.get("body", "")
    filename = None

    uploaded_file = request.files.get("attachment")
    if uploaded_file and allowed_file(uploaded_file.filename):
        filename = secure_filename(uploaded_file.filename)
        destination = os.path.join(current_app.config["UPLOAD_FOLDER"], filename)
        uploaded_file.save(destination)

    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO notes (title, body, filename) VALUES (%s, %s, %s) RETURNING id",
            (title, body, filename),
        )
        note_id = cur.fetchone()["id"]
    conn.close()

    return jsonify({"id": note_id, "title": title, "body": body, "filename": filename}), 201


@api_bp.route("/notes/<int:note_id>", methods=["GET"])
def get_note(note_id):
    conn = get_db_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, title, body, filename, created_at FROM notes WHERE id = %s", (note_id,))
        note = cur.fetchone()
    conn.close()
    if note is None:
        return jsonify({"error": "Note not found"}), 404
    return jsonify(_serialize(note))


@api_bp.route("/notes/<int:note_id>", methods=["DELETE"])
def delete_note(note_id):
    conn = get_db_connection()
    with conn, conn.cursor() as cur:
        cur.execute("DELETE FROM notes WHERE id = %s", (note_id,))
        deleted = cur.rowcount
    conn.close()
    if deleted == 0:
        return jsonify({"error": "Note not found"}), 404
    return jsonify({"message": "Note deleted"}), 200
