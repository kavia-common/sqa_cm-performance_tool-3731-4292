#!/usr/bin/env bash
set -euo pipefail
# start Vite dev server detached with readiness probe; idempotent and cleans stale pidfile
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
PIDFILE="$WS/.vite_dev.pid"
LOGFILE="/tmp/vite_dev.log"
PORT=${VITE_PORT:-5173}
MAX_WAIT=${VITE_START_TIMEOUT:-60}
# Validate existing pidfile refers to node/vite
if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    if [ -r "/proc/$PID/cmdline" ]; then
      CMDLINE=$(tr '\0' ' ' < /proc/$PID/cmdline || true)
      case "$CMDLINE" in *node*|*vite*)
        echo "Vite dev server already running pid=$PID"
        echo "vite_dev_pid=$PID; url=http://127.0.0.1:$PORT; logs=$LOGFILE"
        exit 0
        ;;
      esac
    fi
  fi
  # stale or invalid pidfile
  rm -f "$PIDFILE" || true
fi
# Ensure log file exists and is writable
mkdir -p "$(dirname "$LOGFILE")"
: > "$LOGFILE"
# Start detached using setsid so it won't be killed when this script exits
# Ensure npm dev script exists; fail clearly if not
if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found on PATH" >&2
  exit 11
fi
# Start the dev server in background, capturing pid
setsid npm run dev --silent >"$LOGFILE" 2>&1 &
VID=$!
echo "$VID" > "$PIDFILE"
# readiness probe
i=0
while [ $i -lt "$MAX_WAIT" ]; do
  sleep 1
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" 2>/dev/null || true)
  if echo "$HTTP_CODE" | grep -E '^[23][0-9][0-9]$' >/dev/null; then
    echo "vite_dev_pid=$VID; url=http://127.0.0.1:$PORT; logs=$LOGFILE"
    exit 0
  fi
  i=$((i+1))
done
# failure: print recent logs
echo "Vite dev server did not become ready within $MAX_WAIT seconds" >&2
echo "--- last 200 lines of $LOGFILE ---" >&2
tail -n 200 "$LOGFILE" || true
exit 12
