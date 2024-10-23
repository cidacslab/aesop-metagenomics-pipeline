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

bash --version

# Start job profile
start=$(date +%s.%N)
echo "Started running job for all datasets!"

# Pipeline script to be executed
pipeline_script=$1
# Dictionary with dataset names and their project_id
sample_datasets=$2
# Parameters to be passed to the script
args_str=$3

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


echo ""
df
du -hd 4 /scratch/pablo.viana | sort -k2
find /scratch/pablo.viana | sort
# du -hd 4 /home/pedro/aesop/pipeline | sort -k2
# find /home/pedro/aesop/pipeline | sort


#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline for all datasets!"