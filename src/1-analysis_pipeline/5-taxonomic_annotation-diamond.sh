#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run kraken2 taxonomic classification.

params $1 - Line number
params $2 - Input id
params $3 - Input directory
params $4 - Output directory
params $5 - Database directory
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
input_dir=$3
output_dir=$4
path_to_db=$5

diamond_script="/scratch/pablo.viana/softwares/diamond"

input_id=$(basename $input_id .fasta)
input_file="${input_dir}/${input_id}.fasta"
output_file="${output_dir}/${input_id}_diamond_result.tsv"

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"
echo "Running diamond command: "

echo "Go to database folder: cd $path_to_db"
cd $path_to_db

echo "$diamond_script blastx -d nr -q $input_file -o $output_file"
$diamond_script blastx -d nr -q $input_file -o $output_file --threads 16 --max-target-seqs 20
 

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
