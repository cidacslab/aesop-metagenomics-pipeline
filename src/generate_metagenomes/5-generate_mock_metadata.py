#!/usr/bin/env python
"""
generate_mock_metatadata.py
---------------------------
Creates file containing all species present in mock metagenomes.

• Requires: pandas  (Python ≥ 3.8)
• Input CSVs: core_bacteria.csv, tail_bacteria.csv, core_viruses.csv
  ─ each with columns  Accession,Organism,TaxID
• Output: data/viral_discovery/metadata_accession.tsv
"""
import pathlib, argparse
import pandas as pd


# ----------------------------------------------------------------------
# 4.  main routine
# ----------------------------------------------------------------------
def generate_metadata(
  list_dir: pathlib.Path,
  out_dir: pathlib.Path
):
  # ------------------------------------------------------------------
  # read the three composition files
  # ------------------------------------------------------------------
  core_df  = pd.read_csv(list_dir / "core_bacteria_fixed_completed.csv")
  tail_df  = pd.read_csv(list_dir / "tail_bacteria_fixed_completed.csv")
  virus_df = pd.read_csv(list_dir / "core_viruses_fixed_completed.csv")
  # ------------------------------------------------------------------
  # rows — a list of *3-field tuples*
  # ------------------------------------------------------------------
  rows = [
      ("AP023461.1", 9606,   "Homo sapiens"),
      ("NC_045512.2", 2697049, "SARS-CoV-2"),
      ("MP467583.1", 114727,  "Influenza A (H1N1)"),
      ("MW587061.1", 147711,  "Rhinovirus A"),
  ]
  # ------------------------------------------------------------------
  # add the accessions from each DataFrame
  # ------------------------------------------------------------------
  rows.extend(zip(core_df.Accession,  core_df.TaxID,  core_df.Organism))
  rows.extend(zip(tail_df.Accession,  tail_df.TaxID,  tail_df.Organism))
  rows.extend(zip(virus_df.Accession, virus_df.TaxID, virus_df.Organism))
  
  # ------------------------------------------------------------------
  # write out
  # ------------------------------------------------------------------
  out_dir.mkdir(exist_ok=True, parents=True)
  df = pd.DataFrame(rows, columns=["Accession", "TaxID", "Organism"])
  df.to_csv(out_dir / "metadata_accession.tsv", sep="\t", index=False, header=False)  
  print(f"✅ wrote {out_dir / 'metadata_accession.tsv'}")


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
  
  generate_metadata(args.lists, args.out)


if __name__ == "__main__":
  main()
