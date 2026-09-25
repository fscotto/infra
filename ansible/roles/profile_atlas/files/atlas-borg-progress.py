#!/usr/bin/env python3
"""Turn Borg's JSON progress stream into bounded, readable journal entries."""

import argparse
import json
import sys
import time


def size(value):
    if not isinstance(value, (int, float)):
        return "unknown"
    return f"{value / (1024 ** 3):.2f} GiB"


parser = argparse.ArgumentParser()
parser.add_argument("--estimated-total-bytes", type=int, required=True)
args = parser.parse_args()
if args.estimated_total_bytes <= 0:
    parser.error("estimated total must be positive")

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
        original_size = event.get("original_size")
        if isinstance(original_size, (int, float)) and original_size >= 0:
            percent = original_size / args.estimated_total_bytes * 100
            estimated_progress = (
                f"{percent:.1f}%" if percent < 100 else ">=100% (ZFS estimate exceeded)"
            )
        else:
            estimated_progress = "unknown"
        print(
            "Borg create progress: "
            f"estimated={estimated_progress} dataset={dataset} "
            f"files={event.get('nfiles', 'unknown')} "
            f"original={size(original_size)} "
            f"compressed={size(event.get('compressed_size'))} "
            f"deduplicated={size(event.get('deduplicated_size'))}",
            flush=True,
        )
        last_progress = now
    elif kind == "log_message":
        print(f"Borg {event.get('levelname', 'INFO')}: {event.get('message', '')}", flush=True)
    elif kind == "progress_message" and event.get("message"):
        print(f"Borg: {event['message']}", flush=True)
