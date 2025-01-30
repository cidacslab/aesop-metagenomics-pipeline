#!/bin/bash

export NCBI_API_KEY="86cf88e5ee6087442f57c78ed90336b99408"

# file=$1
file="SI041_1"
input_file="./data/dataset_mock/composition/${file}.tsv"
taxids_map_file="./data/dataset_mock/metadata/${file}_taxids_map.tsv"

# Initialize the taxid tmp file
> "$taxids_map_file"

# Loop through all accessions
while read -r accession rest; do
  # Skip header lines
  [[ "$accession" == "accession"* ]] && continue
  # Fetch the TaxID  
  echo "Searching for accession: $accession"
  taxid=$(esearch -db nuccore -query "$accession" -email "pablo.alessandro@gmail.com" < /dev/null | elink -target taxonomy | esummary | xtract -pattern DocumentSummary -element TaxId)
  # Check if TaxID was retrieved
  if [[ -n "$taxid" ]]; then
    echo -e "$accession\t$taxid" >> "$taxids_map_file"
  else
    echo "Error: Could not find TaxID for $accession"
  fi
done < "$input_file"

echo "Processing completed. Output saved to $taxids_map_file."