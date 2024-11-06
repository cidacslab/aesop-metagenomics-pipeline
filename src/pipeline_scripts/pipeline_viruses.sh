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

# Arguments string received
args_str=$1
# Dataset to be run
dataset=$2
# Basespace project ID
basespace_project_id=$3

# Convert the argument string back to a dictionary
declare -A args_dict
# Use IFS to split by | and read each key-value pair
IFS='|' read -ra pairs <<< "$args_str"
# Loop through the key-value pairs
for pair in "${pairs[@]}"; do
  IFS='=' read -r key value <<< "$pair"
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


################################################################################
#############################  EXPORT EXECUTABLES  #############################
################################################################################

# Array of executable names
executables=( "HISAT2_EXECUTABLE" "BOWTIE2_EXECUTABLE" \
  "BOWTIE2_BUILD_EXECUTABLE" "SAMTOOLS_EXECUTABLE" "BASESPACE_CLI_EXECUTABLE" \
  "FASTP_EXECUTABLE" "EXTRACT_READS_EXECUTABLE" \
  "KRAKEN2_EXECUTABLE" "BRACKEN_EXECUTABLE" "BLASTN_EXECUTABLE" \
  "SPADES_EXECUTABLE" "MEGAHIT_EXECUTABLE" "QUAST_EXECUTABLE" )

# Loop through each executable exporting to child scripts
for executable in "${executables[@]}"; do
  if [[ -v args_dict["$executable"] ]]; then
    export $executable=${args_dict["$executable"]}
    # Try different options to get the version
    # command=${args_dict["$executable"]}
    # if version=$($command -v 2>/dev/null); then
    #     echo "$command version: $version"
    # elif version=$($command -version 2>/dev/null); then
    #     echo "$command version: $version"
    # elif version=$($command --version 2>/dev/null); then
    #     echo "$command version: $version"
    # else
    #     echo "Unable to determine version for $command"
    # fi

  fi
done

################################################################################
###########################  PIPELINE STEP FUNCTION  ###########################
################################################################################
# Global variable to track if the step was executed successfully
step_executed=0  # Default is 0 (Step was not executed)

# Function to execute each step
run_pipeline_step() {
  local step_name=$1
  local script_path=$2
  shift 2 # Shift past the first two arguments (step_name, script_path)

  # Global variable to track if the step was executed successfully
  step_executed=0  # Default is 0 (Step was not executed)

  # Check if the step should be executed
  if [[ -v args_dict["execute_${step_name}"] && ${args_dict["execute_${step_name}"]} -eq 1 ]]; then
    # Create default argument list
    params=($dataset_name
            ${args_dict["${step_name}_nprocesses"]}
            ${args_dict["${step_name}_delete_preexisting_output_folder"]}
            ${dataset_name}_${args_dict["${step_name}_log_file"]}
            ${args_dict["${step_name}_input_suffix"]}
            ${base_dataset_path}/${args_dict["${step_name}_input_folder"]}
            ${base_dataset_path}/${args_dict["${step_name}_output_folder"]}
            ${args_dict["${step_name}_process_nthreads"]}
            $@) # Add any extra arguments passed to the function
    
    echo ""
    echo "Executing step: $step_name"
    $script_path "${params[@]}"
    step_executed=1  # Step executed successfully
  fi
}

################################################################################
##################################  PIPELINE  ##################################
################################################################################
# rm -r ${base_dataset_path}
# cp -vr /opt/storage/shared/aesop/metagenomica/biome/dataset_mock_viral/ ${base_dataset_path}

## DOWNLOAD 
run_pipeline_step "download" \
  "$repository_src/pipeline_steps/0-raw_sample_download_basepace.sh" \
  ${args_dict["download_basespace_access_token"]} \
  $basespace_project_id


## BOWTIE2 PHIX
run_pipeline_step "bowtie2_phix" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  ${args_dict["bowtie2_phix_index"]}


## BOWTIE2 ERCC
run_pipeline_step "bowtie2_ercc" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  ${args_dict["bowtie2_ercc_index"]}


## FASTP
run_pipeline_step "fastp" \
  "$custom_script $repository_src/pipeline_steps/1-quality_control-fastp_filters.sh" \
  ${args_dict["fastp_minimum_length"]} \
  ${args_dict["fastp_max_n_count"]}
  
if [ $step_executed -eq 1 ]; then  
  # compress the reports
  echo "Tar gziping report files: tar -czf ${dataset_name}_fastp_filters_reports.tar.gz *.html *.json"
  tar -czf "${dataset_name}_fastp_filters_reports.tar.gz" *.html *.json
  # delete the reports
  echo "rm -vf *.html *.json"
  rm -vf *.html *.json
fi


## HISAT2 HUMAN
run_pipeline_step "hisat2_human" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-hisat2_remove.sh" \
  ${args_dict["hisat2_human_index"]}


## BOWTIE2 HUMAN
run_pipeline_step "bowtie2_human" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  ${args_dict["bowtie2_human_index"]}


## KRAKEN2
run_pipeline_step "kraken2" \
  "$custom_script $repository_src/pipeline_steps/3-taxonomic_annotation-kraken2.sh" \
  ${args_dict["kraken2_database"]} \
  ${args_dict["kraken2_confidence"]} \
  ${args_dict["kraken2_keep_output"]} 


##  EXTRACT READS 
run_pipeline_step "extract_reads" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-extract_reads.sh" \
  $base_dataset_path/${args_dict["extract_reads_kraken_output"]} \
  "0 10239"


##  ASSEMBLY MEGAHIT
# run_pipeline_step "assembly_megahit" \
#   "$custom_script $repository_src/pipeline_steps/4-viral_discovery-assembly_megahit.sh"


##  ASSEMBLY METASPADES
run_pipeline_step "assembly_metaspades" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-assembly_metaspades.sh"

run_pipeline_step "mapping_metaspades" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-contig_mapping.sh" \
  ${args_dict["mapping_metaspades_origin_input_suffix"]} \
  $base_dataset_path/${args_dict["mapping_metaspades_origin_input_folder"]}

rm -rvf ${args_dict["final_output_path"]}/$dataset_name
mkdir -p ${args_dict["final_output_path"]}/$dataset_name
cp -rvf $base_dataset_path/${args_dict["mapping_metaspades_output_folder"]} \
  ${args_dict["final_output_path"]}/$dataset_name


## BLASTN ON CONTIGS
run_pipeline_step "blastn" \
  "$custom_script $repository_src/pipeline_steps/3-taxonomic_annotation-blastn.sh" \
  ${args_dict["blastn_viral_index"]}


################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"