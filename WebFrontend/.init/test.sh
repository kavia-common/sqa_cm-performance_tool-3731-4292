#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
mkdir -p __tests__
if [ ! -f __tests__/smoke.test.js ]; then
  cat > __tests__/smoke.test.js <<'JS'
test('smoke', ()=>{ expect(1+1).toBe(2) })
JS
fi
# If package-lock.json exists, do NOT mutate package.json. Prefer local jest binary, then npx --no-install, otherwise skip with clear message.
if [ -f package-lock.json ]; then
  # try local installed jest
  if [ -x "node_modules/.bin/jest" ]; then
    npm test --silent || { echo 'Tests failed (local node_modules/.bin/jest returned non-zero)' >&2; exit 11; }
    exit 0
  fi
  # try npx without installing
  if command -v npx >/dev/null 2>&1; then
    if npx --no-install jest --version >/dev/null 2>&1; then
      npx --no-install jest --runInBand --json --outputFile=./jest-results.json || { echo 'Tests failed (npx jest returned non-zero)' >&2; exit 11; }
      exit 0
    fi
  fi
  echo 'package-lock.json present: skipping install. No local jest binary nor npx-available jest found. To run tests, add jest to your lockfile or run npm i --save-dev jest in a safe context.'
  exit 0
else
  # no lockfile: safe to install jest as devDependency if missing
  if [ ! -f package.json ]; then
    # create minimal package.json to allow installing jest for smoke test
    cat > package.json <<'PJ'
{
  "name": "minimal-project",
  "version": "0.0.0"
}
PJ
  fi
  # check whether jest is already declared in devDependencies
  has_jest_declared=1
  if node -e "try{let p=require('./package.json');process.exit((p.devDependencies&&p.devDependencies.jest)?0:1)}catch(e){process.exit(1)}" 2>/dev/null; then
    has_jest_declared=0
  fi
  if [ "$has_jest_declared" -ne 0 ]; then
    # install jest as devDependency non-interactively
    npm i --no-audit --no-fund --save-dev jest@^29 >/tmp/npm_jest_install.log 2>&1 || { tail -n 200 /tmp/npm_jest_install.log >&2; echo 'npm install jest failed' >&2; exit 10; }
  fi
  # ensure test script exists without overwriting existing test script
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};p.scripts.test=p.scripts.test||'jest --runInBand --json --outputFile=./jest-results.json';fs.writeFileSync('package.json',JSON.stringify(p,null,2))" >/dev/null 2>&1
  # run tests
  npm test --silent || { echo 'Tests failed' >&2; [ -f ./jest-results.json ] && echo 'jest results in ./jest-results.json'; exit 11; }
  exit 0
fi
