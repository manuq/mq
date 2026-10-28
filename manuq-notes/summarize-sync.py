#!/usr/bin/env python3
"""
Summarize the verbose log of an rclone bisync run, for reading in a terminal.

Path1 is the notes folder on this device and Path2 is the remote. The
listing of changes that bisync prints before applying them has relative
paths, so the summary is built from it.
"""

import argparse
import re
import sys

CHANGE = re.compile(
    r"- (?P<side>Path1|Path2)\s+(?P<what>File is new|File was deleted|File changed:[^-]*?)"
    r"\s+- (?P<path>.+)$"
)
KINDS = {"File is new": "new", "File was deleted": "deleted"}
CONFLICT = re.compile(r"- WARNING\s+New or changed in both paths\s+- (?P<path>.+)$")
# rclone colors some messages even when its output isn't a terminal.
COLOR = re.compile(r"\x1b\[[0-9;]*m")
LEVEL = re.compile(r"^(?:\d{4}/\d\d/\d\d \d\d:\d\d:\d\d )?(?P<level>[A-Z]+)\s*: (?P<message>.*)$")


def plural(count: int, word: str) -> str:
    return f"{count} {word}" + ("" if count == 1 else "s")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log")
    parser.add_argument("--dry-run", action="store_true")
    args, _rclone_flags = parser.parse_known_args()

    changes: dict[str, dict[str, str]] = {}
    conflicts: list[str] = []
    errors: list[str] = []
    successful = False

    for line in open(args.log, encoding="utf-8", errors="replace"):
        match = LEVEL.match(COLOR.sub("", line.rstrip("\n")))
        if not match:
            continue
        level, message = match["level"], match["message"]
        if level == "ERROR":
            errors.append(message)
        if message == "Bisync successful":
            successful = True
        if change := CHANGE.search(message):
            kind = KINDS.get(change["what"], "changed")
            changes.setdefault(change["path"], {})[change["side"]] = kind
        elif conflict := CONFLICT.search(message):
            conflicts.append(conflict["path"])

    sent = received = deleted = 0
    lines = []
    for path in sorted(changes):
        if path in conflicts:
            continue
        for side, kind in sorted(changes[path].items()):
            where = "here" if side == "Path1" else "on the remote"
            if kind == "deleted":
                lines.append(f"  × {path} (deleted {where})")
                deleted += 1
            elif side == "Path1":
                lines.append(f"  ↑ {path} ({kind} {where})")
                sent += 1
            else:
                lines.append(f"  ↓ {path} ({kind} {where})")
                received += 1
    for path in sorted(conflicts):
        lines.append(
            f"  ! {path} (changed on both sides, keeping both: "
            f"{path}.conflict1 is from here, {path}.conflict2 from the remote)"
        )

    if lines:
        if not successful:
            print("Changes found, not applied:")
        elif args.dry_run:
            print("Dry run, these changes would be applied:")
        print("\n".join(lines))

    counts = [
        plural(sent, "file") + " sent" if sent else "",
        plural(received, "file") + " received" if received else "",
        plural(deleted, "file") + " deleted" if deleted else "",
        plural(len(conflicts), "conflict") if conflicts else "",
    ]
    counts = [c for c in counts if c]

    if not successful:
        print("Sync failed:", file=sys.stderr)
        for error in errors:
            print(f"  {error}", file=sys.stderr)
        print(f"Full log: {args.log}", file=sys.stderr)
        return 1

    if not counts:
        print("Nothing to do, all is in sync.")
    else:
        print(("Would sync: " if args.dry_run else "Synced: ") + ", ".join(counts) + ".")
    if errors:
        print(f"rclone recovered from errors on the way. Full log: {args.log}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
