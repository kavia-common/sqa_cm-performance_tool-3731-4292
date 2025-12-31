#!/usr/bin/env bash
set -euo pipefail
# validation continuation fragment: expects the inline Node server code to have been written
# and started by earlier concatenated script portions. Variables expected from parent:
#   PORT (port server listens on), VAL_LOG (path to validation log), START_PID (pid of node)
# This fragment validates START_PID, polls for readiness (HTTP 200), logs evidence, and stops server.
VAL_LOG=${VAL_LOG:-"/tmp/validation.log"}
PORT=${PORT:-3000}
START_PID=${START_PID:-}
# validate PID
if [ -z "${START_PID:-}" ] || ! kill -0 "${START_PID}" 2>/dev/null; then
  echo "failed to start server (missing or invalid START_PID=${START_PID:-})" | tee -a "$VAL_LOG" >&2
  exit 32
fi
trap 'if [ -n "${START_PID:-}" ] && kill -0 "${START_PID}" 2>/dev/null; then kill "${START_PID}" 2>/dev/null || true; fi; sleep 1' EXIT INT TERM
# readiness loop (30s)
READY=0
HTTP_CODE=000
for i in $(seq 1 30); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT/" || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    READY=1
    break
  fi
  sleep 1
done
if [ "$READY" -ne 1 ]; then
  echo "Validation failed: server did not return 200 (last code ${HTTP_CODE})" | tee -a "$VAL_LOG" >&2
  tail -n 200 "$VAL_LOG" || true
  # attempt to capture node stdout/stderr if still running
  if [ -n "${START_PID:-}" ] && kill -0 "${START_PID}" 2>/dev/null; then
    echo "server still running pid=${START_PID}, attempting kill" | tee -a "$VAL_LOG"
    kill "${START_PID}" 2>/dev/null || true
  fi
  exit 33
fi
# evidence
echo "validation: http_status=$HTTP_CODE pid=$START_PID" | tee -a "$VAL_LOG"
if [ -f build/index.html ]; then
  sed -n '1,80p' build/index.html >>"$VAL_LOG" || true
else
  echo "build/index.html not found" >>"$VAL_LOG"
fi
du -sh build >>"$VAL_LOG" || true
# clean stop
if [ -n "${START_PID:-}" ] && kill -0 "${START_PID}" 2>/dev/null; then
  kill "$START_PID" 2>/dev/null || true
fi
sleep 1
trap - EXIT INT TERM
