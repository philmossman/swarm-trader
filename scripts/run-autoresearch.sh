#!/bin/bash
# run-autoresearch.sh — Deterministic entry point for AutoResearch strategy evolution.
# Handles env setup, dep validation, and time-bounded execution.
# Usage: bash scripts/run-autoresearch.sh [--iterations N] [--backtest-days N] [--max-runtime-minutes N]
#
# Default: 15 iterations, 10 backtest days, 50 minute max runtime
# (cron session timeout is ~60 min; we stop at 50 to ensure clean exit)

set -euo pipefail

# --- Environment ---
export HOME=/home/openclaw
export PATH="/home/openclaw/.local/bin:/home/openclaw/.npm-global/bin:$PATH"
export POETRY_CACHE_DIR=/home/openclaw/.cache/pypoetry
export PYTHONUNBUFFERED=1

POETRY=/home/openclaw/.local/bin/poetry
PROJECT=/home/openclaw/.openclaw/workspace/projects/swarm-trader

cd "$PROJECT"

# --- Guard: remove any stale in-project .venv ---
if [ -d ".venv" ]; then
    echo "[run-autoresearch] WARNING: Removing stale .venv" >&2
    rm -rf .venv
fi

# --- Guard: ensure python symlink exists ---
if ! command -v python &>/dev/null; then
    echo "[run-autoresearch] WARNING: 'python' not in PATH, creating symlink" >&2
    ln -sf /usr/bin/python3 /home/openclaw/.local/bin/python
fi

# --- Guard: verify core deps ---
if ! $POETRY run python -c "import yfinance, httpx, dotenv" 2>/dev/null; then
    echo "[run-autoresearch] Core deps missing, running poetry install..." >&2
    $POETRY install --no-interaction
fi

# --- Run ---
ITERATIONS=${1:-15}
BACKTEST_DAYS=${2:-10}
MAX_RUNTIME=${3:-50}

echo "[run-autoresearch] Starting: iterations=$ITERATIONS backtest_days=$BACKTEST_DAYS max_runtime=${MAX_RUNTIME}min" >&2
exec $POETRY run python autoresearch/evolve.py \
    --iterations "$ITERATIONS" \
    --backtest-days "$BACKTEST_DAYS" \
    --max-runtime-minutes "$MAX_RUNTIME"
