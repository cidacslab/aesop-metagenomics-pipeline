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
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v4/dataset_${run_name}"
old_dataset_path="/home/work/aesop/github/aesop_metagenomics_read_length/results/pipeline_mock/mock_metagenomes"
base_dataset_path="/home/work/aesop/results_pipeline_v8/dataset_${run_name}"
# base_dataset_path="/scratch/pablo.viana/aesop/pipeline_v8/dataset_${run_name}"

# Bowtie2 index to remove phix reads
bowtie2_phix_index="/dev/shm/databases/bowtie2_db/phix_viralproj14015/phix174_index"
# bowtie2_phix_index="/scratch/pablo.viana/databases/bowtie2_db/phix_viralproj14015/phix174_index"
# bowtie2_phix_index="/scratch/pablo.viana/databases/bowtie2_db/phix_viralproj14015/phix174_index"

# Bowtie2 index to remove ercc reads
bowtie2_ercc_index="/dev/shm/databases/bowtie2_db/ercc92/ercc_index"
# bowtie2_ercc_index="/scratch/pablo.viana/databases/bowtie2_db/czid_20240626/ercc/ercc"
# bowtie2_ercc_index="/scratch/pablo.viana/databases/bowtie2_db/ercc92/ercc_index"

# Bowtie2 index to remove human reads
bowtie2_human_index="/dev/shm/databases/bowtie2_db/human_index_20240725/human_full"
# bowtie2_human_index="/scratch/pablo.viana/databases/bowtie2_db/czid_20240626/human_telomere/human_telomere"
# bowtie2_human_index="/scratch/pablo.viana/databases/bowtie2_db/human_index_20240725/human_full"

# Bowtie2 index to remove human reads
hisat2_human_index="/dev/shm/databases/hisat2_db/human_index_20240725/human_full_hisat2"
# hisat2_human_index="/scratch/pablo.viana/databases/hisat2_db/human_index_20240725/human_full_hisat2"

# Kraken2 database
kraken2_database="/dev/shm/databases/k2_pluspfp_20240605"
# kraken2_database="/scratch/pablo.viana/databases/kraken2_db/aesop_kraken2db_20240619"

# Location of src folder in the github directory
repository_src="/home/work/aesop/github/aesop-metagenomics/src"
# repository_src="/home/pablo.viana/metagenomics_src"


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
        "/scratch/pablo.viana/softwares/basespace_illumina/bs"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/0-download"
        "$base_dataset_path/0-raw_samples"
        "$basespace_project_id")

# $download_script "${params[@]}"

################################################################################
##################################  BOWTIE2  ###################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="_R1.fastq"
# rm -rvf "$base_dataset_path/1-bowtie_phix_output"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove.sh"
        "$dataset_name"
        "$input_suffix"
        "$old_dataset_path"
        "$base_dataset_path/1-bowtie_phix_output"
        "$bowtie2_phix_index")

# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_logs.tar.gz \
#   ${dataset_name}_1-sample_decontamination-bowtie2_remove_phix_reads_logs.tar.gz


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

# Suffix of each sample forward sequence
# input_suffix="_1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/1-bowtie_phix_output"
        "$base_dataset_path/1-bowtie_ercc_output"
        "$bowtie2_ercc_index")

# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_logs.tar.gz \
#   ${dataset_name}_1-sample_decontamination-bowtie2_remove_ercc_reads_logs.tar.gz


################################################################################
###################################  FASTP  ####################################
################################################################################

# Suffix of each sample forward sequence
# input_suffix="_1.fastq"
input_suffix="_R1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/1-quality_control-fastp_filters.sh"
        "$dataset_name"
        "$input_suffix"
        "$old_dataset_path"
        "$base_dataset_path/1-fastp_output")

# $custom_script "${params[@]}"

# echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
# tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json

# rm -vf *.html *.json

################################################################################
###################################  HISAT2  ###################################
################################################################################

# Suffix of each sample forward sequence
input_suffix="_1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-hisat2_remove.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/1-fastp_output"
        "$base_dataset_path/2-hisat_human_output"
        "$hisat2_human_index")
        
# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-hisat2_remove_logs.tar.gz \
#   ${dataset_name}_2-sample_decontamination-hisat2_remove_human_reads_logs.tar.gz
  

# ################################################################################
# ##################################  BOWTIE2  ###################################
# ################################################################################

# Suffix of each sample forward sequence
input_suffix="_1.fastq"

params=("$num_processes"
        "$repository_src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/2-hisat_human_output"
        "$base_dataset_path/2-bowtie_human_output"
        "$bowtie2_human_index")
        
# $custom_script "${params[@]}"

# mv ${dataset_name}_2-sample_decontamination-bowtie2_remove_logs.tar.gz \
#   ${dataset_name}_2-sample_decontamination-bowtie2_remove_human_reads_logs.tar.gz
  
  

# ################################################################################
# ##################################  KRAKEN2  ###################################
# ################################################################################
num_processes=1
confidences=("0")
# confidences=("0" "0.1" "0.2" "0.3" "0.4" "0.5" "0.6" "0.7")

for value in "${confidences[@]}"; do
    # rm -rv "$base_dataset_path/3-kraken_results"
    
    params=("$num_processes"
            "$repository_src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
            "$dataset_name"
            "$input_suffix"
            "$base_dataset_path/2-bowtie_human_output"
            "$base_dataset_path/3-taxonomic_output"
            "$kraken2_database"
            $value)
    
    $custom_script "${params[@]}"
    
    # mv ${dataset_name}_3-taxonomic_annotation-kraken2_logs.tar.gz \
    #   ${dataset_name}_3-taxonomic_annotation-kraken2_conf_${value}_logs.tar.gz
done


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