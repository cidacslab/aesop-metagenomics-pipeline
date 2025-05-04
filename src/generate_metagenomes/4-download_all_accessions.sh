#!/bin/bash

path="/home/pedro/aesop/github/aesop-metagenomics-pipeline/data/viral_discovery"
mkdir -p $path/genomes

# List all accessions
# awk -F',' 'FNR>1 {print $1}' $path/mock_generation/*fixed_completed.csv | sort -u > $path/all_accessions.txt

# iterate over each accession in the file and download one by one 
while IFS= read -r acc && [[ -n $acc ]]; do
    printf 'Downloading %s …\n' "$acc" >&2
    efetch -db nuccore -id "$acc" -format fasta > "${path}/genomes/${acc}.fasta"
done < $path/all_accessions.txt