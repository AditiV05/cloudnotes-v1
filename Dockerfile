# Alternative path: run CloudNotes in a Linux container (no systemd needed).
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
# Run migrations, then gunicorn bound to all interfaces.
CMD ["sh", "-c", "python migrate.py && exec gunicorn --workers 2 --bind 0.0.0.0:5000 --access-logfile - app:app"]
