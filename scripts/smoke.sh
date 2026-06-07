#!/usr/bin/env bash
set -euo pipefail

URL="${1:-https://dev.boutique.example.com}"
MAX_ATTEMPTS="${SMOKE_ATTEMPTS:-12}"
SLEEP_SEC="${SMOKE_SLEEP:-10}"

echo "Smoke test: ${URL}"
for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  if curl -fsS -o /dev/null -w "%{http_code}" "${URL}" | grep -qE '^200$'; then
    echo "OK (${i}/${MAX_ATTEMPTS})"
    exit 0
  fi
  echo "Attempt ${i}/${MAX_ATTEMPTS} failed; retry in ${SLEEP_SEC}s..."
  sleep "${SLEEP_SEC}"
done

echo "Smoke test failed after ${MAX_ATTEMPTS} attempts"
exit 1
