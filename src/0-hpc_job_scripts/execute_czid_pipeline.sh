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
custom_script="/home/pablo.viana/metagenomics_src/0-hpc_job_scripts/execute_custom_script.sh"

################################################################################
############################### ATTENTION !!!!! ################################
################################################################################
################### FOR EACH ANALYSIS FILL THESE INFORMATION ###################
################################################################################

#number of parallel processes
num_processes=$1
# name of the run folder
run_name=$2
# Basespace project ID
basespace_project_id=$3

# run_name="rs01"
dataset_name="aesop_${run_name}"
# old_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# /scratch/pablo.viana/aesop/dataset_manaus01/0-raw_samples/
# old_path="/scratch/pablo.viana/aesop/pipeline_v2/dataset_${run_name}"
base_path="/scratch/pablo.viana/aesop/pipeline_v4/dataset_${run_name}"

################################################################################
##################################  BOWTIE2  ###################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="*_1.fastq"

# # Remove ercc reads
# bowtie2_ercc_index="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/ercc/ercc"

# params=("$num_processes"
#         "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_path/1-fastp_output"
#         "$base_path/2-bowtie_ercc_output"
#         "$bowtie2_ercc_index")

# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_host_reads_logs.tar.gz ${dataset_name}_2-sample_decontamination-bowtie2_remove_ercc_reads_logs.tar.gz

# # Remove human reads
# bowtie2_human_index="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/human_telomere/human_telomere"

# params=("$num_processes"
#         "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_path/2-bowtie_ercc_output"
#         "$base_path/2-bowtie_human_output"
#         "$bowtie2_human_index")
        
# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_host_reads_logs.tar.gz ${dataset_name}_2-sample_decontamination-bowtie2_remove_human_reads_logs.tar.gz



################################################################################
##################################  KRAKEN2  ###################################
################################################################################

kraken2_database="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"

params=("$num_processes"
        "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_path/2-bowtie_output"
        "$base_path/3-kraken_results"
        "$kraken2_database")

$custom_script "${params[@]}"

params=("$num_processes"
        "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_path/2-bowtie_human_output"
        "$base_path/3-kraken_czid_results"
        "$kraken2_database")

$custom_script "${params[@]}"

################################################################################
################################################################################

echo ""
df
du -hd 4 /scratch/pablo.viana
find /scratch/pablo.viana 


#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"