#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

CMD=${1:-start}
PIDFILE=".bot.pid"

start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Already running (PID $(cat "$PIDFILE"))."
    exit 0
  fi
  echo "Starting bot…"
  nohup python3 -u main.py >> bot.out 2>&1 &
  echo $! > "$PIDFILE"
  echo "✅ PID $(cat "$PIDFILE")"
}

stop() {
  if [ -f "$PIDFILE" ]; then
    kill -TERM "$(cat "$PIDFILE")" 2>/dev/null || true
    rm -f "$PIDFILE"
    echo "Stopped."
  else
    echo "Not running."
  fi
}

status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Running (PID $(cat "$PIDFILE"))."
  else
    echo "Not running."
  fi
}

case "$CMD" in
  start) start ;;
  stop) stop  ;;
  restart) stop; start ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
