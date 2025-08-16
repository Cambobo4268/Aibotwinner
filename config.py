import os

def load_env(path=".env"):
    vals = {}
    if not os.path.exists(path):
        return vals
    with open(path, "r") as f:
        for line in f:
            line=line.strip()
            if not line or line.startswith("#") or "=" not in line: 
                continue
            k,v = line.split("=",1)
            vals[k.strip()] = v.strip()
    return vals

ENV = load_env()
KRAKEN_API_KEY    = ENV.get("KRAKEN_API_KEY","")
KRAKEN_API_SECRET = ENV.get("KRAKEN_API_SECRET","")
TELEGRAM_BOT_TOKEN= ENV.get("TELEGRAM_BOT_TOKEN","")
TELEGRAM_CHAT_ID  = ENV.get("TELEGRAM_CHAT_ID","")
DRIVE_FILE_ID     = ENV.get("DRIVE_FILE_ID","")
