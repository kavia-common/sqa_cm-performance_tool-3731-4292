#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend"
cd "$WORKSPACE"
USE_TS=${USE_TS:-0}
LOG_DIR="$WORKSPACE/.logs"; mkdir -p "$LOG_DIR"
DEP_LOG="$LOG_DIR/deps.log"
: >"$DEP_LOG" || true
# choose package manager: prefer yarn if yarn.lock exists or yarn binary is available
if [ -f yarn.lock ] || command -v yarn >/dev/null 2>&1; then PM="yarn"; else PM="npm"; fi
# lockfile-driven install
if [ "$PM" = "yarn" ]; then
  if [ -f yarn.lock ]; then yarn install --frozen-lockfile >>"$DEP_LOG" 2>&1; else yarn install >>"$DEP_LOG" 2>&1; fi
else
  if [ -f package-lock.json ]; then npm ci --no-audit --no-fund >>"$DEP_LOG" 2>&1; else npm i --no-audit --no-fund >>"$DEP_LOG" 2>&1; fi
fi
# helper to check package presence using package.json (avoid quoting issues)
has_pkg(){ pkg="$1"; node -e "const fs=require('fs');const p='./package.json';if(!fs.existsSync(p)){process.exit(1);}const pkg=JSON.parse(fs.readFileSync(p));const deps=Object.assign({},pkg.dependencies||{},pkg.devDependencies||{});process.exit(deps[process.argv[1]]?0:1);" "$pkg";
}
# install helpers
_install(){ pkg="$1";
 if [ "$PM" = "yarn" ]; then yarn add "$pkg" >>"$DEP_LOG" 2>&1; else npm i "$pkg" --no-audit --no-fund >>"$DEP_LOG" 2>&1; fi
}
_install_dev(){ pkg="$1";
 if [ "$PM" = "yarn" ]; then yarn add -D "$pkg" >>"$DEP_LOG" 2>&1; else npm i -D --no-audit --no-fund "$pkg" >>"$DEP_LOG" 2>&1; fi
}
# Ensure core libs react/react-dom
has_pkg react || _install "react@^18.0.0"
has_pkg react-dom || _install "react-dom@^18.0.0"
# Ensure lightweight state mgmt
has_pkg zustand || _install "zustand"
# Testing libraries (dev)
has_pkg "@testing-library/react" || _install_dev "@testing-library/react"
has_pkg "@testing-library/jest-dom" || _install_dev "@testing-library/jest-dom"
# TypeScript dev deps if requested
if [ "$USE_TS" = "1" ]; then
  has_pkg typescript || _install_dev "typescript"
  has_pkg "ts-jest" || _install_dev "ts-jest"
  has_pkg "@types/jest" || _install_dev "@types/jest"
  has_pkg "@types/react" || _install_dev "@types/react"
  has_pkg "@types/react-dom" || _install_dev "@types/react-dom"
fi
# serve for validation (dev dep)
has_pkg serve || _install_dev "serve"
# record versions for debugging
node -v >>"$DEP_LOG" 2>&1 || true
npm -v >>"$DEP_LOG" 2>&1 || true
command -v yarn >/dev/null 2>&1 && yarn -v >>"$DEP_LOG" 2>&1 || true
