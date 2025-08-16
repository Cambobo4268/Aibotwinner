#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
~/ai_bot/poll_predictions.sh
python3 ~/ai_bot/consume_signals.py
