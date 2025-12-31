#!/usr/bin/env bash
set -euo pipefail
# Idempotently scaffold minimal Vite+React project in workspace
WS="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WS"
# Ensure Node major >=18
NODE_MAJOR=$(node -p "parseInt(process.versions.node.split('.')[0],10)")
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "ERROR: Node major version is $NODE_MAJOR; >=18 required by policy. Cannot change Node in-container." >&2
  exit 2
fi
# Ensure package.json exists
if [ ! -f package.json ]; then
  npm init -y >/tmp/npm_init.log 2>&1
fi
# Detect TypeScript usage: scan files or package.json deps
use_ts=0
if find . -path ./node_modules -prune -o -type f \( -name '*.ts' -o -name '*.tsx' \) -print -quit | grep -q .; then use_ts=1; fi
if [ -f package.json ]; then
  if node -e "let p=require('./package.json'); if((p.dependencies&&p.dependencies.typescript)||(p.devDependencies&&p.devDependencies.typescript)) process.exit(0); process.exit(1)" 2>/dev/null; then use_ts=1; fi
fi
# Add missing scripts without overwriting other package.json fields
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'))||{};p.scripts=p.scripts||{};p.scripts.dev=p.scripts.dev||'vite';p.scripts.build=p.scripts.build||'vite build';p.scripts.preview=p.scripts.preview||'vite preview --port 5000';p.scripts.start=p.scripts.start||'npm run preview';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" >/dev/null
# Create src dir and minimal files idempotently
mkdir -p src
if [ "$use_ts" -eq 1 ]; then
  MAIN_FILE="src/main.tsx"
  [ -f src/main.tsx ] || cat > src/main.tsx <<'TS'
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
const root = document.getElementById('root')
if (root) createRoot(root).render(<App />)
TS
  [ -f src/App.tsx ] || cat > src/App.tsx <<'TS'
export default function App(){ return <div>Vite React App (TS)</div> }
TS
  [ -f tsconfig.json ] || cat > tsconfig.json <<'TSJ'
{
  "compilerOptions": {
    "target": "es2020",
    "module": "esnext",
    "jsx": "react-jsx",
    "moduleResolution": "node",
    "esModuleInterop": true
  }
}
TSJ
else
  MAIN_FILE="src/main.jsx"
  [ -f src/main.jsx ] || cat > src/main.jsx <<'JS'
import React from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
const root = document.getElementById('root')
if (root) createRoot(root).render(<App />)
JS
  [ -f src/App.jsx ] || cat > src/App.jsx <<'JS'
export default function App(){ return <div>Vite React App</div> }
JS
fi
# Create index.html referencing the module relatively
if [ ! -f index.html ]; then
  cat > index.html <<HTML
<!doctype html>
<html>
  <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" /><title>WebFrontend</title></head>
  <body><div id="root"></div><script type="module" src="${MAIN_FILE}"></script></body>
</html>
HTML
fi
# Small config showing env consumption
if [ ! -f src/config.js ]; then
  cat > src/config.js <<'CFG'
export const API_URL = process.env.API_URL || '/api'
CFG
fi
# Success
echo "Scaffolding completed (use_ts=$use_ts)"
