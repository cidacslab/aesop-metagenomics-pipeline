#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/10/23

Script used to run megahit assembly.

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
input_suffix=$3
input_dir=$4
output_dir=$5
nthreads=$6 

input_id=$(basename $input_file $input_suffix)

input_suffix1=$input_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_file1="${input_dir}/${input_id}${input_suffix1}"
input_file2="${input_dir}/${input_id}${input_suffix2}"

megahit_script=$MEGAHIT_EXECUTABLE


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

echo "Running megahit command: "
echo "$megahit_script --presets meta-sensitive --min-contig-len 200 -t $nthreads" \
  "-1 $input_file1 -2 $input_file2 --out-dir $output_dir/$input_id --out-prefix $input_id"

$megahit_script --presets meta-sensitive --min-contig-len 200 -t $nthreads \
  -1 $input_file1 -2 $input_file2 --out-dir $output_dir/$input_id --out-prefix $input_id
  
rm -rvf $output_dir/$input_id/intermediate_contigs

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
