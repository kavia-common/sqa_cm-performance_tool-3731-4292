#!/usr/bin/env bash
set -euo pipefail
# Minimal idempotent React scaffolding for container workspace
WORKSPACE="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"
USE_TS=${USE_TS:-0}
VITE=${VITE:-0}
LOG_DIR="$WORKSPACE/.logs"; mkdir -p "$LOG_DIR"
SC_LOG="$LOG_DIR/scaffold.log"
# detect non-empty workspace (ignore .logs)
shopt -s dotglob || true
NONEMPTY=0
if find "$WORKSPACE" -mindepth 1 -maxdepth 1 ! -name '.logs' | read -r _; then NONEMPTY=1; fi
# if package.json already present, skip scaffold
if [ -f "$WORKSPACE/package.json" ]; then echo "package.json exists, skipping scaffold" >"$SC_LOG"; exit 0; fi
# use staging dir if workspace non-empty to avoid CRA/Vite refusal
STAGE="$(mktemp -d)"
cleanup(){ rm -rf "$STAGE" 2>/dev/null || true; }
trap cleanup EXIT
# prefer preinstalled tools
if [ "$VITE" = "1" ]; then
  if command -v yarn >/dev/null 2>&1; then
    (cd "$STAGE" && yarn create vite app --template "react${USE_TS:+-ts}") >>"$SC_LOG" 2>&1 || { echo "vite scaffold failed" >>"$SC_LOG"; exit 12; }
  else
    (cd "$STAGE" && npm create vite@latest app -- --template "react${USE_TS:+-ts}") >>"$SC_LOG" 2>&1 || { echo "vite scaffold failed" >>"$SC_LOG"; exit 12; }
  fi
else
  if command -v create-react-app >/dev/null 2>&1; then
    (cd "$STAGE" && create-react-app app ${USE_TS:+--template typescript}) >>"$SC_LOG" 2>&1 || { echo "create-react-app failed" >>"$SC_LOG"; exit 13; }
  elif command -v yarn >/dev/null 2>&1; then
    (cd "$STAGE" && yarn create react-app app ${USE_TS:+--template typescript}) >>"$SC_LOG" 2>&1 || { echo "yarn create react-app failed" >>"$SC_LOG"; exit 13; }
  else
    # last-resort fallback
    (cd "$STAGE" && npx --yes create-react-app@5.0.1 app ${USE_TS:+--template typescript}) >>"$SC_LOG" 2>&1 || { echo "npx create-react-app failed" >>"$SC_LOG"; exit 13; }
  fi
fi
# move staged app into workspace root only if package.json not present
if [ -d "$STAGE/app" ]; then
  # copy respecting existing files; do not overwrite existing files
  (cd "$STAGE/app" && tar -cf - .) | (cd "$WORKSPACE" && tar -xpf -)
fi
# verify package.json created
if [ ! -f "$WORKSPACE/package.json" ]; then echo "scaffold failed, package.json missing" >>"$SC_LOG" && tail -n 200 "$SC_LOG" || true && exit 10; fi
# backup package.json then add safe scripts if missing (atomic replace)
pkgbak="$WORKSPACE/package.json.bak.$(date +%s)"
cp "$WORKSPACE/package.json" "$pkgbak"
# Use node to merge scripts without overwriting existing ones
node -e "const fs=require('fs');const p=process.argv[1];let pkg=JSON.parse(fs.readFileSync(p));pkg.scripts=pkg.scripts||{};if(!pkg.scripts.ci) pkg.scripts.ci='npm ci'; if(!pkg.scripts.serve) pkg.scripts.serve='serve -s build -l \$PORT';fs.writeFileSync(p,JSON.stringify(pkg,null,2));" "$WORKSPACE/package.json" || { cp "$pkgbak" "$WORKSPACE/package.json"; echo 'failed to update package.json' >>"$SC_LOG"; exit 11; }
# create .env files only if absent
[ -f "$WORKSPACE/.env" ] || cat > "$WORKSPACE/.env" <<'EOF'
REACT_APP_API_ENDPOINT=http://localhost:8000/api
EOF
[ -f "$WORKSPACE/.env.production" ] || cat > "$WORKSPACE/.env.production" <<'EOF'
REACT_APP_API_ENDPOINT=https://api.example.invalid
EOF
echo "scaffold completed" >>"$SC_LOG"
