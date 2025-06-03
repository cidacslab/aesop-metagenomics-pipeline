#!/bin/bash
:<<DOC
Author: Pablo Viana
Created: 2024/09/10

Template script used to run a task script over the input samples.

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
# Extract the script file path (second argument)
task_script="$1"
script_name=$task_script
# Extract the number of proccesses to be run in parallel
num_processes="$2"
# Delete preexisting output directory
delete_output_dir="$3"
# Tar Log file name
tar_log_file="$4"
# Suffix of the input files
input_suffix="$5"
# Path containing the input files
input_dir="$6"
# Destination folder for the output files
output_dir="$7"
# Number of parallel threads to be run in each process
nthreads="$8"

shift 4 # Remove the first 4 arguments from the list

###############################################################################
############################## SCRIPT EXECUTION ###############################
###############################################################################

#Start timing profile
ini=$(date +%s.%N)
echo "Started Executing $script_name"

args=($@)
args_str=$(printf '%s ' "${args[@]}")
echo "Parameters filtered: $args_str"

if [ $delete_output_dir -eq 1 ]; then
  echo "rm -rf $output_dir"
  rm -rf $output_dir
fi

echo "mkdir -p $output_dir"
mkdir -p $output_dir

find -L "$input_dir" -type f -name "*${input_suffix}" | sort -r | \
  # head -n 5 | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $args_str"

# Check if has to compress the log files
if [[ "$tar_log_file" == *.tar.gz ]]; then
  echo "Tar gziping log files: find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf ${tar_log_file}"
  find . \( -name '*.log' -or -name '*.err' \) -print0 | xargs -0 tar -czf "${tar_log_file}"

  echo "Removing log files: rm -rf [0-9]*.log"
  rm -rf [0-9]*.log
else
  echo "Didnt zip any log files."
fi

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished ${script_name} in: ${runtime} min."

###############################################################################
###############################################################################