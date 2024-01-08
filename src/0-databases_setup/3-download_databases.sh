#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/03/16

Script used to download SRA files.

params $1 - Line number
params $2 - Input file id
params $3 - Output folder
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

url_name=$2
input_dir=$3
output_dir=$4

{
# Start script profile
start=$(date +%s.%N)
echo "Started task! Input: $2 Count: $1"

wget -P $output_dir $url_name

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."
} &> ${BASHPID}.log