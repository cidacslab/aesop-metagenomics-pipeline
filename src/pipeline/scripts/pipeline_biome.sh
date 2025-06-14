#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2025/05/23

Template script used to define a pipeline run over a sample dataset.

params $1 - Argument string comprising the complete list of arguments
params $2 - Dataset name
params $3 - Dataset basespace project id (OPTIONAL)

First define the Software Executables to be used by the steps scripts.
The Input Args section creates the parameters dictionary and exports the 
executables to be used by the child processes. 
The pipeline section must define each step to be executed by the pipeline.
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
echo "Started running pipeline script!"


################################################################################
######################  SET EXECUTABLES FOR THIS PIPELINE  #####################
################################################################################

# Array of executable names
executables=("FASTP_EXECUTABLE" "BOWTIE2_EXECUTABLE" "SAMTOOLS_EXECUTABLE" 
  "KRAKEN2_EXECUTABLE" "PRODIGAL_EXECUTABLE" "HMMER_EXECUTABLE")

################################################################################
################################## INPUT ARGS ##################################
################################################################################

# Arguments string received
args_str=$1
# Dataset to be run
dataset=$2
# Basespace project ID
basespace_project_id=$3

# Create the argument dictionary
declare -A args_dict

# Convert the argument string back to a dictionary
# Pass the name of the dictionary and the key-value pairs to add/update
set_values_in_dict "args_dict" "$args_str"

# Dataset name
dataset_name="dataset_${dataset}"
# Location of src folder in the github directory
repository_src=${args_dict["repository_src"]}
# Location of the dataset data
base_dataset_path=${args_dict["base_dataset_path"]}/${dataset_name}
# Script to execute the tasks
custom_script="$repository_src/${args_dict[custom_task_script]}"

# Loop through each executable exporting to child scripts
for executable in "${executables[@]}"; do
  if [[ -v args_dict["$executable"] ]]; then
    export $executable="${args_dict[$executable]}"
  fi
done

################################################################################
##################################  PIPELINE  ##################################
################################################################################

## FASTP
run_pipeline_step "fastp" "dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/1-quality_control-fastp_filters.sh" \
  "${args_dict[fastp_minimum_quality]}" \
  "${args_dict[fastp_minimum_length]}" \
  "${args_dict[fastp_max_n_count]}"

if [ $STEP_EXECUTED -eq 1 ]; then  
  # compress the reports
  echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
  tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json
  # delete the reports
  echo "rm -vf *.html *.json"
  rm -vf *.html *.json
fi


## BOWTIE2 HUMAN
run_pipeline_step "bowtie2_human" "dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_human_index]}"


## KRAKEN2
run_pipeline_step "kraken2" "dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/3-taxonomic_annotation-kraken2.sh" \
  "${args_dict[kraken2_database]}" \
  "${args_dict[kraken2_confidence]}" \
  "${args_dict[kraken2_keep_output]}"


## PRODIGAL
run_pipeline_step "prodigal" "dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/6-functional_annotation-prodigal.sh"


## HMMER
run_pipeline_step "hmmer" "dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/6-functional_annotation-hmmer.sh" \
  "${args_dict[hmmer_profile]}"


################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished pipeline for ${dataset_name}!"
