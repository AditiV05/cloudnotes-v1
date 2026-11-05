import os
import tempfile

import pytest

# app.py reads DATA_DIR when it is imported, so set it first.
os.environ["DATA_DIR"] = tempfile.mkdtemp(prefix="cloudnotes-tests-")

from app import app as flask_app  # noqa: E402


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    return flask_app.test_client()
