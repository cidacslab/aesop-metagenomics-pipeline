#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/12/14

Script used to run megahit assembly.

params $1 - NCBI accession id
params $2 - Taxon id
DOC

# Start script profile
# start=$(date +%s.%N)

accession_id=$1
taxon_id=$2
path_to_db="/home/pedro/aesop/pipeline/databases/taxonkit_db"
output_file="complete_viruses_metadata.csv"

lineage=$(printf "%s" $taxon_id | taxonkit --data-dir $path_to_db reformat -I 1 -F -t -f ",{k},{p},{c},{o},{f},{g},{s}" )

trimmed_lineage=$(awk -F',' '{for(i=1; i<=NF; i++) {gsub(/^[ \t]+|[ \t]+$/, "", $i); printf "%s%s", $i, (i==NF ? "" : ",")}}' <<< "$lineage")

printf "%s\n" "$accession_id,$trimmed_lineage" >> $output_file

# Finish script profile
# finish=$(date +%s.%N)
# runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)}')
# echo "Finished script! Total elapsed time: ${runtime} s."