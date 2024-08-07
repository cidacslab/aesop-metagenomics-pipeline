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

#number of parallel processes
num_processes=$1
# name of the run folder
run_name=$2
# Basespace project ID
basespace_project_id=$3


################################################################################
############################### ATTENTION !!!!! ################################
################################################################################
################### FOR EACH ANALYSIS FILL THESE INFORMATION ###################
################################################################################

# run_name="rs01"
dataset_name="aesop_${run_name}"

# old_dataset_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v2/dataset_${run_name}"
base_dataset_path="/scratch/pablo.viana/mocks/read_length_review/dataset_${run_name}"

# Bowtie2 index to remove hosts reads
bowtie2_hosts_index="/scratch/pablo.viana/databases/bowtie2db_host_genomes_v2/hosts_index"

# Kraken2 database
# kraken2_database="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"
kraken2_database="/scratch/pablo.viana/databases/kraken_db/k2_pluspfp_20240605"

# Location of src folder in the github directory
repository_src="/home/pablo.viana/metagenomics_src"

# Script to execute the tasks
custom_script="$repository_src/0-hpc_job_scripts/execute_custom_script.sh"

# Script to download samples from basespace
download_script="$repository_src/0-hpc_job_scripts/execute_download_script.sh"


################################################################################
################################## DOWNLOAD ####################################
################################################################################

# Basespace file suffix
# Suffix of each sample forward sequence
input_suffix="_R1.fastq"

# params=("$num_processes"
#         "/scratch/pablo.viana/softwares/basespace_illumina/bs"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_dataset_path/0-download"
#         "$base_dataset_path/0-raw_samples"
#         "$basespace_project_id")

# $download_script "${params[@]}"


################################################################################
###################################  FASTP  ####################################
################################################################################

# params=("$num_processes"
#         "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/1-quality_control-fastp_filters.sh"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_dataset_path/0-raw_samples"
#         "$base_dataset_path/1-fastp_output")

# $custom_script "${params[@]}"

# echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
# tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json

# rm -vf *.html *.json


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="_1.fastq"

# params=("$num_processes"
#         "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_dataset_path/1-fastp_output"
#         "$base_dataset_path/2-bowtie_output"
#         $bowtie2_hosts_index)

# $custom_script "${params[@]}"


################################################################################
#############################  KRAKEN2 ##############################
################################################################################

params=("$num_processes"
        "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/1-fastp_output"
        "$base_dataset_path/3-kraken_results"
        "$kraken2_database")

$custom_script "${params[@]}"


################################################################################
################################################################################

# echo ""
# df
# du -hd 4 /scratch/pablo.viana
# find /scratch/pablo.viana 

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"