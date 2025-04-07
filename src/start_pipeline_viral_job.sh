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
################### DEFINE THE APPROPRIATE COMMAND TO EXECUTE ##################
################################################################################
# Set execution command in singularity docker or local
# Template: singularity exec [SINGULARITY_OPTIONS] <sif> [COMMAND_OPTIONS]
# command="singularity exec /opt/images/cidacs/biome.sif"
# command="singularity exec /opt/images/cidacs/cidacs-jupyter-datascience-v1-r2.sif"
# Local execution
command=""

################################################################################
################# DEFINE THE DATASETS TO EXECUTE THE PIPELINE ##################
################################################################################
# List all datasets and their basepace project ID
# Format MUST BE: [DATASET_NAME]:[BASEPACE_ID]
# If dataset is not from basespace put any number
# If using Illumina basespace EDIT CREDENTIALS in download parameters bellow
# You can execute mutiple datasets at once, commented lines will not be executed
sample_datasets="
                # mao01:123456789
                # ssa01:393298912
                # ssa01_wgs:412407112
                # aju01:398485813
                # rio01:394153669
                # rio02:403173828
                # rio03:414143602
                # rgs01:420835421
                # rgs02:417421287
                # rgs03:419098942
                # bsb01:422858797
                # rio04:423157194
                # rio05:427570404
                # to01:442690473
                mock150bp
                "

################################################################################
############################### ATTENTION !!!!! ################################
###################### DEFINE ANY EXECUTION PARAMETER HERE #####################
################################################################################
# Define the dictionary variable for the parameters
declare -A params

# 0 = DONT EXECUTE STAGE | 1 = EXECUTE STAGE
# params["execute_download"]=0
# params["execute_bowtie2_phix"]=1
# params["execute_bowtie2_ercc"]=1
# params["execute_fastp"]=1
# params["execute_hisat2_human"]=1
# params["execute_bowtie2_human"]=1
params["execute_kraken2"]=1
params["execute_extract_reads"]=1
params["execute_assembly_metaspades"]=1
params["execute_mapping_metaspades"]=1
params["execute_blastn"]=1
params["execute_tabulate_blastn"]=1
params["execute_filter_contigs_blastn"]=1
params["execute_diamond"]=1
params["execute_tabulate_diamond_fast"]=1
params["execute_tabulate_diamond_fast_sensitive"]=1

## DEFINE STAGES EXTRA PARAMETERS
# unclassified_entries = "2787823"
# artificial_sequences = "81077"
# Homo sapiens = "9606"
# viruses="10239"
# coronaviridae = "11118"
# betacoronavirus = "694002"
# sars_cov = "694009"
# alphainfluenzavirus = "197911"
# enterovirus = "12059"
# orthoflavivirus = "3044782"
filter_taxons="2787823,81077,9606,694002"

## Blastn viral parameters
params["blastn_filter_taxon"]="betacoronavirus.txt"
# params["blastn_filter_taxon"]="$filter_taxons"
## Diamond viral parameters
params["diamond_filter_taxon"]="$filter_taxons"
## Diamond sensitive viral parameters
# params["diamond_sensitive_filter_taxon"]="$filter_taxons"

# Project repository path
params["repository_src"]="/home/pedro/aesop/github/aesop-metagenomics-pipeline/src"
# Script that call the pipeline for each dataset
script_for_datasets="${params[repository_src]}/pipeline_scripts/execute_pipeline_for_datasets.sh"
# Pipeline script to be executed
pipeline_script="${params[repository_src]}/pipeline_scripts/pipeline_viruses.sh"
# Parameters JSON file
json_file="${params[repository_src]}/pipeline_scripts/pipeline_viruses.json"

################################################################################
############################# LOAD PARAMETERS JSON #############################
################################################################################

# 1) Generate all scalar paths (including nested objects and arrays)
#    Then flatten each path into a dot-notation string, e.g. "nested1.sub1.key1"
#    Example: '["nested1","sub1","key1"]' → "nested1.sub1.key1"
while IFS= read -r path; do
  # 2) Use that path to extract the actual value with 'jq'
  value=$(jq -r ".${path}" "$json_file")
  # 3) Convert dots (and array indices) in the path to underscores
  #    e.g. "nested1.sub1.key1" → "nested1_sub1_key1"
  new_key=$(echo "$path" | tr '.' '_')
  # 4) Assign into the Bash array
  params["$new_key"]="$value"
done < <(jq -r 'paths(scalars) | join(".")' "$json_file")

################################################################################
###################### CONVERTING PARAMETERS TO A STRING #######################
################################################################################

# ARGUMENTS
# Initialize an empty string to hold the parameters as a string
params_str=""
# Iterate over the dictionary and build the string
for key in "${!params[@]}"; do
  value=${params[$key]}
  params_str+="$key=$value|"
done
# Remove trailing | if present
params_str=${params_str%|}

# DATASETS
# Trim all lines, then filter out comments and empty lines
sample_datasets=$(echo "$sample_datasets" | \
                  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
                  grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#')

################################################################################
####################### DEFINE THE EXECUTION PARAMETERS ########################
################################################################################

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "    $params_str"
echo "$sample_datasets"

$command $script_for_datasets "$pipeline_script" "$params_str" "$sample_datasets"

################################################################################
################################################################################
