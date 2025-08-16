#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
. ~/.ai_bot_env

# Try Telegram first
if python3 ~/ai_bot/poll_telegram_json.py; then
  exit 0
fi

# Fallback to old URL poller (kept for later)
~/ai_bot/poll_predictions.sh || true
