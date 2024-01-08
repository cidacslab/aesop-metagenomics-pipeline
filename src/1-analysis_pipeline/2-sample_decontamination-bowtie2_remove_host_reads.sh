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
input_dir=$3
output_dir=$4

input_id=$(basename $input_id .fastq)
input_id=${input_id/_R1/}
input_id=${input_id/_R2/}
input_file1="${input_dir}/${input_id}_R1.fastq"
input_file2="${input_dir}/${input_id}_R2.fastq"

output_sam="${output_dir}/SAM_FILES/${input_id}_mapped_and_unmapped.sam"
output_bam="${output_dir}/BAM_FILES/${input_id}_mapped_and_unmapped.bam"
#output_sorted_bam="${output_dir}/BAM_FILES/${input_id}_mapped_and_unmapped.sorted.bam"
output_fasta="${output_dir}/UNMAPPED_FASTA/${input_id}.fasta"
output_final="${output_dir}/${input_id}.fasta"

path_to_db="/scratch/pablo.viana/databases/bowtie2db_host_genomes/all_host_genomes_index"
bowtie2_script="/scratch/pablo.viana/softwares/bowtie2-2.5.1-linux-x86_64/bowtie2"
samtools_script="/scratch/pablo.viana/softwares/samtools-1.17/bin/samtools"

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

echo "Executing Bowtie2 to map sample reads to the contaminats db:"
echo "$bowtie2_script --threads 8 --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 -S $output_sam"
$bowtie2_script --threads 8 --met-stderr -x $path_to_db -q -1 $input_file1 -2 $input_file2 -S $output_sam

echo "Executing samtools to convert mapped output to bam format:"
echo "$samtools_script view -bS $output_sam > $output_bam"
$samtools_script view -bS $output_sam > $output_bam

#echo "Executing samtools to sort results:"
#echo "$samtools_script sort $output_sam -o $output_sorted_bam"
#$samtools_script sort $output_sam -o $output_sorted_bam

echo "Executing samtools to remove reads mapped to contaminats from samples:"
echo "$samtools_script fasta -f 4 $output_bam > $output_fasta"
$samtools_script fasta -f 4 $output_bam > $output_fasta

echo "Moving final output: mv $output_fasta $output_dir"
mv $output_fasta $output_dir

echo "Removing intermediate files: rm $output_sam $output_bam"
#rm $output_sam $output_bam #$output_sorted_bam

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."
} &> ${BASHPID}_${input_id}.log
