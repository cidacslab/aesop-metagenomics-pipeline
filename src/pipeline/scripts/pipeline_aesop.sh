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
######################  SET EXECUTABLES FOR THIS PIPELINE  #####################
################################################################################

# Array of executable names
executables=("BASESPACE_CLI_EXECUTABLE" "FASTP_EXECUTABLE" "HISAT2_EXECUTABLE" \
  "BOWTIE2_EXECUTABLE" "SAMTOOLS_EXECUTABLE" "KRAKEN2_EXECUTABLE" \
  "BRACKEN_EXECUTABLE")

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

## DOWNLOAD 
run_pipeline_step "download" "$dataset_name" "$base_dataset_path" \
  "$repository_src/pipeline/steps/0-raw_sample_basespace_download.sh" \
  "$(cat $repository_src/${args_dict[download_basespace_access_token]})" \
  "${args_dict[download_basespace_api_server]}" \
  $basespace_project_id


## BOWTIE2 PHIX
run_pipeline_step "bowtie2_phix" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_phix_index]}"


## BOWTIE2 ERCC
run_pipeline_step "bowtie2_ercc" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_ercc_index]}"


## FASTP
run_pipeline_step "fastp" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/1-quality_control-fastp_filters.sh" \
  "${args_dict[fastp_cut_window_size]}" \
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


## HISAT2 HUMAN
run_pipeline_step "hisat2_human" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/2-sample_decontamination-hisat2_remove.sh" \
  "${args_dict[hisat2_human_index]}"


## BOWTIE2 HUMAN
run_pipeline_step "bowtie2_human" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_human_index]}"


## KRAKEN2
run_pipeline_step "kraken2" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/3-taxonomic_annotation-kraken2.sh" \
  "${args_dict[kraken2_database]}" \
  "${args_dict[kraken2_confidence]}" \
  "${args_dict[kraken2_keep_output]}"


## BRACKEN
run_pipeline_step "bracken" "$dataset_name" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline/steps/3-taxonomic_annotation-bracken.sh" \
  "${args_dict[bracken_database]}" \
  "${args_dict[bracken_read_length]}" \
  "${args_dict[bracken_threshold]}"


# ## NORMALIZATION
# run_pipeline_step "normalization" "$dataset_name" "$base_dataset_path" \
#   "python $repository_src/report_results/normalize_abundance_by_species.py" \
#   "${base_dataset_path}" \
#   "${args_dict[normalization_folders]}"


################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished pipeline for ${dataset_name}!"
