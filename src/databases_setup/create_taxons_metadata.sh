#!/bin/bash

export NCBI_API_KEY="86cf88e5ee6087442f57c78ed90336b99408"
taxonkit_script="taxonkit"

# file=$1
file="SI041_1"
input_file="./data/dataset_mock/metadata/${file}.csv"
output_file="./data/dataset_mock/metadata/${file}_metadata.csv"
taxids_tmp_file="./data/dataset_mock/metadata/${file}_taxids_tmp.csv"

# Initialize the taxid tmp file
> "$taxids_tmp_file"
# Loop through all accessions
while IFS=',' read -r accession rest; do
  # Skip lines starting with 'accession'
  [[ "$accession" == "accession"* ]] && continue
  # Fetch the TaxID  
  echo "Searching for accession: $accession"
  taxid=$(esearch -db nuccore -query "$accession" < /dev/null| elink -target taxonomy | esummary | xtract -pattern DocumentSummary -element TaxId)
  # Include this tax id to the taxid file
  echo "$accession,$taxid" >> "$taxids_tmp_file"
done < "$input_file"

# Writes the header to the output file
echo "accession_id,accession_taxid,superkingdom,phylum,class,order,family,genus,species,"\
"superkingdom_taxid,phylum_taxid,class_taxid,order_taxid,family_taxid,genus_taxid,"\
"species_taxid" > "$output_file"

# Read each line from the input file and process
while IFS=',' read -r accession_id taxid rest; do
  # Skip the line (when acession_id variable is not set yet)
  if [[ -z "$accession_id" ]]; then
    accession_id=1
    continue
  fi
  echo "Accession: $accession_id"

  if [[ -z "$taxid" ]]; then
    echo "taxid not found for line: ${line}"
    continue
  fi
  echo "Tax Id: $taxid"

  lineage=$(echo "$taxid" | $taxonkit_script reformat -I 1 -F -t -f ",{k},{p},{c},{o},{f},{g},{s}")
  echo $lineage

  # Remove trailing spaces from lineage
  trimmed_lineage=$(echo "$lineage" | awk -F',' '{for(i=1;i<=NF;i++) {gsub(/^[[:space:]]+|[[:space:]]+$/,"",$i); printf "%s%s",$i,(i==NF?"":",");}}')
  # echo $trimmed_lineage
  # Append the result to the output file
  echo "$accession_id,$trimmed_lineage" >> $output_file
done < "$taxids_tmp_file"

rm "$taxids_tmp_file"
