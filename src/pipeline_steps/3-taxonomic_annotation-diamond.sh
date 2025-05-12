#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run blastn taxonomic classification.

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

input_file=$2
input_suffix=$3
# input_dir=$4 # NOT USED
output_dir=$5
nthreads=$6 
path_to_db=$7
diamond_sensitivity=$8
diamond_filter_taxon=$9

input_id=$(basename $input_file $input_suffix)

# input_file="${input_dir}/${input_id}${input_suffix}"
output_file="${output_dir}/${input_id}.txt"

diamond_script=$DIAMOND_EXECUTABLE

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

if [ -n "$diamond_filter_taxon" ]; then
  diamond_filter_taxon="--taxon-exclude ${diamond_filter_taxon}"
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running diamond command: "
echo "$diamond_script blastx --db $path_to_db --query $input_file --threads $nthreads " \
    "--max-target-seqs 100 $diamond_sensitivity $diamond_filter_taxon --out $output_file " \
    "--outfmt 6 qseqid sseqid pident length qcovs qcovhsp mismatch gapopen gaps qstart qend sstart send evalue bitscore staxids salltitles"

$diamond_script blastx --db $path_to_db --query $input_file --threads $nthreads \
    --max-target-seqs 100 $diamond_sensitivity $diamond_filter_taxon --out $output_file \
    --outfmt 6 qseqid sseqid pident length qcovs qcovhsp mismatch gapopen gaps qstart qend sstart send evalue bitscore staxids salltitles


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
