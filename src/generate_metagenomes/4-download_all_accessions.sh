#!/bin/bash

cd data/viral_discovery/

mkdir -p mock_generation
mkdir -p mock_genomes

awk -F',' 'FNR>1 {print $1}' mock_generation/*.csv | sort -u > all_accessions.txt


infile="$1"         # text file with one accession per line
while IFS= read -r acc && [[ -n $acc ]]; do
    printf 'Downloading %s …\n' "$acc" >&2
    efetch -db nuccore -id "$acc" -format fasta > "mock_genomes/${acc}.fasta"
done < all_accessions.txt