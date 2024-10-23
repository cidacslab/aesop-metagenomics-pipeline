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

echo "Executing pipeline for:" 
echo "    dataset: ${dataset} : ${basespace_project_id}"
echo "    args: $args_str"

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

################################################################################
#############################  EXPORT EXECUTABLES  #############################
################################################################################

# Array of executable names
executables=("BASESPACE_CLI_EXECUTABLE" "FASTP_EXECUTABLE" "HISAT2_EXECUTABLE" \
  "BOWTIE2_EXECUTABLE" "SAMTOOLS_EXECUTABLE" "KRAKEN2_EXECUTABLE" \
  "BRACKEN_EXECUTABLE")

# Loop through each executable exporting to child scripts
for executable in "${executables[@]}"; do
  if [[ -v args_dict["$executable"] ]]; then
    export $executable=${args_dict["$executable"]}
  fi
done

################################################################################
################################### DOWNLOAD ###################################
################################################################################

if [ ${args_dict["execute_download"]} -eq 1 ]; then
  params=($dataset_name
          ${args_dict["download_delete_preexisting_output_folder"]}
          ${dataset_name}_0-raw_sample_basepace_download.log
          ${args_dict["download_input_suffix"]}
          $base_dataset_path/${args_dict["download_input_folder"]}
          $base_dataset_path/${args_dict["download_output_folder"]}
          $basespace_project_id
          ${args_dict["download_basespace_access_token"]})

  # $repository_src/pipeline_steps/0-raw_sample_basepace_download.sh "${params[@]}"
fi

rm -rf $base_dataset_path/${args_dict["download_output_folder"]}
mkdir -p $base_dataset_path/${args_dict["download_output_folder"]}

cp /scratch/pablo.viana/aesop/pipeline_v4/dataset_mao01/0-raw_samples/* \
   $base_dataset_path/${args_dict["download_output_folder"]}

################################################################################
##################################  BOWTIE2  ###################################
################################################################################

if [ ${args_dict["execute_bowtie2_phix"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh"
          $dataset_name
          ${args_dict["bowtie2_phix_nprocesses"]}
          ${args_dict["bowtie2_phix_delete_preexisting_output_folder"]}
          "${dataset_name}_1.1-sample_decontamination-bowtie2_remove_phix_reads_logs.tar.gz"
          ${args_dict["bowtie2_phix_input_suffix"]}
          $base_dataset_path/${args_dict["bowtie2_phix_input_folder"]}
          $base_dataset_path/${args_dict["bowtie2_phix_output_folder"]}
          ${args_dict["bowtie2_phix_process_nthreads"]}
          ${args_dict["bowtie2_phix_index"]})

  $custom_script "${params[@]}"      
fi


################################################################################
##################################  BOWTIE2  ###################################
################################################################################

if [ ${args_dict["execute_bowtie2_ercc"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh"
          $dataset_name
          ${args_dict["bowtie2_ercc_nprocesses"]}
          ${args_dict["bowtie2_ercc_delete_preexisting_output_folder"]}
          ${dataset_name}_1.2-sample_decontamination-bowtie2_remove_ercc_reads_logs.tar.gz
          ${args_dict["bowtie2_ercc_input_suffix"]}
          $base_dataset_path/${args_dict["bowtie2_ercc_input_folder"]}
          $base_dataset_path/${args_dict["bowtie2_ercc_output_folder"]}
          ${args_dict["bowtie2_ercc_process_nthreads"]}
          ${args_dict["bowtie2_ercc_index"]})

  $custom_script "${params[@]}"
fi

################################################################################
###################################  FASTP  ####################################
################################################################################

if [ ${args_dict["execute_fastp"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/1-quality_control-fastp_filters.sh"
          $dataset_name
          ${args_dict["fastp_nprocesses"]}
          ${args_dict["fastp_delete_preexisting_output_folder"]}
          ${dataset_name}_1.3-quality_control-fastp_filters_logs.tar.gz
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
  params=("$repository_src/pipeline_steps/2-sample_decontamination-hisat2_remove.sh"
          $dataset_name
          ${args_dict["hisat2_human_nprocesses"]}
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
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh"
          $dataset_name
          ${args_dict["bowtie2_human_nprocesses"]}
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
          ${args_dict["kraken2_nprocesses"]}
          ${args_dict["kraken2_delete_preexisting_output_folder"]}
          ${dataset_name}_3-taxonomic_annotation-kraken_logs.tar.gz
          ${args_dict["kraken2_input_suffix"]}
          $base_dataset_path/${args_dict["kraken2_input_folder"]}
          $base_dataset_path/${args_dict["kraken2_output_folder"]}
          ${args_dict["kraken2_process_nthreads"]}
          ${args_dict["kraken2_database"]}
          ${args_dict["kraken2_confidence"]}
          ${args_dict["kraken2_keep_output"]})

  $custom_script "${params[@]}"
fi

################################################################################
##################################  BRACKEN  ###################################
################################################################################

if [ ${args_dict["execute_bracken"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/3-taxonomic_annotation-bracken.sh"
          $dataset_name
          ${args_dict["bracken_nprocesses"]}
          ${args_dict["bracken_delete_preexisting_output_folder"]}
          ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz
          ${args_dict["bracken_input_suffix"]}
          $base_dataset_path/${args_dict["bracken_input_folder"]}
          $base_dataset_path/${args_dict["bracken_output_folder"]}
          1
          ${args_dict["bracken_database"]}
          ${args_dict["bracken_read_length"]}
          ${args_dict["bracken_threshold"]})

  $custom_script "${params[@]}"
fi

################################################################################
###############################  NORMALIZATION  ################################
################################################################################

if [ ${args_dict["execute_normalization"]} -eq 1 ]; then
    declare -A folders
    folders["3-taxonomic_output"]="4-bracken_normalized"
    # folders["3-kraken_results"]="5-kraken_reports"
    # folders["4-bracken_results"]="6-bracken_reports"
    # folders["4-bracken_czid_results"]="6-bracken_czid_reports"
    # folders_str=${args_dict["normalization_input_suffix"]}
    folders_str=""
    # clean the output folder for the new execution
    for input_folder in "${!folders[@]}"; do
        output_folder=${folders[$input_folder]}
        folders_str+=" $input_folder $output_folder"
        rm -rvf "${base_dataset_path}/${output_folder}"
    done

    input_extension=${args_dict["normalization_input_suffix"]}
    input_path=$base_dataset_path/${args_dict["normalization_input_folder"]}
    task_script="$repository_src/report_results/normalize_abundance_by_species.py"

    # Execute normalization code
    python -u $task_script "$base_dataset_path" "$input_extension" "$input_path" $folders_str
    
    # send output to the final output path
    final_output_path=${args_dict["final_output_path"]}
    for input_folder in "${!folders[@]}"; do
        output_folder=${folders[$input_folder]}
        
        mkdir -p "${final_output_path}/${input_folder}"
        mkdir -p "${final_output_path}/${output_folder}"

        cd "${base_dataset_path}/${input_folder}" && \
           find . \( -name '*.kreport' -or -name '*.bracken' \) -print0 | \
           xargs -0 tar -czvf "${final_output_path}/${input_folder}/dataset_${dataset}.tar.gz"

        cd "${base_dataset_path}/${output_folder}" && \
           tar -czvf "${final_output_path}/${output_folder}/dataset_${dataset}.tar.gz" *.csv
    done
fi

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
