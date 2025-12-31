#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
LOG=/tmp/npm_build.log
: >"$LOG" # truncate log
# If lockfile exists prefer deterministic install for CI
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund 2>&1 | tee -a "$LOG" || (tail -n 200 "$LOG" >&2 && echo 'npm ci failed' >&2 && exit 12)
else
  # No lockfile: ensure local deps present without changing package.json (no-save)
  npm install --no-audit --no-fund --no-save --silent 2>&1 | tee -a "$LOG" || (tail -n 200 "$LOG" >&2 && echo 'npm install (no-save) failed' >&2 && exit 11)
fi
# Run the project's build script; capture output and show helpful logs on failure
npm run build --silent 2>&1 | tee -a "$LOG" || (tail -n 200 "$LOG" >&2 && echo 'Build failed' >&2 && exit 13)
