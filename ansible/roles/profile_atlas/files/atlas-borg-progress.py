#!/usr/bin/env python3
"""Turn Borg's JSON progress stream into bounded, readable journal entries."""

import json
import sys
import time


def size(value):
    if not isinstance(value, (int, float)):
        return "unknown"
    return f"{value / (1024 ** 3):.2f} GiB"


last_progress = 0.0
for line in sys.stdin:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        print(line.rstrip(), flush=True)
        continue

    kind = event.get("type")
    if kind == "archive_progress":
        now = time.monotonic()
        if now - last_progress < 60 and not event.get("finished"):
            continue
        path = event.get("path") or ""
        parts = path.split("/")
        dataset = parts[1] if len(parts) > 1 and parts[0] == "source" else "unknown"
        print(
            "Borg create progress: "
            f"dataset={dataset} files={event.get('nfiles', 'unknown')} "
            f"original={size(event.get('original_size'))} "
            f"compressed={size(event.get('compressed_size'))} "
            f"deduplicated={size(event.get('deduplicated_size'))}",
            flush=True,
        )
        last_progress = now
    elif kind == "log_message":
        print(f"Borg {event.get('levelname', 'INFO')}: {event.get('message', '')}", flush=True)
    elif kind == "progress_message" and event.get("message"):
        print(f"Borg: {event['message']}", flush=True)
