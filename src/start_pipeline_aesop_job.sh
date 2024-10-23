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

# Set execution command in singularity docker or local
# Template: singularity exec [SINGULARITY_OPTIONS] <sif> [COMMAND_OPTIONS]
command="singularity exec /opt/images/cidacs/biome.sif"
# command="singularity exec /opt/images/cidacs/cidacs-jupyter-datascience-v1-r2.sif"
# Local execution
# command=""

################################################################################
################# DEFINE THE DATASETS TO EXECUTE THE PIPELINE ##################
################################################################################
# List all datasets and their basepace project ID
# Format MUST BE: [DATASET_NAME]:[BASEPACE_ID]
# If dataset is not from basespace put any number
# If using Illumina basespace EDIT CREDENTIALS in download parameters bellow
# You can execute mutiple datasets at once, commented lines will not be executed
sample_datasets="
                test01
                "

################################################################################
############################### ATTENTION !!!!! ################################
########### CHECK IF ALL PARAMETERS ARE CORRECT FOR YOUR ENVIRONMENT ###########
################################################################################
# Variable for the parameters
declare -A params

################################################################################
################### DEFINE STAGES TO EXECUTE IN THE PIPELINE ###################
################################################################################
# 0 = DONT EXECUTE STAGE | 1 = EXECUTE STAGE
params["execute_download"]=1
params["execute_bowtie2_phix"]=1
params["execute_bowtie2_ercc"]=1
params["execute_fastp"]=1
params["execute_hisat2_human"]=1
params["execute_bowtie2_human"]=1
params["execute_kraken2"]=1
params["execute_bracken"]=0
params["execute_normalization"]=0
#If a stage is not executed change the input_path for the next stage accordingly

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
    params["repository_src"]="/home/pablo.viana/jobs/github/aesop-metagenomics-pipeline/src"
    # Location of the dataset data
    params["base_dataset_path"]="/scratch/pablo.viana/aesop/pipeline_v1.0"    
    # Bowtie2 ercc index to remove human reads
    params["bowtie2_ercc_index"]="/scratch/pablo.viana/databases/bowtie2_db/ercc92/ercc_index"
    # Bowtie2 phix index to remove human reads
    params["bowtie2_phix_index"]="/scratch/pablo.viana/databases/bowtie2_db/phix_viralproj14015/phix174_index"
    # HISAT2 human index to remove human reads
    params["hisat2_human_index"]="/scratch/pablo.viana/databases/hisat2_db/human_index_20240725/human_full_hisat2"
    # Bowtie2 human index to remove human reads
    params["bowtie2_human_index"]="/scratch/pablo.viana/databases/bowtie2_db/human_index_20240725/human_full"
    # Kraken2 taxonomic database
    params["kraken2_database"]="/scratch/pablo.viana/databases/kraken2_db/aesop_kraken2db_20240619"
    # Bracken taxonomic estimation database
    params["bracken_database"]="/scratch/pablo.viana/databases/kraken2_db/aesop_kraken2db_20240619"
    # Location of the final report output
    params["final_output_path"]="/opt/storage/shared/aesop/metagenomica/biome/pipeline_v1.0"
    # Location of software executables
    params["BASESPACE_CLI_EXECUTABLE"]="/scratch/pablo.viana/softwares/basespace_illumina/bs"
    params["FASTP_EXECUTABLE"]="/scratch/pablo.viana/softwares/fastp-0.23.2"
    params["HISAT2_EXECUTABLE"]="/scratch/pablo.viana/softwares/hisat2-2.2.1/hisat2"
    params["BOWTIE2_EXECUTABLE"]="/scratch/pablo.viana/softwares/bowtie2-2.5.1-linux-x86_64/bowtie2"
    params["SAMTOOLS_EXECUTABLE"]="/scratch/pablo.viana/softwares/samtools-1.17/bin/samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["BRACKEN_EXECUTABLE"]="/scratch/pablo.viana/softwares/Bracken-master/bracken"
    ;;
  "prometheus")
    params["repository_src"]="/home/work/aesop/github/aesop-metagenomics-pipeline/src"
    params["base_dataset_path"]="/home/work/aesop/pipeline/results/pipeline_v1.0"
    params["bowtie2_ercc_index"]="/home/work/aesop/pipeline/databases/bowtie2_db/ercc92/ercc_index"
    params["bowtie2_phix_index"]="/home/work/aesop/pipeline/databases/bowtie2_db/phix_viralproj14015/phix174_index"
    params["hisat2_human_index"]="/home/work/aesop/pipeline/databases/hisat2_db/human_index_20240725/human_full_hisat2"
    params["bowtie2_human_index"]="/home/work/aesop/pipeline/databases/bowtie2_db/human_index_20240725/human_full"
    params["kraken2_database"]="/home/work/aesop/pipeline/databases/kraken2_db/viruses_without_coronaviridae"
    params["bracken_database"]="/home/work/aesop/pipeline/databases/kraken2_db/viruses_without_coronaviridae"
    params["final_output_path"]="${params[base_dataset_path]}"
    params["BASESPACE_CLI_EXECUTABLE"]="bs"
    params["FASTP_EXECUTABLE"]="fastp"
    params["HISAT2_EXECUTABLE"]="hisat2"
    params["BOWTIE2_EXECUTABLE"]="bowtie2"
    params["SAMTOOLS_EXECUTABLE"]="samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["BRACKEN_EXECUTABLE"]="bracken"
    ;;
  *)
    # Default case if no pattern matches
    echo "Didn't define a valid server"
    exit 1
    ;;
