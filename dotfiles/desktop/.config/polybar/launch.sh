#!/usr/bin/env bash
# Restart polybar on each connected monitor.

polybar-msg cmd quit >/dev/null 2>&1 || true

while pgrep -u "$UID" -x polybar >/dev/null; do
  sleep 0.1
done

if command -v xrandr >/dev/null 2>&1; then
  monitors=$(xrandr --query | awk '/ connected/ {print $1}')
fi

if [ -n "${monitors:-}" ]; then
  for m in $monitors; do
    MONITOR="$m" polybar main >/dev/null 2>&1 &
  done
else
  polybar main >/dev/null 2>&1 &
fi
