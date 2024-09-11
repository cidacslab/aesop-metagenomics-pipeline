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

# Export global variables with software locations
if [[ -v args_dict["download_basespace_access_token"] ]]; then
  export BASESPACE_API_SERVER="https://api.basespace.illumina.com"
  export BASESPACE_ACCESS_TOKEN=$args_dict["download_basespace_access_token"]
fi
if [[ -v args_dict["BASESPACE_CLI_EXECUTABLE"] ]]; then
  export BASESPACE_CLI_EXECUTABLE=$args_dict["BASESPACE_CLI_EXECUTABLE"]
fi
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
if [[ -v args_dict["BLASTN_EXECUTABLE"] ]]; then
  export BLASTN_EXECUTABLE=$args_dict["BLASTN_EXECUTABLE"]
fi
if [[ -v args_dict["DIAMOND_EXECUTABLE"] ]]; then
  export DIAMOND_EXECUTABLE=$args_dict["DIAMOND_EXECUTABLE"]
fi

################################################################################
################################### DOWNLOAD ###################################
################################################################################

if [ ${args_dict["execute_download"]} -eq 1 ]; then
  params=($dataset_name
          ${args_dict["download_delete_preexisting_output_folder"]}
          ${dataset_name}_0-raw_sample_basepace_download_logs.tar.gz
          ${args_dict["download_input_suffix"]}
          $base_dataset_path/${args_dict["download_input_folder"]}
          $base_dataset_path/${args_dict["download_output_folder"]}
          $basespace_project_id)

  $download_script="$repository_src/pipeline_steps/0-raw_sample_basepace_download.sh"
  $download_script "${params[@]}"
fi

################################################################################
##################################  BOWTIE2  ###################################
################################################################################

if [ ${args_dict["execute_bowtie2_phix"]} -eq 1 ]; then
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove_host_reads.sh"
          $dataset_name
          ${args_dict["bowtie2_phix_nprocess"]}
          ${args_dict["bowtie2_phix_delete_preexisting_output_folder"]}
          ${dataset_name}_1.1-sample_decontamination-bowtie2_remove_phix_reads_logs.tar.gz
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
  params=("$repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove_host_reads.sh"
          $dataset_name
          ${args_dict["bowtie2_ercc_nprocess"]}
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
          ${args_dict["fastp_nprocess"]}
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
          ${dataset_name}_3-taxonomic_annotation-kraken_logs.tar.gz
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
          ${dataset_name}_3-taxonomic_annotation-bracken_logs.tar.gz
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
###############################  NORMALIZATION  ################################
################################################################################

if [ ${args_dict["execute_normalization"]} -eq 1 ]; then
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

    input_extension=${args_dict["normalization_input_suffix"]}
    input_folder=${args_dict["normalization_input_folder"]}
    task_script="$repository_src/2-report_taxon_abundances/normalize_abundance_by_species.py"

    # Execute normalization code
    python $task_script "$base_dataset_path" "$input_extension" "$input_folder" "$folders_str"
    
    # send output to the final output path
    final_output_path=${args_dict["final_output_path"]}
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