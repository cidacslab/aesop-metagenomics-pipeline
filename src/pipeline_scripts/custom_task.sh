#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2023/03/16

Template script used to run a task script over the input samples.

params $1 - Number os parallel processes to be executed
params $2 - Script to be executed
params $3 - Script parameters
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
if [ "$#" -lt 6 ]; then
    echo "Error! Usage: $0 <script_file> [parameters...]"
    exit 1
fi

# Extract the script file path (second argument)
task_script="$1"

# Check if the script file exists
# if [ ! -f "$task_script" ]; then
#     echo "Error: Script file '$task_script' not found." >&2
#     exit 1
# fi
# script_name=$(basename "$task_script")
# script_name=${script_name%.*}
script_name=$task_script

# Dataset name
dataset_name="$2"
# Extract the number of proccesses to be run in parallel
num_processes="$3"
# Delete preexisting output directory
delete_output_dir="$4"
# Tar Log file name
tar_log_file="$5"
# Suffix of the input files
input_suffix="$6"
# Path containing the input files
input_dir="$7"
# Destination folder for the output files
output_dir="$8"
# Number of parallel threads to be run in each process
nthreads="$9"

shift 5 # Remove the first 5 arguments from the list

###############################################################################
############################## SCRIPT EXECUTION ###############################
###############################################################################

#Start timing profile
ini=$(date +%s.%N)
echo "Started Executing $script_name"

args=($@)
args_str=$(printf '%s ' "${args[@]}")
echo "Parameters: $args_str"

if [ $delete_output_dir -eq 1 ]; then
  echo "rm -rf $output_dir"
  rm -rf $output_dir
fi

echo "mkdir -p $output_dir"
mkdir -p $output_dir

find "$input_dir" -type f -name "*${input_suffix}" | \
  # head -n 1 | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $args_str"

echo "Tar gziping log files: find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf ${tar_log_file}"
find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf "${tar_log_file}"

echo "Removing log files: rm -rf [0-9]*.log"
rm -rf [0-9]*.log

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished ${script_name} in: ${runtime} min."

###############################################################################
###############################################################################