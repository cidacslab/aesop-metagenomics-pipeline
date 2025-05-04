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


# ----------------------------------------------------------------------
# 1.  CST profiles with fixed dominance %
# ----------------------------------------------------------------------
CST_TEMPLATE = {
  "CST1": {  # Corynebacterium / Dolosigranulum
    "Corynebacterium pseudodiphtheriticum": 0.45,
    "Dolosigranulum pigrum":                0.25,
  },
  "CST2": {  # Moraxella dominant
    "Moraxella catarrhalis":     0.50,
    "Haemophilus parainfluenzae":0.15,
    "Streptococcus pneumoniae":  0.10,
  },
  "CST3": {  # Haemophilus / Streptococcus dysbiosis
    "Haemophilus influenzae":    0.35,
    "Streptococcus pneumoniae":  0.25,
    "Neisseria meningitidis":    0.10,
  },
}

BASELINE_SCENARIOS = {
  "CTRL": {},
  "CoV": {"SARS-CoV-2": 2},
  "FLU": {"Influenza A": 3},
  "ENT": {"Rhinovirus A": 2},
  "CoV_FLU": {"SARS-CoV-2": 1.5, "Influenza A": 1.5},
}

# PATHOGENS = {
#   "SARS-CoV-2": 2697049,
#   "Influenza A": 114727, # H1N1
#   "Rhinovirus A": 147711
# }

PATHOGENS_ACC = {
  "SARS-CoV-2": "NC_045512.2",
  "Influenza A": "MP467583.1", 
  "Rhinovirus A": "MW587061.1"
}


# ----------------------------------------------------------------------
# 2.  load_reference_lists
# ----------------------------------------------------------------------
def load_reference_lists(dir_path: pathlib.Path):
  """Return three dicts: core_taxa, tail_taxa, virus_taxa"""
  core_df  = pd.read_csv(dir_path / "core_bacteria_fixed_completed.csv")
  tail_df  = pd.read_csv(dir_path / "tail_bacteria_fixed_completed.csv")
  virus_df = pd.read_csv(dir_path / "core_viruses_fixed_completed.csv")
  return (dict(zip(core_df.Organism,  core_df.Accession)),
          dict(zip(tail_df.Organism,  tail_df.Accession)),
          dict(zip(virus_df.Organism, virus_df.Accession)))


# ----------------------------------------------------------------------
# 3.  helpers
# ----------------------------------------------------------------------
def build_sample(
  core_taxa: dict[str, str],
  cst_dominance: dict[str, float],
  tail_taxa: dict[str, str],
  virus_taxa: dict[str, str],
  human_pct: float,
  pathogens: dict[str, float],
  viral_total: float,
  rng: np.random.Generator | None = None,
) -> pd.DataFrame:
  """
  Build a synthetic sample composition DataFrame.
  
  Parameters:
    core_taxa (dict[str, str]): Mapping of core bacterial species to their accession IDs.
    cst_dominance (dict[str, float]): Dominance percentages of certain core species.
    tail_taxa (dict[str, str]): Mapping of tail bacterial species to their accession IDs.
    virus_taxa (dict[str, str]): Mapping of viral species to their accession IDs.
    human_pct (float): Percentage of the sample that is human.
    pathogens (dict[str, float]): Pathogen species with their respective percentages.
    viral_total (float): Total percentage allocated to viruses.
    rng (np.random.Generator | None): Random number generator instance.
  
  Returns:
    pd.DataFrame: DataFrame containing Organism accession and Percentage columns for the sample.
  """
  rng = rng or np.random.default_rng()
  
  # Calculate remaining percentage for bacteria after accounting for human, viral, and pathogen components
  patho_total = sum(pathogens.values())
  remaining = 100 - human_pct - viral_total - patho_total
  bacteria_total = remaining * 0.9  # Core bacteria is 90% of bacteria
  tail_bacteria_total = remaining - bacteria_total  # Tail is 10% of bacteria
  
  rows: list[tuple[str, int, float]] = [("Homo sapiens", "AP023461.1", human_pct)]
  
  # Add dominant species with fixed percentages
  used = 0
  for sp, frac in cst_dominance.items():
    rows.append((sp, core_taxa[sp], bacteria_total * frac))
    used += frac
  residual = bacteria_total * (1 - used)
  
  # Select additional core species to reach a total of 25
  core_pool = [sp for sp in core_taxa if sp not in cst_dominance]
  extra_sel = rng.choice(core_pool, 25 - len(cst_dominance), replace=False)
  w = rng.dirichlet(np.ones(len(extra_sel)))
  rows += [(sp, core_taxa[sp], residual * w_i) for sp, w_i in zip(extra_sel, w)]
  
  # Select 50 tail species (10% of bacteria)
  tail_sel = rng.choice(list(tail_taxa), 50, replace=False)
  tail_perc = rng.dirichlet(np.ones(50))
  rows += [(sp, tail_taxa[sp], tail_bacteria_total * w_i) for sp, w_i in zip(tail_sel, tail_perc)]
  
  # Select background virome (2-5 genomes)
  n_viruses = rng.integers(2, 6)
  viral_sel = rng.choice(list(virus_taxa), n_viruses, replace=False)
  viral_perc = rng.dirichlet(np.ones(n_viruses))
  rows += [(sp, virus_taxa[sp], viral_total * w_i) for sp, w_i in zip(viral_sel, viral_perc)]
  
  # Add pathogen spikes
  rows += [(sp, PATHOGENS_ACC[sp], pct) for sp, pct in pathogens.items()]
  
  # Renormalize to account for float drift
  tot = sum(r[2] for r in rows)
  rows = [(acc, p / tot) for o, acc, p in rows]
  
  return pd.DataFrame(rows)


