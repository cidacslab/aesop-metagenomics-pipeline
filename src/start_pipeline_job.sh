#!/bin/bash
################################################################################
#################################  BEGIN JOB  ##################################
################################################################################
#SBATCH --job-name='AESOP JOB'                        # Job name
#SBATCH --partition=cpu_iterativo                     # CPU batch queue
#SBATCH --nodes=1                                     # Maxinum amount of nodes
#SBATCH --cpus-per-task=40                            # Maxinum amount of cores
#SBATCH --mem=1024GB                                  # Maxinum amount of memory
#SBATCH --time=99:00:00                               # Time limit hrs:min:sec
#SBATCH --output=aesop_%j.log                         # Standard output log
#SBATCH --error=aesop_%j.err                          # Standard error log
################################################################################
:<<DOC
Author: Pablo Viana
Created: 2024/07/06

Template script used to start the pipeline on SLURM JOB or locally.
DOC


################################################################################
############################### ATTENTION !!!!! ################################
########### CHECK IF ALL PARAMETERS ARE CORRECT FOR YOUR ENVIRONMENT ###########
################################################################################
# Variable for the parameters
declare -A params

################################################################################
################# DEFINE THE DATASETS TO EXECUTE THE PIPELINE ##################
################################################################################
# List all datasets and their basepace project ID
# Format MUST BE: [DATASET_NAME]:[BASEPACE_ID]
# If dataset is not from basespace put any number
# If using Illumina basespace EDIT CREDENTIALS in download parameters bellow
# You can execute mutiple datasets at once, commented lines will not be executed
sample_datasets="
                #  test01:123456789
                mock01:123456789"

################################################################################
######################### DEFINE THE SERVER LOCATIONS ##########################
################################################################################
# Location where to execute the pipeline
server="hpc"
# server="prometheus"

# Set the server locations, paths MUST NOT have spaces
# ADD NEW SERVER HERE IF NEEDED
case $server in
  "hpc")
    # Location of src folder in the github directory
    params["repository_src"]="/home/pablo.viana/metagenomics_src"
    # Location of the dataset data
    params["base_dataset_path"]="/scratch/pablo.viana/aesop/pipeline_v8"
    # HISAT2 human index to remove human reads
    params["hisat2_human_index"]="/scratch/pablo.viana/databases/hisat2_db/human_index_20240725/human_full_hisat2"
    # Bowtie2 human index to remove human reads
    params["bowtie2_human_index"]="/scratch/pablo.viana/databases/bowtie2_db/human_index_20240725/human_full"
    # Kraken2 taxonomic database
    params["kraken2_database"]="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"
    # Bracken taxonomic estimation database
    params["bracken_database"]="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"
    # Location of the final report output
    params["final_output_path"]="/opt/storage/shared/aesop/metagenomica/biome/pipeline_v8_mock"
    # Location of software executables
    params["FASTP_EXECUTABLE"]="/scratch/pablo.viana/softwares/fastp-0.23.2"
    params["HISAT2_EXECUTABLE"]="/scratch/pablo.viana/softwares/hisat2-2.2.1/hisat2"
    params["BOWTIE2_EXECUTABLE"]="/scratch/pablo.viana/softwares/bowtie2-2.5.1-linux-x86_64/bowtie2"
    params["SAMTOOLS_EXECUTABLE"]="/scratch/pablo.viana/softwares/samtools-1.17/bin/samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["BRACKEN_EXECUTABLE"]="/scratch/pablo.viana/softwares/Bracken-master/bracken"
    params["BLASTN_EXECUTABLE"]="/scratch/pablo.viana/softwares/ncbi-blast-2.14.0+/bin/blastn"
    params["DIAMOND_EXECUTABLE"]="/scratch/pablo.viana/softwares/diamond"
    ;;
  "prometheus")
    params["repository_src"]="/home/work/aesop/github/aesop-metagenomics/src"
    params["base_dataset_path"]="/home/work/aesop/results_pipeline_v8"
    params["hisat2_human_index"]="/dev/shm/databases/hisat2_db/human_index_20240725/human_full_hisat2"
    params["bowtie2_human_index"]="/dev/shm/databases/bowtie2_db/human_index_20240725/human_full"
    params["kraken2_database"]="/dev/shm/databases/aesop_kraken2db_20240619"
    params["final_output_path"]="$base_dataset_path"
    params["FASTP_EXECUTABLE"]="fastp"
    params["HISAT2_EXECUTABLE"]="hisat2"
    params["BOWTIE2_EXECUTABLE"]="bowtie2"
    params["SAMTOOLS_EXECUTABLE"]="samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["BRACKEN_EXECUTABLE"]="bracken"
    params["BLASTN_EXECUTABLE"]="blastn"
    params["DIAMOND_EXECUTABLE"]="diamond"
    ;;
  *)
    # Default case if no pattern matches
    echo "Didn't define a valid server"
    exit 1
    ;;
