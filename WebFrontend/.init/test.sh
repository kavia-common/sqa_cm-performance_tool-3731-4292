#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WORKSPACE"
USE_TS=${USE_TS:-0}
LOG_DIR="$WORKSPACE/.logs"; mkdir -p "$LOG_DIR"
TEST_LOG="$LOG_DIR/test.log"
EXT="js"; [ "$USE_TS" = "1" ] && EXT="ts"
# create smoke test
mkdir -p src/__tests__
cat > src/__tests__/smoke.test.${EXT} <<'EOF'
// Minimal smoke test
describe('smoke', () => { test('true is true', () => expect(true).toBe(true)); });
EOF
# detect runner with node helper
RUNNER=$(node -e "const fs=require('fs');const p='./package.json';if(!fs.existsSync(p)){console.log('jest');process.exit(0);}const pkg=JSON.parse(fs.readFileSync(p));const deps=Object.assign({},pkg.devDependencies||{},pkg.dependencies||{});if(deps['react-scripts']){console.log('react-scripts');}else if(deps['vitest']){console.log('vitest');}else if(deps['jest']||pkg.scripts&&pkg.scripts.test){console.log('jest');}else{console.log('jest');}")
# choose runner binary preferring local node_modules/.bin
CMD=()
if [ "$RUNNER" = "react-scripts" ]; then
  if [ -x "./node_modules/.bin/react-scripts" ]; then CMD=("./node_modules/.bin/react-scripts" test --watchAll=false --runInBand); else CMD=(npx react-scripts test --watchAll=false --runInBand); fi
elif [ "$RUNNER" = "vitest" ]; then
  if [ -x "./node_modules/.bin/vitest" ]; then CMD=("./node_modules/.bin/vitest" run --reporter verbose); else CMD=(npx -y vitest run --reporter verbose); fi
else
  if [ -x "./node_modules/.bin/jest" ]; then CMD=("./node_modules/.bin/jest" --runInBand --silent); else CMD=(npx -y jest --runInBand --silent); fi
fi
# Prevent running user-defined interactive npm test script that might do watch: detect 'watch' flag in package.json test script
if node -e "const fs=require('fs');const p='./package.json';if(!fs.existsSync(p))process.exit(0);const pkg=JSON.parse(fs.readFileSync(p));const s=(pkg.scripts&&pkg.scripts.test||'');if(/watch/.test(s))process.exit(1);"; then :; else echo 'Detected interactive npm test script; using direct runner instead' >>"$TEST_LOG"; fi
printf "Running tests with: %s\n" "${CMD[*]}" >"$TEST_LOG"
if "${CMD[@]}" >>"$TEST_LOG" 2>&1; then printf "tests: PASS\n" >>"$TEST_LOG"; else printf "tests: FAIL (see %s)\n" "$TEST_LOG" >&2; tail -n 200 "$TEST_LOG" >&2 || true; exit 20; fi
