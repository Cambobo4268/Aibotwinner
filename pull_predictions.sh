#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Read FILE_ID from .env
FILE_ID="$(awk -F= '/^DRIVE_FILE_ID=/{print $2}' .env | tr -d '\r')"
if [ -z "${FILE_ID:-}" ]; then
  echo "[pull] DRIVE_FILE_ID not set in .env yet."
  exit 0
fi

URL="https://drive.google.com/uc?export=download&id=${FILE_ID}"
TMP="predictions.json.tmp"
OUT="predictions.json"

# Fetch with curl
HTTP_CODE=$(curl -sSL -w '%{http_code}' -o "$TMP" "$URL" || true)
if [ "$HTTP_CODE" != "200" ]; then
  echo "[pull] download failed: HTTP ${HTTP_CODE}"
  rm -f "$TMP"
  exit 0
fi

# Basic sanity: ensure it's JSON
if jq . "$TMP" >/dev/null 2>&1; then
  mv "$TMP" "$OUT"
  echo "[pull] updated $OUT"
else
  echo "[pull] not valid JSON; keeping old file."
  rm -f "$TMP"
fi
