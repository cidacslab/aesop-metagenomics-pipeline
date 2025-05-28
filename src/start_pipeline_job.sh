#!/bin/bash
################################################################################
#################################  BEGIN JOB  ##################################
################################################################################
#SBATCH --job-name='AESOP JOB'                        # Job name
#SBATCH --partition=cpu_iterativo                     # CPU batch queue
#SBATCH --nodes=1                                     # Maxinum amount of nodes
#SBATCH --cpus-per-task=40                            # Maxinum amount of cores
#SBATCH --mem=1024GB                                  # Maxinum amount of memory
#SBATCH --time=99:00:00                               # Time limit hrs:min:sec
#SBATCH --output=aesop_%j.log                         # Standard output log
#SBATCH --error=aesop_%j.err                          # Standard error log
################################################################################
:<<DOC
Author: Pablo Viana
Created: 2024/07/06

Template script used to start the pipeline on SLURM JOB or locally.
DOC

################################################################################
# Path to the JSON file containing the parameters
default_json_file="/data/aesop/github/aesop-metagenomics-pipeline/data/aesop_data/biome_parameters.jsonc"
# Check if the JSON file is provided as an argument
json_file="${1:-$default_json_file}"

################################################################################
############################# LOAD PARAMETERS JSON #############################
################################################################################
# Define the dictionary variable for the parameters
declare -A params

# Remove everything after //
# This approach assumes // does not appear inside quoted strings
cleaned_json=$(mktemp)
sed 's/\/\/.*$//' "$json_file" > "$cleaned_json"

# 1) Generate all scalar paths (including nested objects and arrays)
#    Then flatten each path into a dot-notation string, e.g. "nested1.sub1.key1"
#    Example: '["nested1","sub1","key1"]' → "nested1.sub1.key1"
while IFS= read -r path; do
  # 1.1) Skip attribute sample_datasets
  if [[ "$path" =~ sample_datasets ]]; then
    continue
  fi
  # 2) Use that path to extract the actual value with 'jq'
  value=$(jq -r ".${path}" "$cleaned_json")
  # 3) Convert dots (and array indices) in the path to underscores
  #    e.g. "nested1.sub1.key1" → "nested1_sub1_key1"
  new_key=$(echo "$path" | tr '.' '_')
  # 4) Assign into the Bash array
  params["$new_key"]="$value"
done < <(jq -r 'paths(scalars) | join(".")' "$cleaned_json")

# SAMPLE DATASETS
# Retrieve the sample_datasets array
sample_datasets=$(jq -r '.sample_datasets[]' "$cleaned_json")

# CONVERTING PARAMETERS TO A STRING 
# Initialize an empty string to hold the parameters as a string
params_str=""
# Iterate over the dictionary and build the string
for key in "${!params[@]}"; do
  value=${params[$key]}
  params_str+="$key=$value|"
done
# Remove trailing | if present
params_str=${params_str%|}

################################################################################
####################### DEFINE THE EXECUTION PARAMETERS ########################
################################################################################

# Script that call the pipeline for each dataset
script_for_datasets="${params[repository_src]}/${params[script_for_datasets]}"
# Pipeline script to be executed
pipeline_script="${params[repository_src]}/${params[pipeline_script]}"
# Get execution command in singularity docker or local
command="${params[command]}"

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "    $params_str"
echo "  $sample_datasets"

$command $script_for_datasets "$pipeline_script" "$params_str" "$sample_datasets"

################################################################################
################################################################################
