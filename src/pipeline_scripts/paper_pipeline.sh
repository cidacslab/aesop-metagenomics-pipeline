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

# Dataset to be run
dataset=$1
# Basespace project ID
basespace_project_id=$2
# Arguments string received
args_str=$3
# Convert the argument string back to a dictionary
declare -A args_dict
for pair in $args_str; do
    key=${pair%=*}
    value=${pair#*=}
    args_dict[$key]=$value
done

# Dataset name
dataset_name="aesop_${dataset}"
# Location of src folder in the github directory
repository_src=${args_dict["repository_src"]}
# Location of the dataset data
base_dataset_path=${args_dict["base_dataset_path"]}/dataset_${dataset}
# Script to execute the tasks
custom_script="$repository_src/pipeline_scripts/custom_task.sh"

if [[ -v args_dict["FASTP_EXECUTABLE"] ]]; then
  export FASTP_EXECUTABLE=$args_dict["FASTP_EXECUTABLE"]
fi
if [[ -v args_dict["HISAT2_EXECUTABLE"] ]]; then
  export HISAT2_EXECUTABLE=$args_dict["HISAT2_EXECUTABLE"]
fi
if [[ -v args_dict["BOWTIE2_EXECUTABLE"] ]]; then
  export BOWTIE2_EXECUTABLE=$args_dict["BOWTIE2_EXECUTABLE"]
fi
if [[ -v args_dict["SAMTOOLS_EXECUTABLE"] ]]; then
  export SAMTOOLS_EXECUTABLE=$args_dict["SAMTOOLS_EXECUTABLE"]
fi
if [[ -v args_dict["KRAKEN2_EXECUTABLE"] ]]; then
  export KRAKEN2_EXECUTABLE=$args_dict["KRAKEN2_EXECUTABLE"]
fi
if [[ -v args_dict["BRACKEN_EXECUTABLE"] ]]; then
  export BRACKEN_EXECUTABLE=$args_dict["BRACKEN_EXECUTABLE"]
fi

################################################################################
###################################  FASTP  ####################################
################################################################################

if [ ${args_dict["execute_fastp"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/1-quality_control-fastp_filters.sh"
          $dataset_name
          ${args_dict["fastp_nprocess"]}
          ${args_dict["fastp_delete_preexisting_output_folder"]}
          ${dataset_name}_1-quality_control-fastp_filters_logs.tar.gz
          ${args_dict["fastp_input_suffix"]}
          $base_dataset_path/${args_dict["fastp_input_folder"]}
          $base_dataset_path/${args_dict["fastp_output_folder"]}
          ${args_dict["fastp_process_nthreads"]}
          ${args_dict["fastp_minimum_length"]}
          ${args_dict["fastp_max_n_count"]})

  $custom_script "${params[@]}"

  echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
  tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json

  rm -vf *.html *.json
fi

################################################################################
###################################  HISAT2  ###################################
################################################################################

if [ ${args_dict["execute_hisat2_human"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/2-sample_decontamination-hisat2_remove_host_reads.sh"
          $dataset_name
          ${args_dict["hisat2_human_nprocess"]}
          ${args_dict["hisat2_human_delete_preexisting_output_folder"]}
          ${dataset_name}_2.1-sample_decontamination-hisat2_remove_human_reads_logs.tar.gz
          ${args_dict["hisat2_human_input_suffix"]}
          $base_dataset_path/${args_dict["hisat2_human_input_folder"]}
          $base_dataset_path/${args_dict["hisat2_human_output_folder"]}
          ${args_dict["hisat2_human_process_nthreads"]}
          ${args_dict["hisat2_human_index"]})

  $custom_script "${params[@]}"
fi

################################################################################
##################################  BOWTIE2  ###################################
################################################################################

if [ ${args_dict["execute_bowtie2_human"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove_host_reads.sh"
          $dataset_name
          ${args_dict["bowtie2_human_nprocess"]}
          ${args_dict["bowtie2_human_delete_preexisting_output_folder"]}
          ${dataset_name}_2.2-sample_decontamination-bowtie2_remove_human_reads_logs.tar.gz
          ${args_dict["bowtie2_human_input_suffix"]}
          $base_dataset_path/${args_dict["bowtie2_human_input_folder"]}
          $base_dataset_path/${args_dict["bowtie2_human_output_folder"]}
          ${args_dict["bowtie2_human_process_nthreads"]}
          ${args_dict["bowtie2_human_index"]})

  $custom_script "${params[@]}"
fi

################################################################################
##################################  KRAKEN2  ###################################
################################################################################

if [ ${args_dict["execute_kraken2"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/3-taxonomic_annotation-kraken2.sh"
          $dataset_name
          ${args_dict["kraken2_nprocess"]}
          ${args_dict["kraken2_delete_preexisting_output_folder"]}
          ${dataset_name}_3.1-taxonomic_annotation-kraken_logs.tar.gz
          ${args_dict["kraken2_input_suffix"]}
          $base_dataset_path/${args_dict["kraken2_input_folder"]}
          $base_dataset_path/${args_dict["kraken2_output_folder"]}
          ${args_dict["kraken2_process_nthreads"]}
          ${args_dict["kraken2_database"]}
          ${args_dict["kraken2_confidence"]})

  $custom_script "${params[@]}"
fi

################################################################################
##################################  BRACKEN  ###################################
################################################################################

if [ ${args_dict["execute_bracken"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/3-taxonomic_annotation-bracken.sh"
          $dataset_name
          ${args_dict["bracken_nprocess"]}
          ${args_dict["bracken_delete_preexisting_output_folder"]}
          ${dataset_name}_3.2-taxonomic_annotation-bracken_logs.tar.gz
          ${args_dict["bracken_input_suffix"]}
          $base_dataset_path/${args_dict["bracken_input_folder"]}
          $base_dataset_path/${args_dict["bracken_output_folder"]}
          1
          ${args_dict["kraken2_database"]}
          ${args_dict["bracken_read_length"]}
          ${args_dict["bracken_threshold"]})

  $custom_script "${params[@]}"
fi

################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"