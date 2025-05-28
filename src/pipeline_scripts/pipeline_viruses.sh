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
executables=( "HISAT2_EXECUTABLE" "BOWTIE2_EXECUTABLE" "SAMTOOLS_EXECUTABLE" \
  "FASTP_EXECUTABLE" "KRAKEN2_EXECUTABLE" "EXTRACT_READS_EXECUTABLE" \
  "SPADES_EXECUTABLE" "BOWTIE2_BUILD_EXECUTABLE" "BLASTN_EXECUTABLE" \
  "DIAMOND_EXECUTABLE" )

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
custom_script="$repository_src/pipeline_scripts/custom_task.sh"

# Loop through each executable exporting to child scripts
for executable in "${executables[@]}"; do
  if [[ -v args_dict["$executable"] ]]; then
    export $executable="${args_dict[$executable]}"
  fi
done

################################################################################
##################################  PIPELINE  ##################################
################################################################################

## BOWTIE2 PHIX
run_pipeline_step "bowtie2_phix" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_phix_index]}"


## BOWTIE2 ERCC
run_pipeline_step "bowtie2_ercc" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_ercc_index]}"


## FASTP
run_pipeline_step "fastp" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/1-quality_control-fastp_filters.sh" \
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
run_pipeline_step "hisat2_human" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-hisat2_remove.sh" \
  "${args_dict[hisat2_human_index]}"


## BOWTIE2 HUMAN
run_pipeline_step "bowtie2_human" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/2-sample_decontamination-bowtie2_remove.sh" \
  "${args_dict[bowtie2_human_index]}"


## KRAKEN2
run_pipeline_step "kraken2" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/3-taxonomic_annotation-kraken2.sh" \
  "${args_dict[kraken2_database]}" \
  "${args_dict[kraken2_confidence]}" \
  "${args_dict[kraken2_keep_output]}"
  

##  EXTRACT READS 
run_pipeline_step "extract_reads" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-extract_reads.sh" \
  "$base_dataset_path/${args_dict[extract_reads_kraken_output]}" \
  "${args_dict[extract_reads_filter_taxons]}"


##  ASSEMBLY METASPADES
run_pipeline_step "assembly_metaspades" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-assembly_metaspades.sh"


##  MAPPING METASPADES
run_pipeline_step "mapping_metaspades" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/4-viral_discovery-contig_mapping.sh" \
  "${args_dict[mapping_metaspades_origin_input_suffix]}" \
  "$base_dataset_path/${args_dict[mapping_metaspades_origin_input_folder]}"


## BLASTN ON CONTIGS
run_pipeline_step "blastn" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/3-taxonomic_annotation-blastn.sh" \
  "${args_dict[blastn_database]}" \
  "${args_dict[blastn_task]}" \
  "${args_dict[taxonomy_database]}/taxids_by_taxons/${args_dict[blastn_filter_taxon]}" 


## CALCULATE CONFUSION MATRIX
run_pipeline_step "tabulate_blastn" "$base_dataset_path" \
  "$custom_script python $repository_src/pipeline_steps/5-tabulate_known_viruses.py" \
  "${args_dict[tabulate_blastn_align_coverage]}" \
  "${args_dict[tabulate_blastn_align_identity]}" \
  "${args_dict[tabulate_blastn_align_length]}" \
  "${args_dict[tabulate_blastn_align_evalue]}" \
  "${args_dict[taxonomy_database]}" \
  "$base_dataset_path" \
  "$repository_src/../${args_dict[tabulate_blastn_metadata_path]}" \
  "${args_dict[tabulate_blastn_count_reads_folder]}" \
  "${args_dict[tabulate_blastn_count_reads_extension]}" \
  "${args_dict[tabulate_blastn_mapping_folder]}" \
  "${args_dict[tabulate_blastn_kraken_folder]}"


## FILTER CONTIGS NOT CLASSIFIED
run_pipeline_step "filter_contigs_blastn" "$base_dataset_path" \
  "$custom_script python $repository_src/pipeline_steps/5-filter_fasta_by_accessions.py" \
  "$base_dataset_path/${args_dict[filter_contigs_blastn_contigs_folder]}" \
  "${args_dict[filter_contigs_blastn_contigs_extension]}"


## DIAMOND ON CONTIGS
run_pipeline_step "diamond" "$base_dataset_path" \
  "$custom_script $repository_src/pipeline_steps/3-taxonomic_annotation-diamond.sh" \
  "${args_dict[diamond_database]}" \
  "${args_dict[diamond_sensitivity]}" \
  "${args_dict[diamond_filter_taxon]}"


## CALCULATE CONFUSION MATRIX
run_pipeline_step "tabulate_diamond_fast" "$base_dataset_path" \
  "$custom_script python $repository_src/pipeline_steps/5-tabulate_known_viruses.py" \
  "${args_dict[tabulate_diamond_fast_align_coverage]}" \
  "${args_dict[tabulate_diamond_fast_align_identity]}" \
  "${args_dict[tabulate_diamond_fast_align_length]}" \
  "${args_dict[tabulate_diamond_fast_align_evalue]}" \
  "${args_dict[taxonomy_database]}" \
  "$base_dataset_path" \
  "$repository_src/../${args_dict[tabulate_diamond_fast_metadata_path]}" \
  "${args_dict[tabulate_diamond_fast_count_reads_folder]}" \
  "${args_dict[tabulate_diamond_fast_count_reads_extension]}"
  

## CALCULATE CONFUSION MATRIX
run_pipeline_step "tabulate_diamond_fast_sensitive" "$base_dataset_path" \
  "$custom_script python $repository_src/pipeline_steps/5-tabulate_known_viruses.py" \
  "${args_dict[tabulate_diamond_fast_sensitive_align_coverage]}" \
  "${args_dict[tabulate_diamond_fast_sensitive_align_identity]}" \
  "${args_dict[tabulate_diamond_fast_sensitive_align_length]}" \
  "${args_dict[tabulate_diamond_fast_sensitive_align_evalue]}" \
  "${args_dict[taxonomy_database]}" \
  "$base_dataset_path" \
  "$repository_src/../${args_dict[tabulate_diamond_fast_sensitive_metadata_path]}" \
  "${args_dict[tabulate_diamond_fast_sensitive_count_reads_folder]}" \
  "${args_dict[tabulate_diamond_fast_sensitive_count_reads_extension]}"


################################################################################
################################################################################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished pipeline for ${dataset_name}!"