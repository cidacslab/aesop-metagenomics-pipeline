#!/usr/bin/env python3
"""
aggregate_execution_times.py
Reads execution_times.csv and produces execution_times_aggregated.csv
--------------------------------------------------------------------
• Keeps only rows with a value in elapsed_min
• For rows whose script is 'script!' (case-sensitive) and that share the
  same database_folder & folder_name, calculates:
      min_elapsed, max_elapsed, mean_elapsed, n_rows
• Rows that don't match the above condition (but still have elapsed_min)
  are retained unchanged.
"""

import pandas as pd

src = "execution_times.csv"
dst = "execution_times_aggregated.csv"

# ─── Load and filter ───────────────────────────────────────────────────────────
df = pd.read_csv(src)

# Keep rows that have a numeric elapsed_min
df = df[df["elapsed_min"].notna() & (df["elapsed_min"] != "")]
df["elapsed_min"] = df["elapsed_min"].astype(float)

# ─── Identify the “script!” rows ───────────────────────────────────────────────
mask_script = df["script"] == "script!"

# ─── Aggregate the “script!” rows ──────────────────────────────────────────────
agg_df = (
    df[mask_script]
    .groupby(["database_folder", "folder_name"], as_index=False)
    .agg(
        min_elapsed=("elapsed_min", "min"),
        max_elapsed=("elapsed_min", "max"),
        mean_elapsed=("elapsed_min", "mean"),
        n_rows=("elapsed_min", "size"),
    )
)

# Give the same column layout as the original for easier concatenation
# (script column will carry the literal 'script!' so you know the group)
agg_df["script"] = "script!"
agg_df["elapsed_min"] = agg_df["mean_elapsed"]      # optional: keep mean here
# You may keep min/max/mean/n_rows only or drop other columns as you like.

# ─── Keep the non-“script!” rows as they are ───────────────────────────────────
others_df = df[~mask_script].copy()

# ---------- make sure BOTH data sets have the same analytic columns ----------
for col in ["mean_elapsed", "min_elapsed", "max_elapsed", "n_rows"]:
    if col not in agg_df.columns:
        agg_df[col] = pd.NA
    if col not in others_df.columns:
        others_df[col] = pd.NA

# Keep original elapsed for “others” rows as mean_elapsed; min/max identical
others_df["mean_elapsed"] = others_df["elapsed_min"]
others_df["min_elapsed"]  = others_df["elapsed_min"]
others_df["max_elapsed"]  = others_df["elapsed_min"]
others_df["n_rows"]       = 1

# Remove the legacy elapsed_min column (now redundant)
agg_df  = agg_df.drop(columns="elapsed_min", errors="ignore")
others_df = others_df.drop(columns="elapsed_min", errors="ignore")

# ---------- concatenate aggregated & untouched rows --------------------------
final_df = pd.concat([agg_df, others_df], ignore_index=True)

# ---------- ensure the requested column order --------------------------------
ordered_cols = [
    "full_path",
    "log_filename",
    "database_folder",
    "folder_name",
    "script",
    "mean_elapsed",
    "min_elapsed",
    "max_elapsed",
    "n_rows",
    "date",
    "time",
]

# Add any missing columns (they’ll be all NA for some rows, e.g. full_path inside agg)
for col in ordered_cols:
    if col not in final_df.columns:
        final_df[col] = pd.NA

final_df = final_df[ordered_cols]

# ---------- write to disk -----------------------------------------------------
dst = "execution_times_aggregated.csv"
final_df.to_csv(dst, index=False)
print(f"✓ Aggregated file written to {dst} with columns in requested order.")
