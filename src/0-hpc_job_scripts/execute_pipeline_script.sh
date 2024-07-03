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

# Start job profile
start=$(date +%s.%N)
echo "Started running job!"

num_processes=$1

################################################################################
############################### ATTENTION !!!!! ################################
################################################################################
################### FOR EACH ANALYSIS FILL THESE INFORMATION ###################
################################################################################

# Basespace project ID
basespace_project_id=403173828
# suffix of each sample forward sequence
input_suffix="_L001_R1_001.fastq.gz"

samples_name="aesop_rio02"
base_path="/scratch/pablo.viana/aesop/dataset_rio02"

kraken_db_std="/scratch/pablo.viana/databases/kraken_db/aesop_kraken_db_k2_pluspf_20231009"
kraken_db_euk="/scratch/pablo.viana/databases/kraken_db/aesop_kraken_db_k2_eupathdb48_20230407"

################################################################################
################################################################################
################################################################################




################################################################################
################################## DOWNLOAD ####################################
################################################################################

ini=$(date +%s.%N)
echo "Started Executing DOWNLOAD"

# Script to be executed for task
task_script="/scratch/pablo.viana/softwares/basespace_illumina/bs"
# Destination folder
output_dir="$base_path/0-raw_samples"
output_dir_download="$base_path/0-download"

rm -rf $output_dir
rm -rf $output_dir_download

mkdir -p $output_dir
mkdir -p $output_dir_download

export BASESPACE_API_SERVER="https://api.basespace.illumina.com"
export BASESPACE_ACCESS_TOKEN="af3e8cde48a74ad38fd4ead99373da58"

echo "$task_script list projects"
$task_script list projects

echo "$task_script download project -i $basespace_project_id -o $output_dir_download --extension=fastq.gz"
$task_script download project -i $basespace_project_id -o $output_dir_download --extension=fastq.gz

echo "ls -la $output_dir_download"
ls -la $output_dir_download

echo "find $output_dir_download -type f -name '*.fastq.gz' -exec mv -v {} $output_dir \;"
find $output_dir_download -type f -name "*.fastq.gz" -exec mv -v {} $output_dir \;

# echo "mv -v $output_dir/*unmapped* $output_dir_download || echo 'mv command didnt find files to move!'"
# mv -v $output_dir/*unmapped* $output_dir_download || echo 'mv command didnt find files to move!'

echo "ls -la $output_dir:"
ls -la $output_dir

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished DOWNLOAD in: ${runtime} min."


################################################################################
###################################  FASTP  ####################################
################################################################################

ini=$(date +%s.%N)
echo "Started Executing FASTP"

# Script to be executed for each sample
task_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/1-quality_control-fastp_filters.sh"
# Path containing the samples
input_dir="$base_path/0-raw_samples"
# Destination folder
output_dir="$base_path/1-fastp_output"

rm -rf $output_dir
# Create folder if it doesn't exist
mkdir -p $output_dir

find "$input_dir" -type f -name "*$input_suffix" | \
#head -n 1 | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $input_dir $output_dir $input_suffix"

echo "Tar gziping log files: tar -czf ${samples_name}_fastp_logs.tar.gz *.log *.err *.json *.html"
tar -czf "${samples_name}_fastp_logs.tar.gz" *.log *.err *.json *.html

echo "Removing log files: rm -rf [0-9]*.log *.json *.html"
rm -rf [0-9]*.log *.json *.html *.json *.html

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished FASTP in: ${runtime} min."


################################################################################
##################################  BOWTIE2  ###################################
################################################################################
ini=$(date +%s.%N)
echo "Started Executing BOWTIE"

# Script to be executed for each sample
task_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/2-sample_decontamination-bowtie2_remove_host_reads.sh"
# Path containing the samples
input_dir=$output_dir
# Destination folder
output_dir="$base_path/2-bowtie_output"

rm -rf $output_dir
# Create folder if it doesn't exist
mkdir -p "$output_dir/SAM_FILES"
mkdir -p "$output_dir/BAM_FILES"
mkdir -p "$output_dir/UNMAPPED_FASTA"

find "$input_dir" -type f -name "*_R1.fastq" | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $input_dir $output_dir"

echo "Tar gziping log files: tar -czf ${samples_name}_bowtie_logs.tar.gz *.log *.err"
tar -czf "${samples_name}_bowtie_logs.tar.gz" *.log *.err

echo "Removing log files: rm -rf [0-9]*.log"
rm -rf [0-9]*.log

echo "Removing intermediate folders: rm -rf $output_dir/SAM_FILES $output_dir/BAM_FILES $output_dir/UNMAPPED_FASTA"
rm -rf "$output_dir/SAM_FILES" "$output_dir/BAM_FILES" "$output_dir/UNMAPPED_FASTA"

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished BOWTIE in: ${runtime} min."

#######################
####### KRAKEN ########
#######################
ini=$(date +%s.%N)
echo "Started Executing KRAKEN "

# Script to be executed for each sample
task_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
# Path containing the samples
input_dir=$output_dir
# Destination folder
output_dir="$base_path/3-kraken_results_std"

rm -rf $output_dir
# Create folder if it doesn't exist
mkdir -p $output_dir

find "$input_dir" -type f -name "*.fasta" | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $input_dir $output_dir $kraken_db_std"

echo "Tar gziping log files: tar -czf ${samples_name}_kraken_std_logs.tar.gz *.log *.err"
tar -czf  *.log *.err

echo "Removing log files: rm -rf [0-9]*.log"
rm -rf [0-9]*.log

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished KRAKEN in: ${runtime} min."

#######################
##### KRAKEN EUK ######
#######################
ini=$(date +%s.%N)
echo "Started Executing KRAKEN EUK"

# Script to be executed for each sample
task_script="/home/pablo.viana/jobs/github/aesop-metagenomics/src/1-analysis_pipeline/3-taxonomic_annotation-kraken2.sh"
# Path containing the samples
# input_dir=$output_dir
# Destination folder
output_dir="$base_path/3-kraken_results_euk"

rm -rf $output_dir
# Create folder if it doesn't exist
mkdir -p $output_dir

find "$input_dir" -type f -name "*.fasta" | \
  awk '{printf("%d \"%s\"\n", NR, $1)}' | \
  xargs -I {} -P $num_processes sh -c "$task_script {} $input_dir $output_dir $kraken_db_euk"

echo "Tar gziping log files: tar -czf ${samples_name}_kraken_euk_logs.tar.gz *.log *.err"
tar -czf  *.log *.err

echo "Removing log files: rm -rf [0-9]*.log"
rm -rf [0-9]*.log

#  Finish task profile
end=$(date +%s.%N)
runtime=$(awk -v a=$end -v b=$ini 'BEGIN{printf "%.3f", (a-b)/60}')
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished KRAKEN in: ${runtime} min."

#######################
#######################

#  Finish pipeline profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)/60}')
echo ""
echo "Total elapsed time: ${runtime} min."
echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: Finished complete pipeline!"
