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

# Extract the number of proccesses to be run in parallel (first argument)
num_processes="$1"

# Extract the script file path (second argument)
task_script="$2"

# Check if the script file exists
if [ ! -f "$task_script" ]; then
    echo "Error: Script file '$task_script' not found." >&2
    exit 1
fi
script_name=$(basename "$task_script")
script_name=${script_name%.*}

# Dataset name
dataset_name="$3"
# Suffix of the input files
input_suffix="$4"
# Path containing the input files
input_dir="$5"
# Destination folder for the output files
output_dir="$6"

shift # Remove the first argument from the list
shift # Remove the second argument from the list
shift # Remove the third argument from the list

###############################################################################
############################## SCRIPT EXECUTION ###############################
###############################################################################

#Start timing profile
ini=$(date +%s.%N)
echo "Started Executing $script_name"

args=($@)
args_str=$(printf '%s ' "${args[@]}")
echo "Parameters: $args_str"

# rm -rf $output_dir
mkdir -p $output_dir

find "$input_dir" -type f -name "*${input_suffix}" | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $args_str"

echo "Tar gziping log files: find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf ${dataset_name}_${script_name}_logs.tar.gz"
find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf "${dataset_name}_${script_name}_logs.tar.gz"

echo "Removing log files: rm -rf [0-9]*.log"
rm -rf [0-9]*.log

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished ${script_name} in: ${runtime} min."

###############################################################################
###############################################################################