##!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/03/16

Template script used to run a script over the biome metagenomic samples.

params $1 - Number os parallel processes to be executed
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

# Start job profile
start=$(date +%s.%N)
echo "Started running job!"

################################################################################
################################## DOWNLOAD ####################################
################################################################################

ini=$(date +%s.%N)
echo "Started Executing make_blastdb"

# Name of the current dataset
dataset_name="$1"
# Delete preexisting output directory
delete_output_dir="$2"
# Tar Log file name
tar_log_file="$3"
# suffix of each sample forward sequence
input_suffix="$4"
# Download folder
download_dir="$5"
# Destination folder
output_dir="$6"
# Basespace project ID
basespace_project_id="$7"
# Basespace access token
basespace_access_token="$8"


{

pip install biopython

# Path containing the samples
repo_dir="/home/pablo.viana/jobs/github/aesop-metagenomics-pipeline"
output_dir="/opt/storage/shared/aesop/metagenomica/biome/viral_genomes"

# List of accession file names
acc_files=("complete_viruses_aa" "complete_viruses_ab" "complete_viruses_ac")

# Loop through the accession files and run each process in parallel
for acc_file in "${acc_files[@]}"; do
  # Launch each process in the background
  python -u "$repo_dir/src/utils/download_ncbi_viruses.py" "$repo_dir/data/$acc_file" "$output_dir/${acc_file}.fasta" &
  # Sleep for 3 seconds before launching the next process
  sleep 3
done

# Wait for all background processes to finish
wait
echo "All downloads completed."


# Variables
FASTA_FILE="$output_dir/viral_sequences.fasta"
BLAST_DB_NAME="$output_dir/complete_viral_blastdb"
makeblastdb_script="/scratch/pablo.viana/softwares/ncbi-blast-2.14.0+/bin/makeblastdb"

# Empty the output file if it exists
> "$FASTA_FILE"

# Loop through the list of files
for acc_file in "${acc_files[@]}"; do
  # Concatenate the content of each file to the output file, removing empty lines
  grep -v '^$' "$output_dir/${acc_file}.fasta" >> "$FASTA_FILE"
done
echo "Concatenation complete. Output written to $FASTA_FILE."


# Create the BLAST database
$makeblastdb_script -in "$FASTA_FILE" -dbtype nucl -out "$BLAST_DB_NAME"

echo "BLAST database creation complete and files copied to $BLAST_DB_NAME."


# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo "Finished script! Total elapsed time: ${runtime} min."

} &> ${BASHPID}_${input_id}.log
