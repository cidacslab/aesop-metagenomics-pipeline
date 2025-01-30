#!/bin/bash

input_folder=$1

for file in $input_folder/*.tsv; do
  awk -F "\t" '{print $1}' "$file" | awk 'NR==FNR {acc[$1]; next} $1 in acc' - accession_taxid.tmp > "${file%.tsv}_map.txt"
done
