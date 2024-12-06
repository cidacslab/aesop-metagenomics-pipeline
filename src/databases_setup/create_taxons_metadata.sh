#!/bin/bash

taxonkit_script="/home/pedro/aesop/github/taxonkit"

# input_file=$1
input_file="./data/dataset_mock/metadata/SI035.csv"
output_file="./data/dataset_mock/metadata/SI035_metadata.csv"

# echo "Executing script for file: $input_file"
# echo "Output file will be: $output_file"
cat $input_file | while IFS=$',' read -r accession rest; do
    taxid=$(esearch -db nuccore -query "$accession" | elink -target taxonomy | esummary | xtract -pattern DocumentSummary -element TaxId)
    echo -e "$accession\t$taxid"
done > taxids_tmp.tsv

# Writes the header to the output file
echo "accession_id,accession_taxid,superkingdom,phylum,class,order,family,genus,species,"\
"superkingdom_taxid,phylum_taxid,class_taxid,order_taxid,family_taxid,genus_taxid,"\
"species_taxid" > "$output_file"

# Read each line from the input file and process
while IFS= read -r accession_id taxid rest; do
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
    echo "$accession_id,$trimmed_lineage"
    # >> $output_file
done < "$taxids_tmp.tsv"

rm taxids_tmp.tsv