esac

################################################################################
###################### DEFINE STAGES SPECIFIC PARAMETERS #######################
################################################################################
## Download parameters
params["download_input_suffix"]="_L001_R1_001.fastq.gz"
params["download_input_folder"]="0-download"
params["download_output_folder"]="0-raw_samples"
params["download_delete_preexisting_output_folder"]=1
params["download_basespace_access_token"]="$(cat ${params[repository_src]}/../data/basespace_access_token.txt)"
## Bowtie2 remove PHIX parameters
params["bowtie2_phix_nprocesses"]=4
params["bowtie2_phix_process_nthreads"]=15
params["bowtie2_phix_input_suffix"]="_L001_R1_001.fastq.gz"
params["bowtie2_phix_input_folder"]="0-raw_samples"
params["bowtie2_phix_output_folder"]="1.1-bowtie_phix_output"
params["bowtie2_phix_delete_preexisting_output_folder"]=1
## Bowtie2 remove ERCC parameters
params["bowtie2_ercc_nprocesses"]=4
params["bowtie2_ercc_process_nthreads"]=15
params["bowtie2_ercc_input_suffix"]="_1.fastq.gz"
params["bowtie2_ercc_input_folder"]="1.1-bowtie_phix_output"
params["bowtie2_ercc_output_folder"]="1.2-bowtie_ercc_output"
params["bowtie2_ercc_delete_preexisting_output_folder"]=1
## Fastp quality control parameters
params["fastp_nprocesses"]="4"
params["fastp_process_nthreads"]="8"
params["fastp_input_suffix"]="_1.fastq.gz"
params["fastp_input_folder"]="1.2-bowtie_ercc_output"
params["fastp_output_folder"]="1.3-fastp_output"
params["fastp_delete_preexisting_output_folder"]=1
params["fastp_minimum_length"]=50
params["fastp_max_n_count"]=2
## HISAT2 remove HUMAN parameters
params["hisat2_human_nprocesses"]="4"
params["hisat2_human_process_nthreads"]="15"
params["hisat2_human_input_suffix"]="_1.fastq.gz"
params["hisat2_human_input_folder"]="1.3-fastp_output"
params["hisat2_human_output_folder"]="2.1-hisat_human_output"
params["hisat2_human_delete_preexisting_output_folder"]=1
## Bowtie2 remove HUMAN parameters
params["bowtie2_human_nprocesses"]="4"
params["bowtie2_human_process_nthreads"]="15"
params["bowtie2_human_input_suffix"]="_1.fastq.gz"
params["bowtie2_human_input_folder"]="2.1-hisat_human_output"
params["bowtie2_human_output_folder"]="2.2-bowtie_human_output"
params["bowtie2_human_delete_preexisting_output_folder"]=1
## Kraken2 annotation parameters
params["kraken2_nprocesses"]="2"
params["kraken2_process_nthreads"]="30"
params["kraken2_input_suffix"]="_1.fastq.gz"
params["kraken2_input_folder"]="2.2-bowtie_human_output"
params["kraken2_output_folder"]="3-taxonomic_output"
params["kraken2_delete_preexisting_output_folder"]=1
params["kraken2_confidence"]=0
params["kraken2_keep_output"]=0
## Bracken annotation parameters
params["bracken_nprocesses"]="6"
params["bracken_input_suffix"]=".kreport"
params["bracken_input_folder"]="3-taxonomic_output"
params["bracken_output_folder"]="3-taxonomic_output"
params["bracken_delete_preexisting_output_folder"]=0
params["bracken_read_length"]=130
params["bracken_threshold"]=1
## Normalization parameters
params["normalization_input_suffix"]="_1.fastq.gz"
params["normalization_input_folder"]="0-raw_samples"
params["normalization_folders"]="3-taxonomic_output:4-bracken_normalized"
params["normalization_delete_preexisting_output_folder"]=1

################################################################################
####################### DEFINE THE EXECUTION PARAMETERS ########################
################################################################################

# Pipeline script to be executed
pipeline_script=${params["repository_src"]}/pipeline_scripts/pipeline_aesop.sh

# Script that call the pipeline for each dataset
script_for_datasets=${params["repository_src"]}/pipeline_scripts/execute_pipeline_for_datasets.sh

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
################################################################################

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "$sample_datasets"
echo "    $params_str"

$command $script_for_datasets "$pipeline_script" "$sample_datasets" "$params_str"

################################################################################
################################################################################
