#!/usr/bin/env bash
set -euo pipefail
# Validation: serve ./dist with http-server (local preferred) or npx fallback
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
# prefer local http-server
HS_LOCAL="$WS/node_modules/.bin/http-server"
if [ -x "$HS_LOCAL" ]; then HS_CMD=("$HS_LOCAL"); elif command -v npx >/dev/null 2>&1; then HS_CMD=(npx --no-install http-server); else echo "http-server not available (local bin or npx). Install http-server devDependency or ensure npx present." >&2; exit 14; fi
# Verify dist exists
if [ ! -d "./dist" ]; then echo "dist directory not found at $WS/dist" >&2; exit 20; fi
# Find free port by trying a short list using python3 bind check
PORT=0
for p in 8080 8081 8082 8083 8084 8085 8086 8087 8088 8089; do
  python3 - <<PYCODE >/dev/null 2>&1
import socket,sys
s=socket.socket()
try:
  s.bind(('127.0.0.1', %d))
  s.close()
  sys.exit(0)
except:
  sys.exit(1)
PYCODE
  if [ $? -eq 0 ]; then PORT=$p; break; fi
done
if [ "$PORT" -eq 0 ]; then echo "No free port found" >&2; exit 15; fi
# Start server safely with tokenized command array and log to tmp
LOG=/tmp/http_server.log
"${HS_CMD[@]}" ./dist -p "$PORT" >/tmp/http_server.log 2>&1 &
HS_PID=$!
# Probe readiness for up to MAX_WAIT seconds
MAX_WAIT=30
i=0
while [ $i -lt $MAX_WAIT ]; do
  sleep 1
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" 2>/dev/null || echo 000)
  if echo "$CODE" | grep -E '^[23][0-9][0-9]$' >/dev/null; then break; fi
  i=$((i+1))
done
if [ $i -ge $MAX_WAIT ]; then
  echo "Validation failed: server not ready after ${MAX_WAIT}s" >&2
  tail -n 200 "$LOG" || true
  kill $HS_PID 2>/dev/null || true
  exit 16
fi
# Evidence
echo "build_ok=true"
echo "served_at=http://127.0.0.1:$PORT/"
# Show a short snippet of server log for evidence
echo "--- http-server log (last 50 lines) ---"
tail -n 50 "$LOG" || true
# Cleanup
kill $HS_PID 2>/dev/null || true
sleep 1
