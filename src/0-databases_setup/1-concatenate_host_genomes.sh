#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/14

Script used to concatenate fasta files into one file.

params $1 - Line number
params $2 - Input id
params $3 - Input directory
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
input_dir=$3
output_file=$4

if [ ! -d $input_dir ]; then
  echo "Input directory not found: $input_dir" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Create the empty output file"
>$output_file

# Loop over all .fasta files in the input directory
for input_file in find $input_dir -type f -name ".fasta"; do
  # Get the filename without the path and extension
  filename=$(basename "$input_file" .fasta)
  prepend_string="${filename%.*}"

  # Use awk to add the string to the beginning of each line that starts with ">"
  awk '/^>/ {sub(/^>/, "&'"$prepend_string"'");} 1' "$input_file" >> "${output_file}"
done


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log


