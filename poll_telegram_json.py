#!/usr/bin/env python3
import os, sys, json, time, urllib.request, urllib.parse, pathlib

BASE = pathlib.Path(os.path.expanduser("~/ai_bot"))
ART  = BASE / "artifacts"
TMP  = ART / "tmp"
STATE= ART / "tg_state.json"
OUT  = ART / "predictions.json"
LOG  = ART / "poll_tg.log"
for d in (ART, TMP):
    d.mkdir(parents=True, exist_ok=True)

def env(name):
    v = os.environ.get(name, "")
    if not v:
        print(f"ERROR: missing env {name}", file=sys.stderr); sys.exit(2)
    return v

def tg_get(url, params=None):
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent":"tg-poller/1.0"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))

def extract_json(text):
    if not text: return None
    # find ```json ... ``` or plain { ... }
    if "```json" in text:
        a = text.split("```json",1)[1]
        b = a.split("```",1)[0]
        return b.strip()
    if text.lstrip().startswith("{") and text.rstrip().endswith("}"):
        return text.strip()
    return None

def save_state(offset):
    STATE.write_text(json.dumps({"offset":offset}), encoding="utf-8")

def load_state():
    if STATE.exists():
        try: return json.loads(STATE.read_text())["offset"]
        except: return 0
    return 0

def validate_and_write(s):
    try:
        data = json.loads(s)
        if not isinstance(data.get("signals"), list):
            raise ValueError("no signals[]")
        for k in ("symbol","action","confidence"):
            if not all(isinstance(x, dict) and k in x for x in data["signals"]):
                raise ValueError(f"missing {k}")
        OUT.write_text(json.dumps(data, indent=2), encoding="utf-8")
        with LOG.open("a", encoding="utf-8") as lf: lf.write("OK wrote predictions.json\n")
        print("OK: predictions.json updated")
        return True
    except Exception as e:
        with LOG.open("a", encoding="utf-8") as lf: lf.write(f"FAIL: {e}\n")
        print(f"ERROR: invalid JSON from Telegram: {e}", file=sys.stderr)
        return False

def main():
    # load env
    # shell must have sourced ~/.ai_bot_env before running this script
    token = env("BOT_TOKEN")
    chat_id = env("CHAT_ID")
    api = f"https://api.telegram.org/bot{urllib.parse.quote(token)}/"

    offset = load_state()
    params = {"timeout": 0, "allowed_updates": json.dumps(["message"])}

    # one-shot poll (not a daemon): fetch latest page of updates and exit
    if offset: params["offset"] = offset
    data = tg_get(api + "getUpdates", params)
    if not data.get("ok"):
        print("ERROR: getUpdates not ok", file=sys.stderr); sys.exit(8)

    latest = offset
    grabbed = False
    for upd in data.get("result", []):
        update_id = upd.get("update_id", 0)
        latest = max(latest, update_id + 1)
        msg = upd.get("message") or {}
        # only accept messages from the configured chat id
        if str(msg.get("chat", {}).get("id", "")) != str(chat_id):
            continue
        text = msg.get("text","")
        js = extract_json(text)
        if js and validate_and_write(js):
            grabbed = True

    if latest != offset:
        save_state(latest)

    if not grabbed:
        print("NO_NEW_JSON")  # useful for cron/logic
        sys.exit(1)

if __name__ == "__main__":
    main()
