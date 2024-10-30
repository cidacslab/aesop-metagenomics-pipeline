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

input_id=$(basename $input_file $input_suffix)

# input_file="${input_dir}/${input_id}${input_suffix}"
output_file="${output_dir}/${input_id}.txt"

blastn_script=$BLASTN_EXECUTABLE

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running blastn command: "
echo "$blastn_script -db $path_to_db -query $input_file" \
    "-outfmt '7 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore staxids salltitles'" \
    "-max_target_seqs 10 -evalue 0.001 -num_threads $nthreads -out $output_file"

$blastn_script -db $path_to_db -query $input_file \
    -outfmt "7 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore staxids salltitles" \
    -max_target_seqs 10 -evalue 0.001 -num_threads $nthreads -out $output_file


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
