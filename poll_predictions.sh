#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

URL="${PREDICTIONS_URL:-}"
ART="$HOME/ai_bot/artifacts"
TMP="$ART/tmp"
OUT="$ART/predictions.json"
CACHE="$ART/last_good.json"
LOG="$ART/poll.log"
mkdir -p "$ART" "$TMP"

pp(){ printf '>> %s\n' "$*"; }
hr(){ printf '%s\n' '----------------------------------------'; }

# If no URL set, work offline (cache/seed only)
if [ -z "${URL}" ]; then
  pp "No PREDICTIONS_URL set; using seed/cache only."
  if [ -s "$CACHE" ]; then
    cp -f "$CACHE" "$OUT"; pp "Copied last_good.json to predictions.json"
  else
    pp "Seed already present at $OUT"
  fi
  hr; exit 0
fi

HOST="$(printf '%s' "$URL" | sed -E 's~^https?://([^/]+).*~\1~')"
PATH_ONLY="$(printf '%s' "$URL" | sed -E 's~^https?://[^/]+~~')"
[ -n "${PATH_ONLY:-}" ] || PATH_ONLY="/"

HDR="$TMP/h.txt"; BODY="$TMP/b.bin"
: >"$HDR"; : >"$BODY"
status="FAIL"

pp "Fetching $URL"

# 0) DoH (Cloudflare) — try before normal DNS
if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-DoH" \
     --doh-url https://cloudflare-dns.com/dns-query \
     -D "$HDR" "$URL" -o "$BODY"; then
  status="OK"
fi

# A) Normal fetch (system DNS)
if [ "$status" != "OK" ]; then
  if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-A" \
       -D "$HDR" "$URL" -o "$BODY"; then
    status="OK"
  fi
fi

# B) --resolve with known Cloudflare IPs (default TLS)
if [ "$status" != "OK" ]; then
  for IP in 104.21.40.47 172.67.195.38; do
    if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-B" \
         --resolve "${HOST}:443:${IP}" -D "$HDR" "$URL" -o "$BODY"; then
      status="OK"; break
    fi
  done
fi

# C) direct IP + Host header (default TLS)
if [ "$status" != "OK" ]; then
  for IP in 104.21.40.47 172.67.195.38; do
    if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-C" \
         -H "Host: ${HOST}" -D "$HDR" "https://${IP}${PATH_ONLY}" -o "$BODY"; then
      status="OK"; break
    fi
  done
fi

# D) try TLS 1.2 (older stacks) with lower seclevel ciphers
if [ "$status" != "OK" ]; then
  for IP in 104.21.40.47 172.67.195.38; do
    if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-D" \
         --resolve "${HOST}:443:${IP}" --tlsv1.2 --ciphers DEFAULT@SECLEVEL=1 \
         -D "$HDR" "$URL" -o "$BODY"; then
      status="OK"; break
    fi
  done
fi

# D2) direct IP + Host with TLS 1.2
if [ "$status" != "OK" ]; then
  for IP in 104.21.40.47 172.67.195.38; do
    if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-D2" \
         -H "Host: ${HOST}" --tlsv1.2 --ciphers DEFAULT@SECLEVEL=1 \
         -D "$HDR" "https://${IP}${PATH_ONLY}" -o "$BODY"; then
      status="OK"; break
    fi
  done
fi

# E) last resort (insecure) — only if absolutely necessary
if [ "$status" != "OK" ]; then
  if curl -fsSL --retry 2 --retry-delay 1 -m 20 -A "curl/poller-E" \
       -k -D "$HDR" "$URL" -o "$BODY"; then
    status="OK"
  fi
fi

validate_and_commit() {
  python - "$BODY" "$OUT" "$CACHE" "$LOG" <<'PY'
import sys, json, pathlib, shutil, datetime
body, outp, cachep, logp = map(pathlib.Path, sys.argv[1:5])
# timezone-aware UTC (no DeprecationWarning)
ts = datetime.datetime.now(datetime.timezone.utc).isoformat()
def ok(d):
    return isinstance(d.get("signals"), list) and all(
      isinstance(s, dict) and "symbol" in s and "action" in s and "confidence" in s
      for s in d["signals"])
try:
    txt = body.read_text(encoding="utf-8")
    data = json.loads(txt)
    if not ok(data):
        raise ValueError("schema check failed: signals list invalid")
    if outp.exists():
        shutil.copy2(outp, outp.with_suffix(".json.bak"))
    outp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    cachep.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print("STATUS: OK_JSON")
    with logp.open("a", encoding="utf-8") as lf:
        lf.write(f"{ts} OK {outp}\n")
except Exception as e:
    print("STATUS: NOT_JSON")
    print("DETAIL:", repr(e))
    with logp.open("a", encoding="utf-8") as lf:
        lf.write(f"{ts} FAIL {repr(e)}\n")
    sys.exit(9)
PY
}

if [ "$status" = "OK" ]; then
  code="$(awk 'BEGIN{c=0}/HTTP\//{c=$2} END{print c}' "$HDR" || echo 0)"
  ctype="$(grep -i '^Content-Type:' "$HDR" | awk '{print $2}' | tr -d $'\r' || true)"
  pp "HTTP ${code:-?} | Content-Type: ${ctype:-unknown} | Bytes: $(wc -c < "$BODY")"
  if validate_and_commit; then
    hr; exit 0
  else
    pp "Validation failed; falling back."
  fi
else
  pp "All fetch attempts failed."
fi

# Fallback: cache → seed (we keep a seed file in place already)
if [ -s "$CACHE" ]; then
  pp "Using cached last_good.json"; cp -f "$CACHE" "$OUT"
else
  pp "No cache found; seed remains at $OUT"
fi
hr
