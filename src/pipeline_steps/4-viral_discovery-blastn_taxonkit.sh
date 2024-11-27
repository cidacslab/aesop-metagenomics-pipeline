#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run megahit assembly.

params $1 - Line number
params $2 - Input id
params $3 - Input suffix
params $4 - Input directory
params $5 - Output directory
params $6 - Number of parallel threads
DOC

# create alias to echo command to log time at each call
echo() {
    command echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: $@"
}
# exit when any command fails
set -e
# keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# echo an error message before exiting
trap 'echo "\"${last_command}\" command ended with exit code $?." >&2' EXIT

echo "Started task! Input: $2 Count: $1" >&1
echo "Started task! Input: $2 Count: $1" >&2

input_id=$2
input_suffix=$3
input_dir=$4
output_dir=$5
#nthreads=$6 #NOT USED
path_to_db=$7

input_id=$(basename $input_id $input_suffix)

input_file="${input_dir}/${input_id}${input_suffix}"
taxid_file="${output_dir}/${input_id}_taxids.txt"
output_file="${output_dir}/${input_id}_metadata.csv"

taxonkit_script=$TAXONKIT_EXECUTABLE
taxonkit_script="/home/pedro/aesop/github/taxonkit"


# if not exists input
if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

# Step 1: Collect all tax ids from the blastn results
awk '!/^#/ { print $13 }' $input_file | sort | uniq > $taxid_file

> $output_file

# Step 2: Read each line from the input file and process
while IFS= read -r taxid; do
  echo $taxid
  
  lineage=$(printf "%s" $taxid | $taxonkit_script --data-dir $path_to_db reformat -I 1 -F -t -f ",{k},{p},{c},{o},{f},{g},{s}" )
  echo $lineage
  
  # Remove trailing spaces from lineage
  trimmed_lineage=$(awk -F',' '{for(i=1; i<=NF; i++) {gsub(/^[ \t]+|[ \t]+$/, "", $i); printf "%s%s", $i, (i==NF ? "" : ",")}}' <<< "$lineage")
  
  # Append the result to the output file
  printf "%s\n" "$trimmed_lineage" >> $output_file
done < "$taxid_file"


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
