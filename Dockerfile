FROM python:3.11-slim

# Install system deps for Lean (if you want Lean in container)
RUN apt-get update && apt-get install -y git curl build-essential ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps (no extras required here)
WORKDIR /app
COPY python/codex_sim.py /app/codex_sim.py
COPY tests /app/tests

RUN pip install --no-cache-dir pytest

# Entrypoint for running sim
ENTRYPOINT ["python", "codex_sim.py"]
