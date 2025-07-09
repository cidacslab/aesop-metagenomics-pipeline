#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/04/19

Template script used to download input samples.

params $1 - Script to be executed
params $2 - Number of parallel processes to run this script
params $3 - Flag to delete the contents of the output directory before start execution
params $4 - Name of the tar log file to be created compressing all log files of the execution
params $5 - Suffix of the files to be used as inputs
params $6 - Input directory where to look for the input files
params $7 - Output directory where to place the output files
params $8 - Number of threads that each process should use
params $@ - Any extra parameters that may be added

All these parameters, except the first 4, are passed down to be used by the script in each process.
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


###############################################################################
############################ PARAMETERS VALIDATION ############################
###############################################################################

# Check if the correct number of arguments is provided
if [ "$#" -lt 8 ]; then
  echo "Error! Usage: $0 <script_file> [parameters...]"
  exit 1
fi

echo "Parameters: $@"
# Extract the number of proccesses to be run in parallel
# num_processes="$1"  # NOT USED
# Delete preexisting output directory
delete_output_dir="$2"
# Tar Log file name
log_file="$3"
# Suffix of the input files
input_suffix="$4"
# Download folder
download_dir="$5"
# Destination folder
output_dir="$6"
# Number of parallel threads to be run in each process
# nthreads="$7"       # NOT USED
# Basespace access token
basespace_access_token="$8"
# Basespace API SERVER
basespace_api_server="$9"
# Basespace project ID
basespace_project_id="${10}"


################################################################################
################################## DOWNLOAD ####################################
################################################################################

# Start timing profile
ini=$(date +%s.%N)
echo "Started Executing DOWNLOAD"

args=($@)
args_str=$(printf '%s ' "${args[@]}")
echo "Parameters: $args_str"

if [ $delete_output_dir -eq 1 ]; then
  echo "rm -rf $output_dir"
  rm -rf $output_dir
  echo "rm -rf $download_dir"
  rm -rf $download_dir
fi

mkdir -p $output_dir
mkdir -p $download_dir

export BASESPACE_API_SERVER=$basespace_api_server
export BASESPACE_ACCESS_TOKEN=$basespace_access_token

# Script to be executed for task
task_script=$BASESPACE_CLI_EXECUTABLE

{
  echo "Started Executing DOWNLOAD"
  
  args=($@)
  args_str=$(printf '%s ' "${args[@]}")
  echo "Parameters: $args_str"
  
  echo "$task_script list projects"
  $task_script list projects
  
  echo "$task_script download project -v -i $basespace_project_id -o $download_dir --extension='$input_suffix' --exclude='*unmapped*' --exclude='*deter*'"
  $task_script download project -v -i $basespace_project_id -o $download_dir --extension="$input_suffix" --exclude='*unmapped*' --exclude='*deter*'
  
  echo "ls -la $download_dir"
  ls -la $download_dir
  
  echo "find $download_dir -type f -name '*.fastq.gz' -exec mv -v {} $output_dir \;"
  find $download_dir -type f -name "*.fastq.gz" -exec mv -v {} $output_dir \;
  
  echo "ls -la $output_dir:"
  ls -la $output_dir
  
} &> ${log_file}

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished DOWNLOAD in: ${runtime} min."