#!/usr/bin/env bash
# Pre-deploy QA gate. Stage 1 (before the build): text, translation, content, UI widget sweep, audio (with auto-fix).
# Stage 2 (after the build, QA_URL = locally served build/web): screenshots at three phone sizes.
# Any blocking issue exits non-zero and the deploy script stops. Report: build/qa/report.html
set -o pipefail
cd "$(dirname "$0")/../.."
if [ "$1" = "post" ]; then
  python3 tool/qa/run_qa.py --only shots --shots "${QA_URL:-http://localhost:8765/}"
else
  python3 tool/qa/run_qa.py --fix --stt "${QA_STT:-150}"
fi