esac

################################################################################
################### DEFINE STAGES TO EXECUTE IN THE PIPELINE ###################
################################################################################
# 0 = DONT EXECUTE STAGE | 1 = EXECUTE STAGE
params["execute_download"]=0
params["execute_fastp"]=1
params["execute_hisat2_human"]=1
params["execute_bowtie2_human"]=1
params["execute_kraken2"]=1
params["execute_bracken"]=1
params["execute_normalization"]=0
#If a stage is not executed change the input_path for the next stage accordingly

################################################################################
###################### DEFINE STAGES SPECIFIC PARAMETERS #######################
################################################################################
### Download parameters
# params["download_suffix"]=".fastq.gz"
# params["download_folder"]="0-download"
# params["download_output_folder"]="0-raw_samples"
# params["download_basespace_access_token"]="$(cat data/basespace_token.txt)"
### Fastp quality control parameters
params["fastp_nprocesses"]="4"
params["fastp_process_nthreads"]="8"
params["fastp_input_suffix"]="_1.fastq"
params["fastp_input_folder"]="0-raw_samples"
params["fastp_output_folder"]="1-fastp_output"
params["fastp_delete_preexisting_output_folder"]=1
params["fastp_minimum_length"]=50
params["fastp_max_n_count"]=2
### HISAT2 remove HUMAN parameters
params["hisat2_human_nprocesses"]="4"
params["hisat2_human_process_nthreads"]="16"
params["hisat2_human_input_suffix"]="_1.fastq"
params["hisat2_human_input_folder"]="1-fastp_output"
params["hisat2_human_input_folder"]="2-hisat_human_output"
params["hisat2_human_delete_preexisting_output_folder"]=1
### Bowtie2 remove HUMAN parameters
params["bowtie2_human_nprocesses"]="4"
params["bowtie2_human_process_nthreads"]="16"
params["bowtie2_human_input_suffix"]="_1.fastq"
params["bowtie2_human_input_folder"]="2-hisat_human_output"
params["bowtie2_human_output_folder"]="2-bowtie_human_output"
params["bowtie2_human_delete_preexisting_output_folder"]=1
### Kraken2 annotation parameters
params["kraken2_nprocesses"]="2"
params["kraken2_process_nthreads"]="32"
params["kraken2_input_suffix"]="_1.fastq"
params["kraken2_input_folder"]="2-bowtie_human_output"
params["kraken2_output_folder"]="3-taxonomic_output"
params["kraken2_delete_preexisting_output_folder"]=1
params["kraken2_confidence"]=0
### Bracken annotation parameters
params["bracken_nprocesses"]="6"
params["bracken_input_suffix"]=".kreport"
params["bracken_input_folder"]="3-taxonomic_output"
params["bracken_output_folder"]="3-taxonomic_output"
params["bracken_delete_preexisting_output_folder"]=0
params["bracken_read_length"]=150
params["bracken_threshold"]=1
### Normalization parameters
# params["normalization_input_suffix"]="_1.fastq"
# params["normalization_input_folder"]="1-bowtie_ercc_output"
# params["normalization_folders"]="3-kraken_results:5-kraken_reports;4-bracken_results:6-bracken_reports"
# params["normalization_folders"]+=";3-kraken_czid_results:5-kraken_czid_reports;"
# params["normalization_folders"]="3-taxonomic_output:4-normalized_reports"

################################################################################
################################################################################
# CONVERTING PARAMETERS TO A STRING
# Trim all lines, then filter out comments and empty lines
sample_datasets=$(echo "$sample_datasets" | \
                  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
                  grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#')

# Initialize an empty string to hold the parameters as a string
params_str=""
# Iterate over the dictionary and build the string
for key in "${!params[@]}"; do
  value=${params[$key]}
  params_str+="$key=$value "
done
# Remove the trailing space
params_str=${params_str% }

################################################################################
####################### DEFINE THE EXECUTION PARAMETERS ########################
################################################################################

# Pipeline script to be executed
pipeline_script=${params["repository_src"]}/pipeline_scripts/paper_pipeline.sh

# Script that call the pipeline for each dataset
script_for_datasets=${params["repository_src"]}/pipeline_scripts/execute_pipeline_for_datasets.sh

# Set execution command in singularity docker or local
# Template: singularity exec [SINGULARITY_OPTIONS] <sif> [COMMAND_OPTIONS]
command="singularity exec /opt/images/cidacs/biome.sif"
# command="singularity exec /opt/images/cidacs/cidacs-jupyter-datascience-v1-r2.sif"
# # Local execution
# command=""

################################################################################
################################################################################

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "$sample_datasets"
echo "    $params_str"

$command $script_for_datasets "$pipeline_script" "$sample_datasets" "$params_str"

################################################################################
################################################################################
