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

bash --version

# Start job profile
start=$(date +%s.%N)
echo "Started running job for all datasets!"
################################################################################
########################### DEFINE GLOBAL VARIABLES ############################
################################################################################


################################################################################
################# DEFINE THE DATASETS TO EXECUTE THE PIPELINE ##################
################################################################################
# ALL DATASETS AND THEIR BASESPACE PROJECT ID
sample_datasets="
                #  test01:123456789
                mock01:123456789"




################################################################################
################### DEFINE STAGES TO EXECUTE IN THE PIPELINE ###################
################################################################################
# 0 = DONT EXECUTE STAGE | 1 = EXECUTE STAGE
params["execute_download"]=0
params["execute_bowtie2_ercc"]=1
params["execute_fastp"]=1
params["execute_bowtie2_host"]=1
params["execute_kraken2"]=1
params["execute_bracken"]=1
params["execute_normalization"]=1
################################################################################
###################### DEFINE STAGES SPECIFIC PARAMETERS #######################
################################################################################
### Download parameters
params["download_input_suffix"]=".fastq.gz"
params["download_input_path"]="0/download"
### Bowtie2 remove PHIX parameters
### Bowtie2 remove ERCC parameters
# params["bowtie_ercc_input_suffix"]="_L001_R1_001.fastq.gz"
# params["bowtie2_ercc_input_suffix"]="_150_reads_R1.fastq"
### Fastp quality control parameters
# params["fastp_input_suffix"]="_L001_R1_001.fastq.gz"
params["fastp_input_suffix"]="_1.fastq"
### HISAT2 remove HUMAN parameters
### Bowtie2 remove HUMAN parameters
params["bowtie2_host_input_suffix"]="_1.fastq"
### Kraken2 annotation parameters
params["kraken2_input_suffix"]="_1.fastq"
### Bracken annotation parameters
params["bracken_input_suffix"]="_1.fastq"
# params["bracken_folders"]="3-kraken_results:4-bracken_results;"
params["bracken_folders"]="3-kraken_czid_results:4-bracken_czid_results"
params["bracken_read_length"]=130
params["bracken_threshold"]=1
### Normalization parameters
params["normalization_input_suffix"]="_1.fastq"
params["normalization_input_folder"]="1-bowtie_ercc_output"
# params["normalization_folders"]="3-kraken_results:5-kraken_reports;4-bracken_results:6-bracken_reports"
# params["normalization_folders"]+=";3-kraken_czid_results:5-kraken_czid_reports;"
params["normalization_folders"]="4-bracken_czid_results:6-bracken_czid_reports"
################################################################################
################################################################################

# Script to be executed
script_to_execute=$2
# Dictionary with dataset names and their project_id
sample_datasets=$3

# Loop throught all datasets
while IFS= read -r dataset_line; do
    IFS=":" read -r dataset project_id <<< "$dataset_line"
    echo "######################################################"
    echo "######################################################"
    echo "Executing script: $script_to_execute"
    echo "     For dataset: $dataset : $project_id"
    echo "######################################################"
    $script_to_execute $num_processes $dataset $project_id
done <<< "$sample_datasets"


echo ""
df
du -hd 4 /scratch/pablo.viana | sort -k2
find /scratch/pablo.viana | sort


#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline for all datasets!"