#!/bin/bash
################################################################################
#################################  BEGIN JOB  ##################################
################################################################################
#SBATCH --job-name='AESOP METAGENOMIC'                # Job name
#SBATCH --partition=cpu_iterativo                     # CPU batch queue
#SBATCH --nodes=1                                     # Maxinum amount of nodes
#SBATCH --cpus-per-task=64                            # Maxinum amount of cores
#SBATCH --mem=1024GB                                  # Maxinum amount of memory
#SBATCH --time=99:00:00                               # Time limit hrs:min:sec
#SBATCH --output=aesop_%j.log                         # Standard output log
#SBATCH --error=aesop_%j.err                          # Standard error log
################################################################################
:<<DOC
Author: Pablo Viana
Created: 2024/07/06

Template script used to start the pipeline on SLURM JOB or locally.

params $1 - JSON file path (OPTIONAL)

Define default value for json file if not provided
DOC

################################################################################
# Path to the JSON file containing the parameters
default_json_file="pipeline_parameters.jsonc"
# Check if the JSON file is provided as an argument
json_file="${1:-$default_json_file}"

################################################################################
############################# LOAD PARAMETERS JSON #############################
################################################################################
# Define the dictionary variable for the parameters
declare -A params

# Remove everything after // except when inside ""
cleaned_json=$(mktemp)
awk '
{
  out = ""; inq = 0; prev = ""
  for (i = 1; i <= length($0); i++) {
    c   = substr($0, i, 1)
    nxt = substr($0, i, 2)
    if (c == "\"" && prev != "\\") inq = !inq          # toggle on un-escaped "
    if (nxt == "//" && !inq) { print out; next }       # cut rest of line
    out = out c
    prev = c
  }
  print out
}' "$json_file" > "$cleaned_json"

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
# Get execution command in singularity docker or local
command="${params[command]}"
# Remove command from params to avoid passing it as a parameter
unset params[command] 

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

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "    $params_str"
echo "  $sample_datasets"

$command $script_for_datasets "$pipeline_script" "$params_str" "$sample_datasets"

################################################################################
################################################################################
