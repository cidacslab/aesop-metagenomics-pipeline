#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/12/14

Script used to run megahit assembly.

params $1 - NCBI accession id
params $2 - Taxon id
DOC

accession_id=$1
taxon_id=$2

lineage=$(printf "%s" $taxon_id | taxonkit --data-dir $path_to_db reformat -I 1 -F -t -f ",{s}" )

trimmed_lineage=$(awk -F',' '{for(i=1; i<=NF; i++) {gsub(/^[ \t]+|[ \t]+$/, "", $i); printf "%s%s", $i, (i==NF ? "" : ",")}}' <<< "$lineage")

printf "%s,%s\n" "$accession,$trimmed_lineage"
