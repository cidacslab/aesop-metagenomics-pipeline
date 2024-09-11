#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to create the bowtie database.

params $1 - Line number
params $2 - Input file
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

echo "Started task! Input: $2 Count: $1" >&1
echo "Started task! Input: $2 Count: $1" >&2

input_id=$2
input_suffix=$3
input_dir=$4
output_dir=$5
nthreads=$6
path_to_db=$7

input_id=$(basename $input_id $input_suffix)

input_suffix1=$input_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_file1="${input_dir}/${input_id}${input_suffix1}"
input_file2="${input_dir}/${input_id}${input_suffix2}"

input_id=${input_id/_metadata/}
output_final="${output_dir}/${input_id}_1.fastq"
# output_fastq="${output_dir}/${input_id}_%.fastq"
output_fastq1="${output_dir}/${input_id}_1.fastq"
output_fastq2="${output_dir}/${input_id}_2.fastq"
output_sam="${output_dir}/${input_id}.sam"
# output_bam="${output_dir}/${input_id}.bam"
output_unmapped_bam="${output_dir}/${input_id}_unmapped.bam"

bowtie2_script=$BOWTIE2_EXECUTABLE
samtools_script=$SAMTOOLS_EXECUTABLE

# if exists output
if [ -f $output_final ]; then
  echo "Output file already exists: $output_final" >&2
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
echo "Started task! Input: $2 Count: $1"

# echo "$bowtie2_script --threads $nthreads --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 --un-conc $output_fastq > /dev/null"
# $bowtie2_script --threads $nthreads --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 --un-conc $output_fastq > /dev/null

# Step 1: Align Reads with Bowtie2
echo "$bowtie2_script --very-sensitive-local --threads $nthreads --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 -S $output_sam > /dev/null"
$bowtie2_script --very-sensitive-local --threads $nthreads --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 -S $output_sam > /dev/null

# # Step 2: Convert SAM to BAM
# # Step 3: Filter BAM File with -f 13 Flag
echo "$samtools_script view -Sb -f 13 $output_sam > $output_unmapped_bam"
$samtools_script view -Sb -f 13 $output_sam > $output_unmapped_bam

# Step 4: Convert Filtered BAM to Paired FASTQ Files
echo "$samtools_script fastq -1 $output_fastq1 -2 $output_fastq2 $output_unmapped_bam"
$samtools_script fastq -1 $output_fastq1 -2 $output_fastq2 $output_unmapped_bam

# Step 5: Delete intermediate files
echo "rm $output_sam $output_unmapped_bam"
rm $output_sam $output_unmapped_bam

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."
} &> ${BASHPID}_${input_id}.log
