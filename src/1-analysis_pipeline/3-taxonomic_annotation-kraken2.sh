#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run kraken2 taxonomic classification.

params $1 - Line number
params $2 - Input id
params $3 - Input directory
params $4 - Output directory
params $5 - Kraken DB directory
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

input_id=$(basename $input_id .fasta)
input_file="${input_dir}/${input_id}.fasta"
# path_to_db="/scratch/pablo.viana/databases/kraken_db/aesop_kraken_db"
# path_to_db="/scratch/pablo.viana/databases/kraken_db/aesop_kraken_pfp_db"

output_prefix="${output_dir}/${input_id}"
output_kraken_class="${output_prefix}/${input_id}.class"
output_kraken_unclass="${output_prefix}/${input_id}.unclass"
output_kraken_output="${output_prefix}/${input_id}.out"
output_kraken_report="${output_prefix}/${input_id}.report"
output_tar_results="${output_prefix}.tar.gz"
nthreads_chosen=8

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

# Create folder if it doesn't exist
mkdir -p $output_prefix
#mkdir -p $path_to_reports

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running kraken command: "
echo "kraken2 --db $path_to_db $input_file --classified-out $output_kraken_class" \
  "--unclassified-out $output_kraken_unclass -output $output_kraken_output" \
  "--report $output_kraken_report --threads $nthreads_chosen"

kraken2 --db $path_to_db $input_file --classified-out $output_kraken_class \
  --unclassified-out $output_kraken_unclass -output $output_kraken_output \
  --report $output_kraken_report --threads $nthreads_chosen
  

echo "cd $output_prefix"
cd $output_prefix

echo "tar gzip the results: tar -czvf $output_tar_results ."
tar -czf $output_tar_results .

echo "cp $output_tar_results $ouput_final_dir"
#cp $output_tar_results $ouput_final_dir

echo "rm -rf $output_prefix"
#rm -rf $output_prefix

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
