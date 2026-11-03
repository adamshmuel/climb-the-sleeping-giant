#!/usr/bin/env python3
"""Health check: is the team working, and on what?

Reads this project's Claude Code session records (the main chat and every
agent) for the last N hours and prints a short report plus alarms.
Usage: python3 scripts/health.py [hours]   (default 24)
"""

import datetime as dt
import glob
import json
import os
import subprocess
import sys

IDLE_ALARM_MIN = 30
BUILDER_LIMIT = 150_000
OTHER_LIMIT = 200_000
ACTIVE_GAP_S = 600  # two events this close count as continuous work
FILE_LIMIT = 1000
FILE_WARN = 900
SIZE_DIRS = ("src", "tools", "scripts", "docs", ".claude")
TEXT_ENDINGS = (".luau", ".lua", ".md", ".py", ".sh", ".json", ".txt")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RECORDS = os.path.expanduser("~/.claude/projects/" + ROOT.replace("/", "-"))


def when(stamp):
    return dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))


def events(path):
    with open(path) as records:
        for line in records:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            if entry.get("type") in ("user", "assistant") and entry.get("timestamp"):
                yield when(entry["timestamp"]), entry


def merge(spans):
    out = []
    for start, end in sorted(spans):
        if out and start <= out[-1][1]:
            out[-1] = (out[-1][0], max(out[-1][1], end))
        else:
            out.append((start, end))
    return out


def hours(spans):
    return sum((end - start).total_seconds() for start, end in spans) / 3600


def main():
    window = float(sys.argv[1]) if len(sys.argv) > 1 else 24
    until = dt.datetime.now(dt.timezone.utc)
    since = until - dt.timedelta(hours=window)
    cutoff = since.timestamp()

    spans, agent_spans, mains = [], [], []
    by_type, peaks, over = {}, {}, []
    for session in glob.glob(os.path.join(RECORDS, "*.jsonl")):
        if os.path.getmtime(session) < cutoff:
            continue
        files = [(session, "main chat")]
        for record in glob.glob(os.path.join(session[:-6], "subagents", "*.jsonl")):
            if os.path.getmtime(record) < cutoff:
                continue
            try:
                with open(record[:-6] + ".meta.json") as meta:
                    kind = json.load(meta).get("agentType", "agent")
            except (OSError, json.JSONDecodeError):
                kind = "unknown agent"
            files.append((record, kind))
        for path, kind in files:
            last, peak = None, 0
            for moment, entry in events(path):
                if not since <= moment <= until:
                    continue
                if kind == "main chat":
                    mains.append((moment, entry))
                if last and (moment - last).total_seconds() <= ACTIVE_GAP_S:
                    spans.append((last, moment))
                    if kind != "main chat":
                        agent_spans.append((last, moment))
                        by_type[kind] = by_type.get(kind, 0) + (moment - last).total_seconds() / 3600
                last = moment
                usage = (entry.get("message") or {}).get("usage") or {}
                size = sum(usage.get(k, 0) for k in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
                peak = max(peak, size)
            if kind != "main chat" and peak:
                peaks[kind] = max(peaks.get(kind, 0), peak)
                limit = OTHER_LIMIT if kind not in ("builder", "unknown agent", "agent") else BUILDER_LIMIT  # unknown: strictest
                if peak > limit:
                    over.append(f"{kind} {peak // 1000}k")

    working = merge(spans)
    idle, cursor = [], since
    for start, end in working:
        if (start - cursor).total_seconds() >= IDLE_ALARM_MIN * 60:
            idle.append((cursor, start))
        cursor = max(cursor, end)
    if (until - cursor).total_seconds() >= IDLE_ALARM_MIN * 60:
        idle.append((cursor, until))

    crashes = 0
    for output in glob.glob(f"/private/tmp/claude-{os.getuid()}/{glob.escape(ROOT.replace('/', '-'))}/*/tasks/*.output"):
        if os.path.getmtime(output) >= cutoff:
            with open(output, errors="replace") as text:
                log_text = text.read()
            if log_text.startswith("Rojo server listening"):  # a real rojo serve log, not an agent quoting one
                crashes += "[ERROR rojo]" in log_text  # a crash ends that rojo serve, so one per log

    log = subprocess.run(
        ["git", "-C", ROOT, "log", f"--since={since.isoformat()}", "--no-merges", "--format=%s"],
        capture_output=True, text=True,
    ).stdout.splitlines()

    tracked = subprocess.run(
        ["git", "-C", ROOT, "ls-files", *SIZE_DIRS], capture_output=True, text=True
    ).stdout.splitlines()
    big = []
    for name in tracked:
        if name.endswith(TEXT_ENDINGS) and os.path.isfile(os.path.join(ROOT, name)):
            with open(os.path.join(ROOT, name), errors="replace") as text:
                lines = sum(1 for _ in text)
            if lines > FILE_WARN:
                big.append((lines, name))

    print(f"Health check, last {window:g} h (to {until:%Y-%m-%d %H:%M} UTC)")
    print(f"- Something working: {hours(working):.1f} h. Nothing working: {window - hours(working):.1f} h.")
    print("- Agents working: " + (", ".join(f"{k} {v:.1f} h (peak {peaks.get(k, 0) // 1000}k)" for k, v in sorted(by_type.items(), key=lambda kv: -kv[1])) or "none"))
    print(f"- Commits: {len(log)}" + (" (" + "; ".join(log[:8]) + (" ..." if len(log) > 8 else "") + ")" if log else ""))
    print(f"- Rojo crashes seen: {crashes}")

    alarms = []
    for start, end in idle:
        gap = (end - start).total_seconds() / 60
        after = next((e for t, e in mains if t >= end), None)
        reason = ""
        if after:
            content = (after.get("message") or {}).get("content")
            text = content if isinstance(content, str) else " ".join(
                part.get("text", "") for part in content or [] if isinstance(part, dict))
            reason = " (ended by the user)" if "agent-message" not in text and "task-notification" not in text else " (ended by an agent)"
        alarms.append(f"Nothing running for {gap:.0f} min from {start:%m-%d %H:%M} UTC{reason}")
    if over:
        alarms.append(f"Over memory limit: {len(over)} agent(s), biggest " + ", ".join(sorted(over, key=lambda o: -int(o.split()[-1][:-1]))[:3]))
    for lines, name in sorted(big, reverse=True):
        verdict = "over the limit: split it now" if lines > FILE_LIMIT else "near the limit: split it before adding more"
        alarms.append(f"{name} has {lines} lines, {verdict}")
    if crashes:
        alarms.append(f"Rojo crashed {crashes} time(s): log it in docs/problems-log/")
    docs = subprocess.run(
        [sys.executable, os.path.join(ROOT, ".claude", "hooks", "docs-check.py"), "--all"], capture_output=True, text=True
    ).stdout.splitlines()
    alarms.extend(f"Docs check: {line}" for line in docs)
    print("ALARMS:" if alarms else "ALARMS: none")
    for alarm in alarms:
        print(f"- {alarm}")
    print("Also check by hand: tasks that closed with nothing built, tasks over their size, a 2nd task on one object.")


if __name__ == "__main__":
    main()
