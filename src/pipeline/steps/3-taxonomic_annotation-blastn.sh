#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run blastn taxonomic classification.

params $1 - Sample number, representing its order in input list
params $2 - Input sample file path
params $3 - Suffix of the input file
params $4 - Input sample directory
params $5 - Output directory where to place the output files
params $6 - Number of threads to use in this process
params $7 - blastn database path
params $8 - blastn task parameter
params $9 - blastn negative_taxidlist parameter listing taxa to exclude from analysis
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
blastn_task=$8
blastn_filter_taxon=$9

input_id=$(basename $input_file $input_suffix)

# input_file="${input_dir}/${input_id}${input_suffix}"
output_file="${output_dir}/${input_id}.txt"

blastn_script=$BLASTN_EXECUTABLE

# if exists output
if [ -f $output_file ]; then
  echo "Output file already exists: $output_file" >&2
  exit 0
fi

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

blast_filter=""
if [ -f "$blastn_filter_taxon" ]; then
  blast_filter="-negative_taxidlist ${blastn_filter_taxon}"
  # blastn_filter_taxon="-negative_taxids ${blastn_filter_taxon}"
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running blastn command: "
echo "$blastn_script -db $path_to_db -query $input_file -task $blastn_task $blast_filter"  \
  "-outfmt '7 qseqid sseqid pident length qlen slen qcovhsp mismatch gapopen gaps qstart qend sstart send evalue bitscore staxids salltitles'" \
  "-max_target_seqs 100 -num_threads $nthreads -out $output_file"

$blastn_script -db $path_to_db -query $input_file -task $blastn_task $blast_filter \
  -outfmt "7 qseqid sseqid pident length qlen slen qcovhsp mismatch gapopen gaps qstart qend sstart send evalue bitscore staxids salltitles" \
  -max_target_seqs 100 -num_threads $nthreads -out $output_file


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
