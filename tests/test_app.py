import os
import subprocess
import sys

import app as app_module


def test_home_page(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"CloudNotes" in response.data


def test_notes_page(client):
    assert client.get("/notes").status_code == 200


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_ready_when_database_works(client):
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ready"}


def test_ready_fails_but_health_passes_when_database_breaks(client, monkeypatch):
    def broken_connection(path):
        raise OSError("database unavailable")

    monkeypatch.setattr(app_module, "get_db_connection", broken_connection)
    assert client.get("/ready").status_code == 503
    assert client.get("/health").status_code == 200


def test_created_note_can_be_read_back(client):
    created = client.post("/api/notes", data={"title": "ci-note", "body": "from the pipeline"})
    assert created.status_code == 201

    notes = client.get("/api/notes").get_json()
    assert any(note["title"] == "ci-note" and note["body"] == "from the pipeline" for note in notes)


def test_app_refuses_to_start_without_secret_key():
    env = {key: value for key, value in os.environ.items() if key != "SECRET_KEY"}
    result = subprocess.run([sys.executable, "-c", "import app"], env=env, capture_output=True, text=True)
    assert result.returncode != 0
    assert "Missing required environment variable: SECRET_KEY" in result.stderr


def test_metrics_endpoint_counts_requests_by_route(client):
    client.get("/health")
    body = client.get("/metrics").get_data(as_text=True)
    assert 'http_requests_total{method="GET",path="/health",status="200"}' in body
    assert "http_request_duration_seconds_bucket" in body


def test_fault_route_is_off_by_default(client, monkeypatch):
    monkeypatch.delenv("FAULT_INJECTION", raising=False)
    assert client.get("/debug/fail").status_code == 404


def test_fault_route_returns_500_when_enabled(client, monkeypatch):
    monkeypatch.setenv("FAULT_INJECTION", "true")
    assert client.get("/debug/fail").status_code == 500
