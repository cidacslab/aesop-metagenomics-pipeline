#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/09/10

Script used to run the pipeline for each sample dataset.

params $1 - Pipeline script to be executed
params $2 - Argument string comprising the complete list of arguments
params $3 - Dataset list

This files contains the functions to parse the argument string to a dictionary,
and to execute each pipeline step.
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

bash --version

# Start job profile
start=$(date +%s.%N)
echo "Started running pipeline for all datasets!"


################################################################################
#############  SET VALUES IN DICT AND EXPORT EXECUTABLES FUNCTION  #############
################################################################################

# Function to modify any dictionary variable (associative array)
set_values_in_dict_and_export_executables() {
  local dict_var=$1  # Name of the dictionary variable
  local dict_args=$2
  # local exports_str=$3
  
  # Use `declare -n` to create a reference to the dictionary
  declare -n dict_ref="$dict_var"
  
  # Use IFS to split by | and read each key-value pair
  IFS='|' read -ra pairs <<< "$dict_args"

  # Loop through the key-value pairs
  for pair in "${pairs[@]}"; do
    IFS='=' read -r key value <<< "$pair"    
    # If the key looks like an executable path, export it
    if [[ $key == *_EXECUTABLE ]]; then
      # declare -gx VAR=value  sets + exports in one go
      declare -gx "$key=$value"
    else
      # else store in the dictionary   
      dict_ref["$key"]="$value"
    fi
  done
}

################################################################################
###########################  PIPELINE STEP FUNCTION  ###########################
################################################################################

# Global variable to track if the step was executed successfully
declare -gx STEP_EXECUTED=0  # Default is 0 (Step was not executed)

# Function to execute each step
run_pipeline_step() {
  local step_name=$1
  local dataset_name=$2
  local base_dataset_path=$3
  local full_command=$4
  shift 4 # Shift past the first four arguments (step_name, script_path)
  
  # Global variable to track if the step was executed successfully
  STEP_EXECUTED=0  # Default is 0 (Step was not executed)
  
  # Check if the step should be executed
  if [[ -v args_dict[execute_${step_name}] && ${args_dict[execute_${step_name}]} -eq 1 ]]; then
    # Create default argument list
    params=("${args_dict[${step_name}_nprocesses]}"
            "${args_dict[${step_name}_delete_preexisting_output_folder]}"
            "${dataset_name}_${args_dict[${step_name}_log_file]}"
            "${args_dict[${step_name}_input_suffix]}"
            "${base_dataset_path}/${args_dict[${step_name}_input_folder]}"
            "${base_dataset_path}/${args_dict[${step_name}_output_folder]}"
            "${args_dict[${step_name}_process_nthreads]}"
            $@) # Add any extra arguments passed to the function
    
    echo ""
    echo "Executing step: $step_name"
    
    # Convert full_command into an array while preserving spaces inside quotes
    set -- $full_command
    script_runner=$1  # First argument is the script runner
    shift  # Remove the first argument from list
    script_command="$*"  # Join remaining words as a single string
    # This is needed to handle commands with spaces,
    # ensuring they are not split as distict arguments.
    
    # Execute command with the preserved extra parameters
    if [[ -n "$script_command" ]]; then
      "$script_runner" "$script_command" "${params[@]}"
    else
      "$full_command" "${params[@]}"
    fi
    
    STEP_EXECUTED=1  # Step executed successfully
  fi
}

################################################################################
# make functions available to child processes
export -f set_values_in_dict_and_export_executables
export -f run_pipeline_step

# Pipeline script to be executed
pipeline_script=$1
# Parameters to be passed to the script
args_str=$2
# Dictionary with dataset names and their project_id
sample_datasets=$3

# Loop throught all datasets
while IFS= read -r dataset_line; do
  IFS=":" read -r dataset project_id <<< "$dataset_line"
  echo "######################################################"
  echo "######################################################"
  echo "Executing script: $pipeline_script"
  echo "     For dataset: $dataset : $project_id"
  echo "######################################################"
  $pipeline_script "$args_str" "$dataset" "$project_id"
done <<< "$sample_datasets"

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline for all datasets!"