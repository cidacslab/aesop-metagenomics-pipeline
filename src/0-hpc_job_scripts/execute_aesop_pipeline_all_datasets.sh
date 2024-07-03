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
declare -A sample_datasets=(  ["mao01"]="1234" ["ssa01"]="393298912"  ["aju02"]="398485813" ["rio02"]="403173828" ["rio03"]="414143602" ["rs01"]="420835421" ["rs02"]="417421287" ["rs03"]="419098942" ["bsb01"]="422858797")
# declare -A sample_datasets=(  ["mao01"]="1234" ["rio01"]="394153669" )
# declare -A sample_datasets=( ["rs01"]="420835421" ["rs02"]="417421287" ["rs03"]="419098942"  ["rio03"]="414143602" )
# declare -A sample_datasets=( ["rio02"]="403173828" ["rio01"]="394153669" ["aju02"]="398485813" ["ssa01"]="393298912")
# declare -A sample_datasets=( ["wgs_ssa"]="412407112" )
# declare -A sample_datasets=( ["bsb01"]="422858797")

for dataset in "${!sample_datasets[@]}"; do
    project_id=${sample_datasets[$dataset]}
    echo "######################################################"
    echo "######################################################"
    echo "Starting pipeline for dataset: $dataset : $project_id"
    echo "######################################################"
    /home/pablo.viana/jobs/github/aesop-metagenomics/src/0-hpc_job_scripts/execute_czid_pipeline.sh $1 $dataset $project_id
done


#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline for all datasets!"