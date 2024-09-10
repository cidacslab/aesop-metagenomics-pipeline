#!/bin/bash
################################################################################
#################################  BEGIN JOB  ##################################
################################################################################
#SBATCH --job-name='AESOP JOB'                        # Job name
#SBATCH --partition=cpu_iterativo                     # CPU batch queue
#SBATCH --nodes=1                                     # Maxinum amount of nodes
#SBATCH --cpus-per-task=40                            # Maxinum amount of cores
#SBATCH --mem=1024GB                                  # Maxinum amount of memory
#SBATCH --time=999:00:00                              # Time limit hrs:min:sec
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
################################################################################
# Variable to iclude the parameters
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
######################### SELECT THE SERVER LOCATIONS ##########################
################################################################################
# Location where to execute the pipeline
server="hpc"
# server="prometheus"

# Set the server locations, paths MUST NOT have spaces
# ADD NEW SERVER HERE IF NEEDED
case $server in
  "hpc")
    # Location of src folder in the github directory
    params["repository_src"]="/home/pablo.viana/metagenomic_pipeline_src"
    # Location of the dataset data
    params["base_dataset_path"]="/scratch/pablo.viana/aesop/pipeline_v9"
    # HISAT2 index to remove human reads
    params["hisat2_human_index"]="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/human_telomere/human_telomere"
    # Bowtie2 index to remove human reads
    params["bowtie2_human_index"]="/scratch/pablo.viana/databases/kraken_db/czid_kraken2db_20240626/human_telomere/human_telomere"
    # Kraken2 taxonomic database
    params["kraken2_database"]="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"
    # Bracken taxonomic estimation database
    params["bracken_database"]="/scratch/pablo.viana/databases/kraken_db/aesop_kraken2db_20240619"
    # Location of the final report output
    params["final_output_path"]="/opt/storage/shared/aesop/metagenomica/biome/pipeline_v4_mock"
    ;;
  "prometheus")
    params["repository_src"]="/home/work/aesop/metagenomic_pipeline_src"
    params["base_dataset_path"]="/home/work/aesop/results_pipeline_v4"
    params["hisat2_human_index"]="/home/work/aesop/czid_bowtie2db_20240626/ercc/ercc"
    params["bowtie2_human_index"]="/home/work/aesop/czid_bowtie2db_20240626/human_telomere/human_telomere"
    params["kraken2_database"]="/home/work/aesop/aesop_kraken2db_20240619"
    params["final_output_path"]="$base_dataset_path"
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
# Number os parallel processes to be executed
params["num_processes"]=1
### Download parameters
params["download_input_suffix"]=".fastq.gz"
params["download_input_path"]="0/download"
### Bowtie2 remove PHIX parameters
### Bowtie2 remove ERCC parameters
# params["bowtie_ercc_input_suffix"]="_L001_R1_001.fastq.gz"
# params["bowtie2_ercc_input_suffix"]="_150_reads_R1.fastq"
### Fastp quality control parameters
# params["fastp_input_suffix"]="_L001_R1_001.fastq.gz"
params["fastp_input_suffix"]="_1.fastq"
### HISAT2 remove HUMAN parameters
### Bowtie2 remove HUMAN parameters
params["bowtie2_host_input_suffix"]="_1.fastq"
### Kraken2 annotation parameters
params["kraken2_input_suffix"]="_1.fastq"
### Bracken annotation parameters
params["bracken_input_suffix"]="_1.fastq"
# params["bracken_folders"]="3-kraken_results:4-bracken_results;"
params["bracken_folders"]="3-kraken_czid_results:4-bracken_czid_results"
params["bracken_read_length"]=130
params["bracken_threshold"]=1
### Normalization parameters
params["normalization_input_suffix"]="_1.fastq"
params["normalization_input_folder"]="1-bowtie_ercc_output"
# params["normalization_folders"]="3-kraken_results:5-kraken_reports;4-bracken_results:6-bracken_reports"
# params["normalization_folders"]+=";3-kraken_czid_results:5-kraken_czid_reports;"
params["normalization_folders"]="4-bracken_czid_results:6-bracken_czid_reports"

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
pipeline_script="${params["repository_src"]}/pipeline_scripts/paper_pipeline.sh"

# Script that call the pipeline for each dataset
script_for_datasets="${params["repository_src"]}/pipeline_scripts/execute_pipeline_for_datasets.sh"

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
