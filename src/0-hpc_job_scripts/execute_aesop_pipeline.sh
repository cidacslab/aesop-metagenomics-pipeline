#!/bin/bash
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

# Script to execute the tasks
custom_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/0-hpc_job_scripts/execute_custom_script.sh"
# Script to download samples from basespace
download_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/0-hpc_job_scripts/execute_download_script.sh"

################################################################################
############################### ATTENTION !!!!! ################################
################################################################################
################### FOR EACH ANALYSIS FILL THESE INFORMATION ###################
################################################################################

# Basespace file suffix
input_suffix="_L001_R1_001.fastq.gz"
# Basespace project ID
basespace_project_id=403173828

# suffix of each sample forward sequence
dataset_name="aesop_rio02"
base_path="/scratch/pablo.viana/aesop/dataset_rio02"
kraken_database="/scratch/pablo.viana/databses/kraken2/aesop_kraken_"

################################################################################
################################## DOWNLOAD ####################################
################################################################################

params=("$1"
        "/scratch/pablo.viana/softwares/basespace_illumina/bs"
        "$dataset_name"
        "$input_suffix"
        "$base_path/0-download"
        "$base_path/0-raw_samples"
        "$basespace_project_id")

$download_script "${params[@]}"


################################################################################
###################################  FASTP  ####################################
################################################################################

input_suffix="*_1.fastq"

params=("$1"
        "/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/1-quality_control-fastp_filters.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_path/0-raw_samples"
        "$base_path/1-fastp_output")

$custom_script "${params[@]}"


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

params=("$1"
        "/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_path/1-fastp_output"
        "$base_path/2-bowtie_output")

$custom_script "${params[@]}"

echo "Removing intermediate folders: rm -rf $output_dir/SAM_FILES $output_dir/BAM_FILES $output_dir/UNMAPPED_FASTA"
rm -rf "$output_dir/SAM_FILES" "$output_dir/BAM_FILES" "$output_dir/UNMAPPED_FASTA"


################################################################################
#############################  KRAKEN2 e BRACKEN  ##############################
################################################################################

params=("$1"
        "/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/3-taxonomic_annotation-kraken2_bracken.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_path/2-bowtie_output"
        "$base_path/3-kraken_results")

# $custom_script "${params[@]}"


################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"