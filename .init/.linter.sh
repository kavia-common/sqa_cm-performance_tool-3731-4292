#!/bin/bash
cd /home/kavia/workspace/code-generation/sqa_cm-performance_tool-3731-4292/WebFrontend
npm run build
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
   exit 1
fi

