#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/14

Script used to create the bowtie database.

params $1 - Line number
params $2 - Input id
params $3 - Input file
params $4 - Output file
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
input_file=$3      # fasta file to create bowtie index
output_file=$4     # bowtie index file
bowtie_build_script="/home/pablo.viana/jobs/scripts/bowtie2-2.5.1-linux-x86_64/bowtie2-build"

if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task! Input: $2 Count: $1"

echo "Executing Bowtie2 to build database using command:"
echo "$bowtie_build_script --threads 8 $input_file $output_file"

$bowtie_build_script --verbose --threads 8 $input_file $output_file


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
