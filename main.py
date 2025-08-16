#!/usr/bin/env python3
import os, sys, time, json, requests
from config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

def log(msg):
    print(msg, flush=True)

def send_tg(text):
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        log(f"[tg] skipped (token/chat not set): {text}")
        return
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        requests.post(url, json={"chat_id": TELEGRAM_CHAT_ID, "text": text}, timeout=10)
    except Exception as e:
        log(f"[tg] error: {e}")

def load_predictions(path="predictions.json"):
    if not os.path.exists(path):
        return {}
    try:
        with open(path,"r") as f:
            return json.load(f)
    except Exception as e:
        log(f"[pred] read error: {e}")
        return {}

if __name__ == "__main__":
    log("BOOT Day-0 Termux bot up.")
    send_tg("🤖 Day-0 Termux bot up. Waiting for predictions.json from Drive…")
    last_blob = ""
    while True:
        # Pull fresh copy from Drive each loop (or use cron/termux-job later)
        os.system("./pull_predictions.sh >/dev/null 2>&1 || true")
        data = load_predictions()
        blob = json.dumps(data, sort_keys=True) if data else ""
        if data and blob != last_blob:
            last_blob = blob
            # Very light handling: just echo each asset’s signal
            lines = []
            for asset, payload in data.items():
                lines.append(f"{asset} → {payload}")
            msg = "📈 New predictions:\n" + "\n".join(lines)
            log(msg)
            send_tg(msg)
        time.sleep(30)
