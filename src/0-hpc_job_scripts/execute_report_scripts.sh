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
# old_dataset_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v2/dataset_${run_name}"
# base_dataset_path="/home/work/aesop/results_pipeline_v4/dataset_${run_name}"
base_dataset_path="/scratch/pablo.viana/aesop/pipeline_v4/dataset_${run_name}"

# Kraken2 database
# kraken2_database="/home/work/aesop/aesop_kraken2db_20240619"
kraken2_database="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"

# Location of src folder in the github directory
# repository_src="/home/work/aesop/github/aesop-metagenomics/src"
repository_src="/home/pablo.viana/metagenomics_src"

# Location to place the final output in tar.gz
# final_output_path="$base_dataset_path"
final_output_path="/opt/storage/raw/aesop/metagenomica/biome/pipeline_v4_mock"


################################################################################
################################################################################

dataset_name="aesop_${run_name}"

# Script to execute the tasks
custom_script="$repository_src/0-hpc_job_scripts/execute_custom_script.sh"


################################################################################
##################################  BRACKEN  ###################################
################################################################################

input_suffix=".kreport"

declare -A kraken_folders
# kraken_folders["3-kraken_results"]="4-bracken_results"
kraken_folders["3-kraken_czid_results"]="4-bracken_czid_results"

for input_folder in "${!kraken_folders[@]}"; do
    output_folder=${kraken_folders[$input_folder]}

    params=("$num_processes"
            "$repository_src/1-analysis_pipeline/3-taxonomic_annotation-bracken.sh"
            "$dataset_name"
            "$input_suffix"
            "$base_dataset_path/$input_folder"
            "$base_dataset_path/$output_folder"
            "$kraken2_database"
            "130")

    $custom_script "${params[@]}"

    mv ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz \
       ${dataset_name}_3-taxonomic_annotation-bracken_czid_logs.tar.gz
done


################################################################################
###############################  NORMALIZATION  ################################
################################################################################

declare -A folders
# folders["3-kraken_results"]="5-kraken_reports"
folders["3-kraken_czid_results"]="5-kraken_czid_reports"
# folders["4-bracken_results"]="6-bracken_reports"
folders["4-bracken_czid_results"]="6-bracken_czid_reports"

folders_str=""
# clean the output folder for the new execution
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    folders_str+=" $input_folder $output_folder"
    rm -rvf "${base_dataset_path}/${output_folder}"
done

input_extension="_1.fastq"
input_folder="1-bowtie_ercc_output"
task_script="$repository_src/2-report_taxon_abundances/normalize_abundance_by_species.py"

# Execute normalization code
python $task_script "$base_dataset_path" "$input_extension" "$input_folder" "$folders_str"

# send output o the storage
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    
    mkdir -p "${final_output_path}/${input_folder}"
    mkdir -p "${final_output_path}/${output_folder}"

    cd "${base_dataset_path}/${input_folder}" && \
       find . \( -name '*.kreport' -or -name '*.bracken' \) -print0 | \
       xargs -0 tar -czvf "${final_output_path}/${input_folder}/dataset_${run_name}.tar.gz"
    cd "${base_dataset_path}/${output_folder}" && \
       tar -czvf "${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz" "*.csv"
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