# ----------------------------------------------------------------------
# 4.  main routine
# ----------------------------------------------------------------------
def generate_all(
  list_dir: pathlib.Path,
  out_dir: pathlib.Path = pathlib.Path("sim_compositions"),
  seed: int = 20250428,
):
  out_dir.mkdir(exist_ok=True)
  rng = np.random.default_rng(seed)
  
  # load reference dictionaries
  core_taxa, tail_taxa, virus_taxa = load_reference_lists(list_dir)
  
  # --- 1 baseline scenarios with 2 reps × 3 CSTs
  for cst_key, cst_dominance in CST_TEMPLATE.items():
    for scen, pdict in BASELINE_SCENARIOS.items():
      for rep in (1, 2):
        df = build_sample(
          core_taxa,
          cst_dominance,
          tail_taxa,
          virus_taxa,
          human_pct=rng.uniform(75, 85),
          pathogens=pdict,
          viral_total=1,
          rng=rng,
        )
        df.to_csv(out_dir / f"{cst_key}_{scen}_{rep}.tsv", sep="\t",
                  index=False, header=False, float_format="%.18f")
  
  # # --- 2 SARS-CoV-2 mutants (CST1)
  # for i in range(1, 6):
  #     df = build_sample(
  #         core_pools["CST1"],
  #         CST_TEMPLATE["CST1"],
  #         tail_taxa,
  #         virus_taxa,
  #         human_pct=80,
  #         pathogens={f"SARS2_mutant_{i}": 2.0},
  #         rng=rng,
  #     )
  #     df.to_csv(out_dir / f"novelCoV_{i}.csv", index=False)
  
  # # --- 3 Low-abundance RSV (CST2)
  # for i in range(1, 6):
  #     df = build_sample(
  #         core_pools["CST2"],
  #         CST_TEMPLATE["CST2"],
  #         tail_taxa,
  #         virus_taxa,
  #         human_pct=82,
  #         pathogens={"Respiratory syncytial virus": 0.05},
  #         rng=rng,
  #     )
  #     df.to_csv(out_dir / f"RSV_low_{i}.csv", index=False)
  
  print(f"✓  30 composition CSVs written to {out_dir.resolve()}")


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
    default="data/viral_discovery/compositions",
    type=pathlib.Path,
    help="Output folder for composition CSVs",
  )
  parser.add_argument("--seed", default=20250428, type=int, help="Random seed")
  args = parser.parse_args()
  
  generate_all(args.lists, args.out, args.seed)


if __name__ == "__main__":
  main()
