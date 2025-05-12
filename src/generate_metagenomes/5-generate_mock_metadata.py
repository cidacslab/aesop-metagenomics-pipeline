#!/usr/bin/env python
"""
generate_cst_metagenomes.py
---------------------------
Builds 40 synthetic throat-metagenome composition tables (CSV) with three
airway community-state types (CSTs) and multiple pathogen scenarios.

• Requires: pandas, numpy  (Python ≥ 3.8)
• Input CSVs: core_bacteria.csv, tail_bacteria.csv, core_viruses.csv
  ─ each with columns  Organism,TaxID  (see README)
• Output: sim_compositions_csv/*.csv
"""

from __future__ import annotations
import pandas as pd
import numpy as np
import hashlib, pathlib, argparse


PATHOGENS_ACC = {
  "NC_045512.2": 2697049,
  "MP467583.1": 114727, # H1N1
  "MW587061.1": 147711
}

# ----------------------------------------------------------------------
# 2.  load_reference_lists
# ----------------------------------------------------------------------
def load_reference_lists(dir_path: pathlib.Path):
  """Return three dicts: core_taxa, tail_taxa, virus_taxa"""
  return (dict(),
          dict(zip(tail_df.Accession,  tail_df.TaxID)),
          dict(zip(virus_df.Accession, virus_df.TaxID)))



# ----------------------------------------------------------------------
# 4.  main routine
# ----------------------------------------------------------------------
def generate_metadata(
  list_dir: pathlib.Path,
  out_dir: pathlib.Path
):
  out_dir.mkdir(exist_ok=True)
  
  core_df  = pd.read_csv(list_dir / "core_bacteria_fixed_completed.csv")
  tail_df  = pd.read_csv(list_dir / "tail_bacteria_fixed_completed.csv")
  virus_df = pd.read_csv(list_dir / "core_viruses_fixed_completed.csv")
  
  rows = []
  rows.update([("AP023461.1", 9606)])
  rows.update([(acc, taxid) for acc, taxid in PATHOGENS_ACC.items()])
  rows.update([(acc, taxid) for acc, taxid in zip(core_df.Accession, core_df.TaxID)])
  rows.update([(acc, taxid) for acc, taxid in zip(tail_df.Accession, tail_df.TaxID)])
  rows.update([(acc, taxid) for acc, taxid in zip(virus_df.Accession, virus_df.TaxID)])
  
  df = pd.DataFrame(rows, columns=["Accession","TaxID"])
  df.to_csv(out_dir / f"metadata_accession_taxid.tsv", sep="\t",
            index=False, header=False)



# ----------------------------------------------------------------------
# 5.  entry-point
# ----------------------------------------------------------------------
def main():
  """Entry-point for generating synthetic CST metagenomes.
  
  This script uses random number generators to generate a set of synthetic
  metagenomes with varying human, viral, and bacterial components. The
  resulting compositions are written to TSV files in the specified output
  folder.
  """
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    "--lists",
    default="data/viral_discovery/mock_generation",
    type=pathlib.Path,
    help="Folder containing core_bacteria.csv, tail_bacteria.csv, core_viruses.csv",
  )
  parser.add_argument(
    "--out",
    default="data/viral_discovery",
    type=pathlib.Path,
    help="Output folder for metadata",
  )
  args = parser.parse_args()
  
  generate_all(args.lists, args.out, args.seed)


if __name__ == "__main__":
  main()
