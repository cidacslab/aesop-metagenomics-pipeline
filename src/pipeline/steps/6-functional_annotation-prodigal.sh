#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2025/05/23

Script used to run prodigal functional annotation.

params $1 - Sample number, representing its order in input list
params $2 - Input sample file path
params $3 - Suffix of the input file
params $4 - Input sample directory
params $5 - Output directory where to place the output files
params $6 - Number of threads to use in this process
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
# input_suffix=$3  # NOT USED
# input_dir=$4     # NOT USED
output_dir=$5
# nthreads=$6      # NOT USED

# Define the input file ID
input_id=$(basename $input_file)
input_id="${input_id%%.*}"

# Define output file names
output_faa="${output_dir}/${input_id}.faa"
output_sco="${output_dir}/${input_id}.sco"

# Define the path to the prodigal executable
prodigal_script=$PRODIGAL_EXECUTABLE

# check if output file exists
if [ -f $output_faa ]; then
  echo "Output file already exists: $output_faa" >&2
  exit 0
fi

# check if input file exists
if [ ! -f $input_file ]; then
  echo "Input file not found: $input_file" >&2
  exit 1
fi
if [ ! -s $input_file ]; then
  echo "Input file is empty: $input_file" >&2
  exit 0
fi

{
  # Start script profile
  start=$(date +%s.%N)
  
  echo "Started task Input: $2 Count: $1"
  
  echo "Running prodigal command: "
  echo "$prodigal_script -p meta -f sco -i $input_file -a $output_faa -o $output_sco"
  $prodigal_script -p meta -f sco -i $input_file -a $output_faa -o $output_sco
  
  # Compress the output file
  # if [ -f $output_faa ]; then
  #   echo "Compressing output file: gzip -v $output_faa"
  #   gzip -v $output_faa
  # fi
  
  # Finish script profile
  finish=$(date +%s.%N)
  runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
  echo "Finished script! Total elapsed time: ${runtime} min."
  
} &> ${BASHPID}_${input_id}.log
