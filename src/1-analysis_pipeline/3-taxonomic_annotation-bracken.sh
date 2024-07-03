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
input_suffix=$3
input_dir=$4
output_dir=$5
path_to_db=$6
read_length=$7

input_id=$(basename $input_id .kreport)
input_kraken_report="${input_dir}/${input_id}.kreport"
output_bracken="${output_dir}/${input_id}.bracken"

bracken_script="/scratch/pablo.viana/softwares/Bracken-master/bracken"


# if exists output
if [ -f $output_bracken ]; then
  echo "Output file already exists: $output_bracken" >&2
  exit 1
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
echo "$bracken_script -d $path_to_db -i $input_kraken_report -o $output_bracken -r $read_length -t 1"

$bracken_script -d $path_to_db -i $input_kraken_report -o $output_bracken -r $read_length -t 1

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
