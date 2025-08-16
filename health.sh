#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ART="$HOME/ai_bot/artifacts"
SRC="$ART/predictions.json"
CACHE="$ART/last_good.json"
echo "PREDICTIONS_URL=${PREDICTIONS_URL:-<unset>}"
ls -l "$SRC" 2>/dev/null || echo "no predictions.json yet"
[ -s "$CACHE" ] && echo "cache present: $(ls -l "$CACHE" | awk '{print $5" bytes, "$6" "$7" "$8}')" || echo "no cache yet"
echo "---- last poll log (tail 5) ----"
tail -n 5 "$ART/poll.log" 2>/dev/null || echo "no poll.log yet"
echo "---- preview ----"
python - <<'PY'
import json, os, pathlib
p=pathlib.Path(os.path.expanduser("~/ai_bot/artifacts/predictions.json"))
if not p.exists(): print("no predictions.json"); raise SystemExit
j=json.load(open(p))
sig=j.get("signals", [])[:5]
print(json.dumps({"version": j.get("version"), "timestamp": j.get("timestamp"), "preview": sig}, indent=2))
PY
