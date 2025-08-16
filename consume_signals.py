#!/usr/bin/env python3
"""
Reads ~/ai_bot/artifacts/predictions.json and prints a simple action table.
Fails fast with a non-zero code if the file is missing or invalid.
Schema expected:
{
  "version": "...",
  "timestamp": "...",
  "signals": [
    {"symbol": "...", "action": "buy|sell|hold", "confidence": 0.0..1.0},
    ...
  ]
}
"""
import json, sys, os, math

ART = os.path.expanduser("~/ai_bot/artifacts")
SRC = os.path.join(ART, "predictions.json")

def die(msg, code=2):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)

def load_signals(path):
    if not os.path.exists(path):
        die(f"missing file: {path}", 3)
    try:
        with open(path, "r", encoding="utf-8") as f:
            j = json.load(f)
    except Exception as e:
        die(f"invalid JSON: {e}", 4)
    if "signals" not in j or not isinstance(j["signals"], list):
        die("schema error: 'signals' list missing", 5)
    # light validation
    out = []
    for s in j["signals"]:
        if not isinstance(s, dict):
            continue
        sym = s.get("symbol")
        act = s.get("action")
        conf = s.get("confidence")
        if not (isinstance(sym, str) and isinstance(act, str) and isinstance(conf, (int, float))):
            continue
        out.append({"symbol": sym, "action": act.lower(), "confidence": float(conf)})
    if not out:
        die("no valid signals found", 6)
    return j.get("version","?"), j.get("timestamp","?"), out

def fmt_row(cols, widths):
    return " | ".join(str(c).ljust(w) for c, w in zip(cols, widths))

def main():
    ver, ts, sigs = load_signals(SRC)
    # sort by confidence desc
    sigs.sort(key=lambda s: s["confidence"], reverse=True)

    headers = ["symbol", "action", "confidence"]
    rows = [[s["symbol"], s["action"], f"{s['confidence']:.2f}"] for s in sigs]
    widths = [max(len(h), *(len(r[i]) for r in rows)) for i, h in enumerate(headers)]

    print(f"predictions: version={ver}  timestamp={ts}")
    print(fmt_row(headers, widths))
    print("-+-".join("-"*w for w in widths))
    for r in rows:
        print(fmt_row(r, widths))

if __name__ == "__main__":
    main()
