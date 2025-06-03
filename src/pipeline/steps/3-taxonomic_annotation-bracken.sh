#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run bracken taxonomic classification.

params $1 - Sample number, representing its order in input list
params $2 - Input sample file path
params $3 - Suffix of the input file
params $4 - Input sample directory
params $5 - Output directory where to place the output files
params $6 - Number of threads to use in this process
params $7 - bracken database path
params $8 - bracken read length parameter
params $9 - bracken threshold output
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
input_dir=$4
output_dir=$5
nthreads=$6 # NOT USED
path_to_db=$7
read_length=$8
threshold=$9

input_id=$(basename $input_file .kreport)
input_kraken_report="${input_dir}/${input_id}.kreport"
output_bracken="${output_dir}/${input_id}.bracken"

bracken_script=$BRACKEN_EXECUTABLE

# if exists output
if [ -f $output_bracken ]; then
  echo "Output file already exists: $output_bracken" >&2
  exit 0
fi

# if not exists input
if [ ! -f $input_kraken_report ]; then
  echo "Input report not found: $input_kraken_report" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Running bracken command: "
echo "$bracken_script -d $path_to_db -i $input_kraken_report -o $output_bracken -r $read_length -t $threshold"

$bracken_script -d $path_to_db -i $input_kraken_report -o $output_bracken -r $read_length -t $threshold

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
