# fill_taxid_and_accession.ipynb  (2-space indent)
import pandas as pd, time, pathlib, os, sys
from Bio import Entrez
from tqdm.auto import tqdm

# ---------- CONFIG ----------
CSV_IN  = "data/viral_discovery/mock_generation/tail_bacteria_fixed.csv"
DELAY   = 1                    # seconds between API calls (≤3 req/s)
Entrez.email = 'pablo.alessandro@gmail.com'
Entrez.api_key = '86cf88e5ee6087442f57c78ed90336b99408'
# ----------------------------------

def assembly_for_taxid(taxid: str) -> str|None:
  """Return best RefSeq assembly accession for a TaxID."""
  filters = [
    'refseq[filter] AND complete genome[Title]',
    'refseq[filter] AND complete[Title]',
    'complete genome[Title]'
  ]
  for filt in filters:
    h = Entrez.esearch(db="nucleotide",
                       term=f"txid{taxid}[Organism:{taxid}] AND {filt}",
                       idtype="acc",
                       retmax=1)
    records = Entrez.read(h)
    h.close()
    if records["IdList"]:
      return records["IdList"][0]
  return None

# ---------------- main --------------
df = pd.read_csv(CSV_IN, dtype=str)
assert "TaxID" in df.columns, "CSV needs at least an TaxID column"

completed = []
unresolved = []
for taxid in tqdm(df.TaxID, desc="querying"):
  org = df.loc[df.TaxID.eq(taxid), "Organism"].squeeze()
  try:
    acc = assembly_for_taxid(org)
    if not taxid:
      unresolved.append((org, "no TaxID")); continue
    acc = assembly_for_taxid(taxid)
    if not acc:
      unresolved.append((org, "no assembly")); acc = ""
    completed.append((acc, org, taxid))
    time.sleep(DELAY)
  except Exception as e:
    unresolved.append((org, f"error {e}"))

out = pathlib.Path(CSV_IN).with_stem(pathlib.Path(CSV_IN).stem + "_completed")
pd.DataFrame(completed, columns=["Accession","Organism","TaxID"])\
  .to_csv(out, index=False)
print(f"✅ wrote {out}  ({len(completed)} rows)")

if unresolved:
  print("\n### Unresolved")
  for org, why in unresolved:
    print(f"  {org}: {why}")
