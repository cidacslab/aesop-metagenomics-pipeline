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

# Name of the run folder
# run_name="rs01"
# old_dataset_path="/scratch/pablo.viana/aesop/dataset_manaus01"
# old_dataset_path="/scratch/pablo.viana/aesop/pipeline_v4/dataset_${run_name}"
old_dataset_path="/home/work/aesop/github/aesop_metagenomics_read_length/results/pipeline_mock/mock_metagenomes"
base_dataset_path="/home/work/aesop/results_pipeline_v8/dataset_${run_name}"
# base_dataset_path="/scratch/pablo.viana/aesop/pipeline_v8/dataset_${run_name}"

# Kraken2 database
kraken2_database="/dev/shm/databases/k2_pluspfp_20240605"
# kraken2_database="/scratch/pablo.viana/databases/kraken2_db/aesop_kraken2db_20240619"

# Location of src folder in the github directory
repository_src="/home/work/aesop/github/aesop-metagenomics/src"
# repository_src="/home/pablo.viana/metagenomics_src"

# Location to place the final output in tar.gz
final_output_path="$base_dataset_path"
# final_output_path="/opt/storage/raw/aesop/metagenomica/biome/pipeline_v7"


################################################################################
################################################################################

dataset_name="aesop_${run_name}"

# Script to execute the tasks
custom_script="$repository_src/0-hpc_job_scripts/execute_custom_script.sh"


################################################################################
##################################  BRACKEN  ###################################
################################################################################

# declare -A input_suffixes=( ["_75_reads.kreport"]="75" ["_150_reads.kreport"]="150" ["_300_reads.kreport"]="300" )

declare -A kraken_folders
# kraken_folders["3-kraken_results"]="3-kraken_results"
kraken_folders["3-taxonomic_output"]="3-taxonomic_output"
# kraken_folders["3.1-kraken_results_2"]="4.1-bracken_results_2"
# kraken_folders["3.1-kraken_czid_results_0"]="4.1-bracken_czid_results_0"
# kraken_folders["3.1-kraken_czid_results_0.1"]="4.1-bracken_czid_results_0.1"
# kraken_folders["3.1-kraken_czid_results_0.2"]="4.1-bracken_czid_results_0.2"
# kraken_folders["3.1-kraken_czid_results_0.3"]="4.1-bracken_czid_results_0.3"
# kraken_folders["3.1-kraken_czid_results_0.4"]="4.1-bracken_czid_results_0.4"
# kraken_folders["3.1-kraken_czid_results_0.5"]="4.1-bracken_czid_results_0.5"
# kraken_folders["3.1-kraken_czid_results_0.6"]="4.1-bracken_czid_results_0.6"
# kraken_folders["3.1-kraken_czid_results_0.7"]="4.1-bracken_czid_results_0.7"

# for input_suffix in "${!input_suffixes[@]}"; do
#     threshold=${input_suffixes[$input_suffix]}
    input_suffix=".kreport"
    threshold=150
    for input_folder in "${!kraken_folders[@]}"; do
        output_folder=${kraken_folders[$input_folder]}
        # rm -rvf "${base_dataset_path}/${output_folder}"
    
        params=("$num_processes"
                "$repository_src/1-analysis_pipeline/3-taxonomic_annotation-bracken.sh"
                "$dataset_name"
                "$input_suffix"
                "$base_dataset_path/$input_folder"
                "$base_dataset_path/$output_folder"
                "$kraken2_database"
                "$threshold")
    
        $custom_script "${params[@]}"
    
        mv ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz \
            ${dataset_name}_3-taxonomic_annotation-bracken_${input_folder}${input_suffix}_logs.tar.gz
    done
# done


################################################################################
###############################  NORMALIZATION  ################################
################################################################################

declare -A folders
folders["3-taxonomic_output"]="4-bracken_normalized"
# folders["4.1-bracken_results_2"]="6-bracken_reports_2"
# folders["3-kraken_results"]="5-kraken_reports"
# folders["4-bracken_results"]="6-bracken_reports"
# folders["4.1-bracken_czid_results_0"]="6.1-bracken_czid_reports_0"
# folders["4.1-bracken_czid_results_0.1"]="6.1-bracken_czid_reports_0.1"
# folders["4.1-bracken_czid_results_0.2"]="6.1-bracken_czid_reports_0.2"
# folders["4.1-bracken_czid_results_0.3"]="6.1-bracken_czid_reports_0.3"
# folders["4.1-bracken_czid_results_0.4"]="6.1-bracken_czid_reports_0.4"
# folders["4.1-bracken_czid_results_0.5"]="6.1-bracken_czid_reports_0.5"
# folders["4.1-bracken_czid_results_0.6"]="6.1-bracken_czid_reports_0.6"
# folders["4.1-bracken_czid_results_0.7"]="6.1-bracken_czid_reports_0.7"

folders_str=""
# clean the output folder for the new execution
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    folders_str+=" $input_folder $output_folder"
    rm -rvf "${base_dataset_path}/${output_folder}"
done

input_extension="_R1.fastq"
input_folder="${old_dataset_path}"
# input_extension="_1.fastq"
# input_folder="${base_dataset_path}/1-bowtie_ercc_output"
# input_extension="_150_reads_R1.fastq"
# input_folder="0-raw_samples"
task_script="$repository_src/2-report_taxon_abundances/normalize_abundance_by_species.py"

# Execute normalization code
python $task_script "$base_dataset_path" $input_extension $input_folder $folders_str

# send output o the storage
for input_folder in "${!folders[@]}"; do
    output_folder=${folders[$input_folder]}
    
    mkdir -p "${final_output_path}/${input_folder}"
    mkdir -p "${final_output_path}/${output_folder}"

    cd "${base_dataset_path}/${input_folder}" && \
      find . \( -name '*.kreport' -or -name '*.bracken' \) -print0 | \
      xargs -0 tar -czvf "${final_output_path}/${input_folder}/dataset_${run_name}.tar.gz"
    cd "${base_dataset_path}/${output_folder}" && \
      find . -name '*.csv' -print0 | \
      xargs -0 tar -czvf "${final_output_path}/${output_folder}/dataset_${run_name}.tar.gz"
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