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

################################################################################
################################## INPUT ARGS ##################################
################################################################################

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

# Name of the run folder
# run_name="rs01"
# old_dataset_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v2/dataset_${run_name}"
# base_dataset_path="/home/work/aesop/results_pipeline_v4/dataset_${run_name}"
base_dataset_path="/scratch/pablo.viana/aesop/pipeline_v4/dataset_${run_name}"

# Bowtie2 index to remove ercc reads
# bowtie2_ercc_index="/home/work/aesop/czid_bowtie2db_20240626/ercc/ercc"
bowtie2_ercc_index="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/ercc/ercc"

# Bowtie2 index to remove human reads
# bowtie2_human_index="/home/work/aesop/czid_bowtie2db_20240626/human_telomere/human_telomere"
bowtie2_human_index="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/human_telomere/human_telomere"

# Kraken2 database
# kraken2_database="/home/work/aesop/aesop_kraken2db_20240619"
kraken2_database="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"

# Location of src folder in the github directory
# repository_src="/home/work/aesop/github/aesop-metagenomics/src"
repository_src="/home/pablo.viana/metagenomics_src"


################################################################################
############################### LOCAL VARIABLES ################################
################################################################################

# Dataset folder name
dataset_name="aesop_${run_name}"

# Script to execute the tasks
custom_script="$repository_src/0-hpc_job_scripts/execute_custom_script.sh"

# Script to download samples from basespace
download_script="$repository_src/0-hpc_job_scripts/execute_download_script.sh"


################################################################################
################################### DOWNLOAD ###################################
################################################################################

# Basespace file suffix
# Suffix of each sample forward sequence
input_suffix="_L001_R1_001.fastq.gz"

params=("$num_processes"
        "bs"
        "$dataset_name"
        "$input_suffix"
        "$base_path/0-download"
        "$base_path/0-raw_samples"
        "$basespace_project_id")

# $download_script "${params[@]}"


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="_150_reads_R1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/0-raw_samples"
        "$base_dataset_path/1-bowtie_ercc_output"
        "$bowtie2_ercc_index")

# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_host_reads_logs.tar.gz \
#    ${dataset_name}_1-sample_decontamination-bowtie2_remove_ercc_reads_logs.tar.gz


################################################################################
###################################  FASTP  ####################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="_1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/1-quality_control-fastp_filters.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/1-bowtie_ercc_output"
        "$base_dataset_path/1-fastp_output")

# $custom_script "${params[@]}"

# echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
# tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json

# rm -vf *.html *.json


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/1-fastp_output"
        "$base_dataset_path/2-bowtie_human_output"
        "$bowtie2_human_index")
        
# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_host_reads_logs.tar.gz \
#    ${dataset_name}_2-sample_decontamination-bowtie2_remove_human_reads_logs.tar.gz


################################################################################
##################################  KRAKEN2  ###################################
################################################################################

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/2-bowtie_human_output"
        "$base_dataset_path/3-kraken_czid_results"
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