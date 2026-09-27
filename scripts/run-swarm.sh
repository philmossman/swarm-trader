#!/bin/bash
# run-swarm.sh — Deterministic entry point for all swarm-trader cron runs.
# Handles all environment setup, dep validation, and stale-venv cleanup.
# Usage: bash scripts/run-swarm.sh <script.py> [args...]
#
# This script exists so cron prompts don't need to contain env/path instructions.
# All environment fragility lives here, in version control, not in cron messages.

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
    echo "[run-swarm] WARNING: Removing stale .venv (would shadow cache venv)" >&2
    rm -rf .venv
fi

# --- Guard: ensure python symlink exists ---
if ! command -v python &>/dev/null; then
    echo "[run-swarm] WARNING: 'python' not in PATH, creating symlink" >&2
    ln -sf /usr/bin/python3 /home/openclaw/.local/bin/python
fi

# --- Guard: verify core deps ---
if ! $POETRY run python -c "import yfinance, langchain, alpaca_trade_api" 2>/dev/null; then
    echo "[run-swarm] Core deps missing, running poetry install..." >&2
    $POETRY install --no-interaction
    # Re-check after install
    if ! $POETRY run python -c "import yfinance, langchain" 2>/dev/null; then
        echo "[run-swarm] FATAL: Dependencies still missing after poetry install" >&2
        exit 1
    fi
fi

# --- Run ---
echo "[run-swarm] Starting: $*" >&2
exec $POETRY run python "$@"
