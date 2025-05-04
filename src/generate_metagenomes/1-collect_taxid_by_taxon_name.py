#!/usr/bin/env python3
# core_taxid_resolver.py   (offline, 2-space indent)

import pandas as pd, pathlib, csv, sys

# ---------- CONFIG ----------
TAXDUMP_DIR = pathlib.Path("data/taxdump")  # folder that contains names.dmp etc.
FILE        = "tail_bacteria"
INPUT_CSV   = f"data/viral_discovery/mock_generation/{FILE}.csv"
OUT_CSV     = f"data/viral_discovery/mock_generation/{FILE}_fixed.csv"
# ----------------------------

def load_names(taxdir):
  names,taxids_name = {},{}
  with open(taxdir / "names.dmp") as fh:
    for line in fh:
      parts = [p.strip() for p in line.split("|")]
      # print(parts)
      taxid, name_txt, _, class_txt = parts[:4]
      if class_txt in ("scientific name", "synonym", "common name", "genbank common name", "equivalent name"):
        name = name_txt.lower()
        names[name] = taxid
      if class_txt in ("scientific name"):
        taxids_name[taxid] = name_txt
  return names, taxids_name


# -------- main logic --------
def main():
  taxdir = TAXDUMP_DIR
  names_dict, taxids_name = load_names(taxdir)
  print(f"{len(names_dict)}")

  df = pd.read_csv(INPUT_CSV, dtype=str)
  if "TaxID" not in df.columns:
    df["TaxID"] = ""

  unresolved = []
  for idx, row in df.iterrows():
    org = row["Organism"].strip()
    key = org.lower()
    taxid = names_dict.get(key)

    if not taxid:
      unresolved.append(org)
    else:
      df.at[idx, "TaxID"] = taxid
      df.at[idx, "Organism"] = taxids_name[taxid]

  df.to_csv(OUT_CSV, index=False)
  print(f"✅ wrote {OUT_CSV}")

  if unresolved:
    print("\nUnresolved names:")
    for name in unresolved:
      print(" ", name)
  else:
    print("\nAll organisms resolved!")

if __name__ == "__main__":
  main()
