#!/usr/bin/env python3
"""
harvest_times.py  -  Collate execution times from log files (recursive).

Output: execution_times.csv
Columns:
  full_path,database_folder,folder_name,log_filename,
  script,elapsed_min,date,time   (time includes timezone, e.g. 22:15:06+0000)

Usage:
  python harvest_times.py [LOG_ROOT]
  LOG_ROOT defaults to the current working directory.
"""
import csv, re, sys
from pathlib import Path

# ─── Command-line argument ─────────────────────────────────────────────────────
root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
out_path = Path("execution_times.csv")

# ─── Regular expressions ───────────────────────────────────────────────────────
# 1. Finished … (script optional) with optional elapsed time after "in:" or
#    "Total elapsed time:"
finished_rx = re.compile(
  r"""Finished\s+
    (?P<script>.*?)                                  # script/path text
    (?= \s+(?:in:|Total\s+elapsed\s+time:) | \s*$)   # stop capture
    (?: \s+(?:in:|Total\s+elapsed\s+time:)\s+
      (?P<elapsed>[0-9.]+)\s+min )?                # optional minutes
  """,
  re.IGNORECASE | re.VERBOSE,
)

# 2. Stand-alone "Total elapsed time:" (no preceding "Finished")
elapsed_only_rx = re.compile(
  r"Total\s+elapsed\s+time:\s+(?P<elapsed>[0-9.]+)\s+min",
  re.IGNORECASE,
)

# 3. Timestamp in square brackets; capture date and time incl. timezone
ts_rx = re.compile(
  r"\[(?P<date>\d{4}-\d{2}-\d{2})T"
  r"(?P<clock>\d{2}:\d{2}:\d{2})(?P<tz>[+-]\d{2}:?\d{2}|[+-]\d{4})?\]"
)

# ─── Gather rows ───────────────────────────────────────────────────────────────
rows = []

for log_file in root.rglob("*.log"):                           # recursive walk
  folder_name = log_file.parent.name                         # immediate folder
  database_folder = (
    log_file.parent.parent.name
    if log_file.parent.parent != log_file.parent.anchor
    else ""
  )
    
  found_match = False
  with log_file.open(encoding="utf-8", errors="replace") as fh:
    for line in fh:
      lower = line.lower()
      if "exit" in lower:                # skip "exit" lines
        continue
      
      # -------- try “Finished …” pattern --------------------------------
      m = finished_rx.search(line)
      if m:
        elapsed = m.group("elapsed") or ""
        script = m.group("script").strip()
      else:
        # -------- try stand-alone elapsed-time pattern ----------------
        if "total elapsed time" not in lower:
          continue
        m2 = elapsed_only_rx.search(line)
        if not m2:
          continue
        elapsed = m2.group("elapsed")
        script = ""                    # no script for these lines
      
      # -------- timestamp extraction ------------------------------------
      tm = ts_rx.search(line)
      if tm:
        date_val = tm.group("date")
        time_val = tm.group("clock") + (tm.group("tz") or "")
      else:
        date_val = ""
        time_val = ""
      
      rows.append(
        dict(
          full_path=str(log_file.resolve()),
          database_folder=database_folder,
          folder_name=folder_name,
          log_filename=log_file.name,
          script=script,
          elapsed_min=elapsed,
          date=date_val,
          time=time_val,
        )
      )
      found_match = True
    
    # If no qualifying lines, emit a placeholder row for the file
  if not found_match:
    rows.append(
      dict(
        full_path=str(log_file.resolve()),
        database_folder=database_folder,
        folder_name=folder_name,
        log_filename=log_file.name,
        script="",
        elapsed_min="",
        date="",
        time="",
      )
    )

# ─── Write CSV ────────────────────────────────────────────────────────────────
fieldnames = [
  "full_path",
  "database_folder",
  "folder_name",
  "log_filename",
  "script",
  "elapsed_min",
  "date",
  "time",
]

with out_path.open("w", newline="", encoding="utf-8") as csvfile:
  writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
  writer.writeheader()
  writer.writerows(rows)

print(f"✓ Wrote {len(rows)} lines to {out_path}")
