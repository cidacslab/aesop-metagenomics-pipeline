#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Script used to run megahit assembly.

params $1 - Line number
params $2 - Input id
params $3 - Input suffix
params $4 - Input directory
params $5 - Output directory
params $6 - Number of parallel threads
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
input_mapping_suffix=$7
input_mapping_dir=$8

input_id=$(basename $input_id $input_suffix)

input_suffix1=$input_mapping_suffix
input_suffix2=${input_suffix1/_R1_/_R2_}
input_suffix2=${input_suffix2/_R1./_R2.}
input_suffix2=${input_suffix2/_1./_2.}

input_contigs="${input_dir}/${input_id}${input_suffix}"
input_file1="${input_mapping_dir}/${input_id}${input_suffix1}"
input_file2="${input_mapping_dir}/${input_id}${input_suffix2}"

output_prefix="${output_dir}/${input_id}"

bowtie2_script=$BOWTIE2_EXECUTABLE
bowtie2_build_script=$BOWTIE2_BUILD_EXECUTABLE
samtools_script=$SAMTOOLS_EXECUTABLE


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

# Step 1: Index the Contigs using Bowtie2
echo "Indexing contigs with Bowtie2..."
$bowtie2_build_script $input_contigs ${output_prefix}_contigs_index

# Step 2: Align the Paired-End Reads to the Contigs using Bowtie2
echo "Aligning reads with Bowtie2..."
$bowtie2_script -x ${output_prefix}_contigs_index --threads $nthreads -1 $input_file1 -2 $input_file2 -S "${output_prefix}_aligned.sam"

# Step 3: Convert SAM to BAM, Sort, and Index using Samtools
echo "Converting SAM to BAM, sorting, and indexing..."
$samtools_script view -Sb "${output_prefix}_aligned.sam" > "${output_prefix}_aligned.bam"
$samtools_script sort "${output_prefix}_aligned.bam" -o "${output_prefix}_sorted_aligned.bam"
$samtools_script index "${output_prefix}_sorted_aligned.bam"

# Step 4: Calculate Coverage per Contig using Samtools
echo "Calculating coverage for each contig..."
$samtools_script depth "${output_prefix}_sorted_aligned.bam" > "${output_prefix}_coverage.tsv"

# Step 5: Print per-contig read counts and coverage
echo "Generating read count per contig and coverage summary..."

# Get contig read counts and coverage
$samtools_script idxstats "${output_prefix}_sorted_aligned.bam" > "${output_prefix}_contig_read_counts.tsv"

printf "Contig\tReference_Length\tTotal_Reads\tCoverage\n" > "${output_prefix}_contig_stats.tsv"

# Combine read counts and coverage in one report
while read -r contig; do
  # Extract the number of reads that mapped to the current contig
  reference_length=$(grep "^$contig\s" "${output_prefix}_contig_read_counts.txt" | cut -f2)

  # Extract the number of reads that mapped to the current contig
  reads_mapped=$(grep "^$contig\s" "${output_prefix}_contig_read_counts.txt" | cut -f3)
  
  # Calculate total coverage for the current contig
  total_coverage=$(grep "^$contig\s" "${output_prefix}_coverage.txt" | awk '{sum += $3} END {print sum}')
  
  # Output the results (use 0 for coverage if it's not found)
  printf "${contig}\t${reference_length}\t${reads_mapped}\t${total_coverage:-0}\n" >> "${output_prefix}_contig_stats.tsv"

  # Step 6: Extract reads mapped to the current contig
  echo "Extracting reads mapped to $contig..."
  
  # Use samtools to extract all reads mapped to the contig
  $samtools_script view "${output_prefix}_sorted_aligned.bam" "$contig" | \
    awk -v contig_name="$contig" '{print contig_name "\t" $1}' >> "${output_prefix}_contig_reads.tsv"
  
done < <(grep ">" "$input_contigs" | sed 's/>//')

echo "Cleaning intermediate files..."
rm -rvf ${output_prefix}_contigs_index* ${output_prefix}_aligned* ${output_prefix}_sorted*

echo "Mapping and coverage calculation completed."
echo "Results are stored in ${output_prefix}_contig_stats.txt."


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
