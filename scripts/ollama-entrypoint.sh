#!/bin/sh
set -eu

MODEL="${OLLAMA_MODEL:-llama3:8b}"

echo "[ollama-entrypoint] Starting Ollama server..."
ollama serve &
OLLAMA_PID=$!

cleanup() {
  echo "[ollama-entrypoint] Shutting down Ollama server..."
  kill "$OLLAMA_PID" 2>/dev/null || true
}
trap cleanup INT TERM

# Wait for Ollama API readiness before pulling the model.
ATTEMPTS=0
MAX_ATTEMPTS=60
until ollama list >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
    echo "[ollama-entrypoint] Ollama API did not become ready in time."
    exit 1
  fi
  sleep 2
done

echo "[ollama-entrypoint] Pulling model: ${MODEL}"
ollama pull "$MODEL"

echo "[ollama-entrypoint] Model is ready."
wait "$OLLAMA_PID"
