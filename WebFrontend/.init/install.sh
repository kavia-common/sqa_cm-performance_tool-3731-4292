#!/usr/bin/env bash
set -euo pipefail
# install: project-local dependencies respecting package-lock.json
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
LOG=/tmp/npm_install.log
: > "$LOG" || true
# Ensure workspace exists
if [ ! -d "$WS" ]; then
  echo "Workspace not found: $WS" >&2
  exit 2
fi
# Quick sanity: node major >=18
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR=$(node -p "parseInt(process.versions.node.split('.')[0],10)") || NODE_MAJOR=0
  if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "Detected node major version $NODE_MAJOR; >=18 required. Cannot change node in-container." >&2
    exit 3
  fi
else
  echo "node executable not found on PATH" >&2
  exit 4
fi
# Run installs
if [ -f package-lock.json ]; then
  echo "package-lock.json found: running 'npm ci' (no package.json mutation)" | tee -a "$LOG"
  npm ci --no-audit --no-fund 2>&1 | tee -a "$LOG" || { echo "npm ci failed; tailing log:" >&2; tail -n 200 "$LOG" >&2; exit 5; }
else
  echo "No package-lock.json: installing minimal deps (react, react-dom, vite)" | tee -a "$LOG"
  # Install runtime deps
  npm i --no-audit --no-fund react@^18 react-dom@^18 --save 2>&1 | tee -a "$LOG" || { echo "npm i react/react-dom failed; tailing log:" >&2; tail -n 200 "$LOG" >&2; exit 6; }
  # Install vite as devDependency
  npm i --no-audit --no-fund vite@^5 --save-dev 2>&1 | tee -a "$LOG" || { echo "npm i vite failed; tailing log:" >&2; tail -n 200 "$LOG" >&2; exit 7; }
  # Optionally add http-server as devDependency for validation if not present
  if ! node -e "try{const p=require('./package.json'); process.exit(p.devDependencies&&p.devDependencies['http-server']?0:1)}catch(e){process.exit(1)}" 2>/dev/null; then
    npm i --no-audit --no-fund --save-dev http-server@^14 2>&1 | tee -a "$LOG" || { echo "npm i http-server failed; tailing log:" >&2; tail -n 200 "$LOG" >&2; exit 8; }
  else
    echo "http-server already present in devDependencies; skipping" | tee -a "$LOG"
  fi
fi
# Verify node and npm are available after install
command -v node >/dev/null || { echo "node missing after install" >&2; tail -n 200 "$LOG" >&2; exit 9; }
command -v npm >/dev/null || { echo "npm missing after install" >&2; tail -n 200 "$LOG" >&2; exit 10; }
# Print condensed success info
echo "Dependencies step completed. Log appended to $LOG" | tee -a "$LOG"
