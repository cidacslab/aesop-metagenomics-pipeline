#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/05

Script used to preprocess fastq files using FASTP.

params $1 - Line number
params $2 - Input id
params $3 - Input directory
params $4 - Output directory
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

echo "  Started task! Input: $2 Count: $1" >&1
echo "  Started task! Input: $2 Count: $1" >&2

input_id=$2
input_suffix=$3
input_dir=$4
output_dir=$5
nthreads=$6
minimum_quality=$7
minimum_length=$8
max_n_count=$9

input_id=$(basename $input_id $input_suffix)

input_suffix1=$input_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_file1="${input_dir}/${input_id}${input_suffix1}"
input_file2="${input_dir}/${input_id}${input_suffix2}"

input_id=${input_id/_metadata/}
output_file1="${output_dir}/${input_id}_1.fastq.gz"
output_file2="${output_dir}/${input_id}_2.fastq.gz"

fastp_script=$FASTP_EXECUTABLE

if [ ! -f $input_file1 ]; then
  echo "Input file not found: $input_file1" >&2
  exit 1
fi
if [ ! -f $input_file2 ]; then
  echo "Input file not found: $input_file2" >&2
  exit 1
fi

{
# Start script profile
start=$(date +%s.%N)

echo "Started task Input: $2 Count: $1"

echo "Executing FASTP using command:"
echo "$fastp_script -i $input_file1 -I $input_file2" \
      " -o $output_file1 -O $output_file2 --thread $nthreads" \
      " -j ${input_id}_fastp_report.json -h ${input_id}_fastp_report.html" \
      " --length_required $minimum_length --average_qual 20" \
      " --cut_front --cut_front_window_size 1 --cut_front_mean_quality 20" \
      " --cut_tail --cut_tail_window_size 1 --cut_tail_mean_quality 20" \
      " --n_base_limit $max_n_count"
$fastp_script -i $input_file1 -I $input_file2 \
  -o $output_file1 -O $output_file2 --thread $nthreads \
  -j "${input_id}_fastp_report.json" -h "${input_id}_fastp_report.html" \
  --cut_front --cut_tail --cut_window_size 3 --cut_mean_quality $minimum_quality \
  --length_required $minimum_length --qualified_quality_phred $minimum_quality \
  --n_base_limit $max_n_count

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
