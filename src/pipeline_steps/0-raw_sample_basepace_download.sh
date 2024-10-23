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

###############################################################################
############################ PARAMETERS VALIDATION ############################
###############################################################################

# Name of the current dataset
dataset_name="$1"
# Delete preexisting output directory
delete_output_dir="$2"
# Log file name
log_file="$3"
# suffix of each sample forward sequence
input_suffix="$4"
# Download folder
download_dir="$5"
# Destination folder
output_dir="$6"
# Basespace project ID
basespace_project_id="$7"
# Basespace access token
basespace_access_token="$8"


################################################################################
################################## DOWNLOAD ####################################
################################################################################

# Start timing profile
ini=$(date +%s.%N)
echo "Started Executing DOWNLOAD"

args=($@)
args_str=$(printf '%s ' "${args[@]}")
echo "Parameters: $args_str"

export BASESPACE_API_SERVER="https://api.basespace.illumina.com"
export BASESPACE_ACCESS_TOKEN=$basespace_access_token

# Script to be executed for task
task_script=$BASESPACE_CLI_EXECUTABLE

{
if [ $delete_output_dir -eq 1 ]; then
  echo "rm -rf $output_dir"
  rm -rf $output_dir
  echo "rm -rf $download_dir"
  rm -rf $download_dir
fi

mkdir -p $output_dir
mkdir -p $download_dir

echo "$task_script list projects"
$task_script list projects

echo "$task_script download project -v -i $basespace_project_id -o $download_dir --extension=fastq.gz --exclude='*unmapped*'"
$task_script download project -v -i $basespace_project_id -o $download_dir --extension=fastq.gz --exclude='*unmapped*'

echo "ls -la $download_dir"
ls -la $download_dir

echo "find $download_dir -type f -name '*.fastq.gz' -exec mv -v {} $output_dir \;"
find $download_dir -type f -name "*.fastq.gz" -exec mv -v {} $output_dir \;

echo "ls -la $output_dir:"
ls -la $output_dir

} &> ${log_file}

# echo "Gziping log file: gzip ${BASHPID}_${log_file}"
# gzip ${BASHPID}_${log_file}

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished DOWNLOAD in: ${runtime} min."