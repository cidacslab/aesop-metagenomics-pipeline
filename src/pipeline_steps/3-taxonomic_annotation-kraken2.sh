#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run kraken2 taxonomic classification.

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
nthreads=$6 
path_to_db=$7
confidence=$8
keep_output=$9

input_id=$(basename $input_id $input_suffix)

input_suffix1=$input_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_file1="${input_dir}/${input_id}${input_suffix1}"
input_file2="${input_dir}/${input_id}${input_suffix2}"
input_file="${input_dir}/${input_id}#.fastq"

output_kraken_report="${output_dir}/${input_id}.kreport"
output_kraken_output="/dev/null"

if [ $keep_output -eq 1 ]; then
  output_kraken_output="${output_dir}/${input_id}.kout"
fi

kraken2_script=$KRAKEN2_EXECUTABLE

# if exists output
if [ -f $output_kraken_report ]; then
  echo "Output file already exists: $output_kraken_report" >&2
  exit 1
fi

# if not exists input
if [ ! -f $input_file1 ]; then
  echo "Input file1 not found: $input_file1" >&2
  exit 1
fi
if [ ! -f $input_file2 ]; then
  echo "Input file2 not found: $input_file2" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running kraken command: "
echo "$kraken2_script --db $path_to_db --paired $input_file1 $input_file2 --output $output_kraken_output" \
  "--report $output_kraken_report --threads $nthreads --confidence $confidence"

$kraken2_script --db $path_to_db --paired $input_file1 $input_file2 --output $output_kraken_output \
  --report $output_kraken_report --threads $nthreads --confidence $confidence
  

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
