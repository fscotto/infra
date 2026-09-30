#!/usr/bin/env python3
"""Prune only verified, named Prometheus backup versions after publication."""

import datetime as dt
import pathlib
import re
import shutil
import sys


def main() -> None:
    if len(sys.argv) != 5:
        raise SystemExit("Usage: atlas-prometheus-prune SNAPSHOTS DAILY WEEKLY MONTHLY")
    root = pathlib.Path(sys.argv[1])
    counts = [int(value) for value in sys.argv[2:]]
    if not root.is_dir() or root.is_symlink() or min(counts) < 1:
        raise SystemExit("Invalid backup directory or retention counts")
    versions = []
    for entry in root.iterdir():
        if not entry.is_dir() or entry.is_symlink():
            continue
        if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z", entry.name):
            continue
        try:
            when = dt.datetime.strptime(entry.name, "%Y%m%dT%H%M%SZ")
        except ValueError:
            continue
        if not all((entry / name).is_file() for name in ("payload.tar", "payload.sha256", "metadata.json")):
            continue
        versions.append((when, entry))
    versions.sort(reverse=True)
    if not versions:
        raise SystemExit("No published backup versions found; refusing to prune")

    keep = {entry for _, entry in versions[: counts[0]]}
    for count, key in (
        (counts[1], lambda when: when.isocalendar()[:2]),
        (counts[2], lambda when: (when.year, when.month)),
    ):
        periods = set()
        for when, entry in versions:
            period = key(when)
            if period in periods:
                continue
            periods.add(period)
            keep.add(entry)
            if len(periods) >= count:
                break

    for _, entry in versions:
        if entry not in keep:
            shutil.rmtree(entry)


if __name__ == "__main__":
    main()
