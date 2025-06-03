#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/10/23

Script used to run kraken2 taxonomic classification.

params $1 - Sample number, representing its order in input list
params $2 - Input sample file path
params $3 - Suffix of the input file
params $4 - Input sample directory
params $5 - Output directory where to place the output files
params $6 - Number of threads to use in this process
params $7 - kraken2 output directory
params $8 - list of taxon ids parameter
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
# nthreads=$6 # NOT USED
kraken_output_dir=$7
taxons=$8

input_id=$(basename $input_file $input_suffix)

input_suffix1=$input_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_file1="${input_dir}/${input_id}${input_suffix1}"
input_file2="${input_dir}/${input_id}${input_suffix2}"

output_fastq1="${output_dir}/${input_id}_1.fastq"
output_fastq2="${output_dir}/${input_id}_2.fastq"
tmp_output_fastq1="${output_dir}/tmp_${input_id}_1.fastq"
tmp_output_fastq2="${output_dir}/tmp_${input_id}_2.fastq"

kraken_report="${kraken_output_dir}/${input_id}.kreport"
kraken_output="${kraken_output_dir}/${input_id}.kout"

extract_reads_script=$EXTRACT_READS_EXECUTABLE

# if exists output
if [ -f $output_fastq1 ]; then
  echo "Output file already exists: $output_fastq1" >&2
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

# Initialize output as empty files
> $output_fastq1
> $output_fastq1

IFS=',' read -r -a taxon_array <<< "$taxons"
# Iterate over each taxon in the list and extract reads
for taxon in "${taxon_array[@]}"; do
  # Run extract_reads_script for the current taxon
  echo "Running extract kraken reads command: "
  echo "$extract_reads_script -k $kraken_output -r $kraken_report -t $taxon --include-children" \
    "-s $input_file1 -s2 $input_file2 --fastq-output -o $tmp_output_fastq1 -o2 $tmp_output_fastq2"
  $extract_reads_script -k $kraken_output -r $kraken_report -t $taxon --include-children \
    -s $input_file1 -s2 $input_file2 --fastq-output -o $tmp_output_fastq1 -o2 $tmp_output_fastq2
  
  # Concatenate the current output to the final combined output
  cat $tmp_output_fastq1 >> $output_fastq1
  cat $tmp_output_fastq2 >> $output_fastq2
  
  # Remove the temporary output files to avoid duplication in the next iteration
  rm -f $tmp_output_fastq1 $tmp_output_fastq2
done

echo "gzip $output_fastq1"
gzip $output_fastq1

echo "gzip $output_fastq2"
gzip $output_fastq2

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
