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
basespace_project_id=$3 # NOT USED


################################################################################
############################### ATTENTION !!!!! ################################
################################################################################
################### FOR EACH ANALYSIS FILL THESE INFORMATION ###################
################################################################################

# run_name="rs01"
dataset_name="aesop_${run_name}"

# old_dataset_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v2/dataset_${run_name}"
base_dataset_path="/home/work/aesop/results_pipeline_v4/dataset_${run_name}"

# Kraken2 database
kraken2_database="/home/work/aesop/aesop_kraken2db_20240619"

# Location of src folder in the github directory
repository_src="/home/work/aesop/github/aesop-metagenomics/src"

# Script to execute the tasks
custom_script="$repository_src/0-hpc_job_scripts/execute_custom_script.sh"

# Location to place the final output in tar.gz
final_output_path="$base_dataset_path"


################################################################################
##################################  BRACKEN  ###################################
################################################################################

input_suffix=".kreport"

# params=("$num_processes"
#         "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/3-taxonomic_annotation-bracken.sh"
#         "$dataset_name"
#         "$input_suffix"
#         "$base_dataset_path/3-kraken_results"
#         "$base_dataset_path/4-bracken_results"
#         "$kraken2_database"
#         "130")

# $custom_script "${params[@]}"

# mv ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz ${dataset_name}_3-taxonomic_annotation-bracken_pipeline_logs.tar.gz


################################################################################

params=("$num_processes"
        "/home/pablo.viana/metagenomics_src/1-analysis_pipeline/3-taxonomic_annotation-bracken.sh"
        "$dataset_name"
        "$input_suffix"
        "$base_dataset_path/3-kraken_czid_results"
        "$base_dataset_path/4-bracken_czid_results"
        "$kraken2_database"
        "130")

$custom_script "${params[@]}"

mv ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz ${dataset_name}_3-taxonomic_annotation-bracken_czid_logs.tar.gz


################################################################################
###############################  NORMALIZATION  ################################
################################################################################

declare -A folders
# folders["3-kraken_results"]="5-kraken_reports"
folders["3-kraken_czid_results"]="5-kraken_czid_reports"
# folders["4-bracken_results"]="6-bracken_reports"
folders["4-bracken_czid_results"]="6-bracken_czid_reports"

# clean the output folder for the new execution
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    rm -rvf "${base_dataset_path}/${output_folder}"
    
    mkdir -p "${final_output_path}/${output_folder}"
done

task_script="/home/pablo.viana/metagenomics_src/2-report_taxon_abundances/normalize_abundance_by_species.py"

# Execute normalization code
python $task_script "$base_dataset_path"

# send output o the storage
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    
    # cd "${base_dataset_path}/${kraken_folder}" && tar -czvf "${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz" "*.kreport"
    # tar -czvf "${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz" -C "${base_dataset_path}/${bracken_folder}" .    
    echo "tar -czvf ${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz -C ${base_dataset_path}/${output_folder} ."
    tar -czvf "${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz" -C "${base_dataset_path}/${output_folder}" .
done


################################################################################
################################################################################

# echo ""
# df
# du -hd 4 /scratch/pablo.viana | sort
# find /scratch/pablo.viana | sort

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"