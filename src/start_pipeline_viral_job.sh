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
                mock2
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
# params["execute_download"]=1
# params["execute_fastp"]=1
# params["execute_bowtie2_phix"]=1
# params["execute_bowtie2_ercc"]=1
# params["execute_hisat2_human"]=1
# params["execute_bowtie2_human"]=1
# params["execute_kraken2"]=1
# params["execute_extract_reads"]=1
# params["execute_assembly_metaspades"]=1
# params["execute_mapping_metaspades"]=1
# params["execute_blastn"]=1
# params["execute_calculate_matrix"]=1
# params["execute_filter_contigs"]=1
# params["execute_diamond"]=1
params["execute_diamond_matrix"]=1
#If a stage is not executed change the input_path for the next stage accordingly

################################################################################
######################### DEFINE THE SERVER LOCATIONS ##########################
################################################################################
# Location where to execute the pipeline
# server="hpc"
server="prometheus"

# Set the server locations, paths MUST NOT have spaces
# ADD NEW SERVER HERE IF NEEDED
case $server in
  "hpc")
    # Location of src folder in the github directory
    params["repository_src"]="/home/pablo.viana/jobs/github/aesop-metagenomics-pipeline/src"
    # Location of the dataset data
    params["initial_dataset_path"]="/scratch/pablo.viana/aesop/pipeline_v1.0"
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
    # Blast viral database
    params["blastn_viral_index"]="/scratch/pablo.viana/databases/blastn_db/viral_genomes/complete_viral_blastdb"
    # Taxon kit db
    params["taxonkit_database"]="/scratch/pablo.viana/databases/taxonkit_db"
    # Location of the final report output
    params["final_output_path"]="/opt/storage/shared/aesop/metagenomica/biome/pipeline_v1.0"
    # Location of software executables
    params["BASESPACE_CLI_EXECUTABLE"]="/scratch/pablo.viana/softwares/basespace_illumina/bs"
    params["FASTP_EXECUTABLE"]="/scratch/pablo.viana/softwares/fastp-0.23.2"
    params["HISAT2_EXECUTABLE"]="/scratch/pablo.viana/softwares/hisat2-2.2.1/hisat2"
    params["BOWTIE2_EXECUTABLE"]="/scratch/pablo.viana/softwares/bowtie2-2.5.1-linux-x86_64/bowtie2"
    params["BOWTIE2_BUILD_EXECUTABLE"]="/scratch/pablo.viana/softwares/bowtie2-2.5.1-linux-x86_64/bowtie2-build"
    params["SAMTOOLS_EXECUTABLE"]="/scratch/pablo.viana/softwares/samtools-1.17/bin/samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["BRACKEN_EXECUTABLE"]="/scratch/pablo.viana/softwares/Bracken-master/bracken"
    params["EXTRACT_READS_EXECUTABLE"]="/scratch/pablo.viana/softwares/KrakenTools-1.2/extract_kraken_reads.py"
    params["BLASTN_EXECUTABLE"]="/scratch/pablo.viana/softwares/ncbi-blast-2.14.0+/bin/blastn"
    params["SPADES_EXECUTABLE"]="/scratch/pablo.viana/softwares/SPAdes-4.0.0-Linux/bin/spades.py"
    ;;
  "prometheus")
    params["repository_src"]="/home/pedro/aesop/github/aesop-metagenomics-pipeline/src"
    params["initial_dataset_path"]="/home/pedro/aesop/pipeline/results/viral_discovery_v1"
    params["base_dataset_path"]="/home/pedro/aesop/pipeline/results/viral_discovery_v1"
    params["bowtie2_ercc_index"]="/home/pedro/aesop/pipeline/databases/bowtie2_db/ercc92/ercc_index"
    params["bowtie2_phix_index"]="/home/pedro/aesop/pipeline/databases/bowtie2_db/phix_viralproj14015/phix174_index"
    params["hisat2_human_index"]="/home/pedro/aesop/pipeline/databases/hisat2_db/human_index_20240725/human_full_hisat2"
    params["bowtie2_human_index"]="/home/pedro/aesop/pipeline/databases/bowtie2_db/human_index_20240725/human_full"
    params["taxonomy_database"]="/home/pedro/aesop/pipeline/databases/taxdump"
    params["kraken2_database"]="/home/pedro/aesop/pipeline/databases/kraken2_db/viruses_without_coronaviridae"
    # params["bracken_database"]="/home/pedro/aesop/pipeline/databases/kraken2_db/viruses_without_coronaviridae"
    # params["kraken2_database"]="/home/pedro/aesop/pipeline/databases/kraken2_db/viruses_complete"
    params["blastn_database"]="/home/pedro/aesop/pipeline/databases/blastn_db/viruses_no_coronaviridae/viruses_no_coronaviridae_blast_db"
    # params["blastn_database"]="/home/pedro/aesop/pipeline/databases/viral_blastn_db/viral_database"
    # params["diamond_database"]="/home/pedro/aesop/pipeline/databases/blastp_db/nr.dmnd"
    params["diamond_database"]="/home/pedro/pablo/aesop/database_files/ncbi_nr_20250205/nr.dmnd"
    params["final_output_path"]="${params[base_dataset_path]}"
    params["BASESPACE_CLI_EXECUTABLE"]="bs"
    params["FASTP_EXECUTABLE"]="fastp"
    params["HISAT2_EXECUTABLE"]="hisat2"
    params["BOWTIE2_EXECUTABLE"]="bowtie2"
    params["BOWTIE2_BUILD_EXECUTABLE"]="bowtie2-build"
    params["SAMTOOLS_EXECUTABLE"]="samtools"
    params["KRAKEN2_EXECUTABLE"]="kraken2"
    params["EXTRACT_READS_EXECUTABLE"]="/home/pedro/aesop/github/KrakenTools-1.2/extract_kraken_reads.py"
    params["SPADES_EXECUTABLE"]="spades.py"
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
###################### DEFINE STAGES SPECIFIC PARAMETERS #######################
################################################################################
## Download parameters
params["download_nprocesses"]=1
params["download_process_nthreads"]=1
params["download_input_suffix"]=".fastq.gz"
params["download_input_folder"]="0-download"
params["download_output_folder"]="0-raw_samples"
params["download_delete_preexisting_output_folder"]=1
params["download_log_file"]="0-raw_samples_download_logs.tar.gz"
params["download_basespace_access_token"]="xxxxx"
# params["download_basespace_access_token"]="$(cat ${params[repository_src]}/../data/basespace_access_token.txt)"
## Bowtie2 remove PHIX parameters
params["bowtie2_phix_nprocesses"]=4
params["bowtie2_phix_process_nthreads"]=15
params["bowtie2_phix_input_suffix"]="_R1.fastq.gz"
params["bowtie2_phix_input_folder"]="0-raw_samples"
params["bowtie2_phix_output_folder"]="1.1-bowtie_phix_output"
params["bowtie2_phix_delete_preexisting_output_folder"]=1
params["bowtie2_phix_log_file"]="1.1-sample_decontamination-bowtie2_remove_phix_reads_logs.tar.gz"
## Bowtie2 remove ERCC parameters
params["bowtie2_ercc_nprocesses"]=4
params["bowtie2_ercc_process_nthreads"]=15
params["bowtie2_ercc_input_suffix"]="_1.fastq.gz"
params["bowtie2_ercc_input_folder"]="1.1-bowtie_phix_output"
params["bowtie2_ercc_output_folder"]="1.2-bowtie_ercc_output"
params["bowtie2_ercc_delete_preexisting_output_folder"]=1
params["bowtie2_ercc_log_file"]="1.2-sample_decontamination-bowtie2_remove_ercc_reads_logs.tar.gz"
## Fastp quality control parameters
params["fastp_nprocesses"]=4
params["fastp_process_nthreads"]=8
params["fastp_input_suffix"]="_1.fastq.gz"
params["fastp_input_folder"]="1.2-bowtie_ercc_output"
params["fastp_output_folder"]="1.3-fastp_output"
params["fastp_delete_preexisting_output_folder"]=1
params["fastp_log_file"]="1.3-quality_control-fastp_filters_logs.tar.gz"
params["fastp_minimum_length"]=50
params["fastp_max_n_count"]=2
## HISAT2 remove HUMAN parameters
params["hisat2_human_nprocesses"]=4
params["hisat2_human_process_nthreads"]=15
params["hisat2_human_input_suffix"]="_1.fastq.gz"
params["hisat2_human_input_folder"]="1.3-fastp_output"
params["hisat2_human_output_folder"]="2.1-hisat_human_output"
params["hisat2_human_delete_preexisting_output_folder"]=1
params["hisat2_human_log_file"]="2.1-sample_decontamination-hisat2_remove_human_reads_logs.tar.gz"
## Bowtie2 remove HUMAN parameters
params["bowtie2_human_nprocesses"]=4
params["bowtie2_human_process_nthreads"]=15
params["bowtie2_human_input_suffix"]="_1.fastq.gz"
params["bowtie2_human_input_folder"]="2.1-hisat_human_output"
params["bowtie2_human_output_folder"]="2.2-bowtie_human_output"
params["bowtie2_human_delete_preexisting_output_folder"]=1
params["bowtie2_human_log_file"]="2.2-sample_decontamination-bowtie2_remove_human_reads_logs.tar.gz"
## Kraken2 annotation parameters
params["kraken2_nprocesses"]=1
params["kraken2_process_nthreads"]=20
params["kraken2_input_suffix"]="_1.fastq.gz"
params["kraken2_input_folder"]="2.2-bowtie_human_output"
params["kraken2_output_folder"]="3-taxonomic_output"
params["kraken2_delete_preexisting_output_folder"]=1
params["kraken2_log_file"]="3-taxonomic_annotation-kraken_logs.tar.gz"
params["kraken2_confidence"]=0
params["kraken2_keep_output"]=1
## Extract viral reads parameters
params["extract_reads_nprocesses"]=8
params["extract_reads_process_nthreads"]=1
params["extract_reads_input_suffix"]="_1.fastq.gz"
params["extract_reads_input_folder"]="2.2-bowtie_human_output"
params["extract_reads_output_folder"]="4.1-viral_discovery_reads"
params["extract_reads_delete_preexisting_output_folder"]=1
params["extract_reads_log_file"]="4.1-viral_discovery-extract_reads_logs.tar.gz"
params["extract_reads_kraken_output"]="3-taxonomic_output"
params["extract_reads_from_taxons"]="0,10239"
## Assembly metaspades parameters
params["assembly_metaspades_nprocesses"]=2
params["assembly_metaspades_process_nthreads"]=30
params["assembly_metaspades_input_suffix"]="_1.fastq.gz"
params["assembly_metaspades_input_folder"]="4.1-viral_discovery_reads"
params["assembly_metaspades_output_folder"]="4.3-viral_discovery_contigs_metaspades"
params["assembly_metaspades_delete_preexisting_output_folder"]=1
params["assembly_metaspades_log_file"]="4.3-viral_discovery-assembly_metaspades_logs.tar.gz"
## Mapping metaspades parameters
params["mapping_metaspades_nprocesses"]=2
params["mapping_metaspades_process_nthreads"]=30
params["mapping_metaspades_input_suffix"]=".contigs.fa"
params["mapping_metaspades_input_folder"]="4.3-viral_discovery_contigs_metaspades"
params["mapping_metaspades_output_folder"]="4.3.1-viral_discovery_mapping_metaspades"
params["mapping_metaspades_delete_preexisting_output_folder"]=1
params["mapping_metaspades_log_file"]="4.3.1-viral_discovery-mapping_metaspades_logs.tar.gz"
params["mapping_metaspades_origin_input_suffix"]="_1.fastq.gz"
params["mapping_metaspades_origin_input_folder"]="4.1-viral_discovery_reads"
## Blastn viral parameters
params["blastn_nprocesses"]=2
params["blastn_process_nthreads"]=30
params["blastn_input_suffix"]=".contigs.fa"
params["blastn_input_folder"]="4.3-viral_discovery_contigs_metaspades"
params["blastn_output_folder"]="4.3.2-blastn_contigs_metaspades"
params["blastn_delete_preexisting_output_folder"]=1
params["blastn_log_file"]="4.3.2-taxonomic_annotation-blastn_contigs_metaspades_logs.tar.gz"
params["blastn_task"]="megablast"
params["blastn_filter_taxon"]="coronaviridae.txt"
## Filter contigs parameters
params["calculate_matrix_nprocesses"]=1
params["calculate_matrix_process_nthreads"]=1
params["calculate_matrix_input_suffix"]=".txt"
params["calculate_matrix_input_folder"]="4.3.2-blastn_contigs_metaspades"
params["calculate_matrix_output_folder"]="4.3.3-tabulated_result_blastn"
params["calculate_matrix_delete_preexisting_output_folder"]=1
params["calculate_matrix_log_file"]="4.3.3-tabulated_result_blastn_logs.tar.gz"
## Filter contigs parameters
params["filter_contigs_nprocesses"]=1
params["filter_contigs_process_nthreads"]=1
params["filter_contigs_input_suffix"]="_contig_not_matched_blast.tsv"
params["filter_contigs_input_folder"]="4.3.3-tabulated_result_blastn"
params["filter_contigs_output_folder"]="5-filtered_contigs_blastn"
params["filter_contigs_delete_preexisting_output_folder"]=1
params["filter_contigs_log_file"]="5-contigs_not_matched_blast_logs.tar.gz"
params["filter_contigs_folder"]="4.3-viral_discovery_contigs_metaspades"
params["filter_contigs_extension"]=".contigs.fa"
## Diamond viral parameters
params["diamond_nprocesses"]=1
params["diamond_process_nthreads"]=30
params["diamond_input_suffix"]=".contigs.fa"
params["diamond_input_folder"]="5-filtered_contigs_blastn"
params["diamond_output_folder"]="5.2-filtered_contigs_diamond_sensitive"
params["diamond_delete_preexisting_output_folder"]=1
params["diamond_log_file"]="5.2-filtered_contigs_diamond_logs.tar.gz"
params["diamond_sensitivity"]="--sensitive" # --fast  --sensitive  --ultra-sensitive
params["diamond_filter_taxon"]="2787823,81077,9606,11118"
# Homo sapiens = "9606"
# unclassified_entries = "2787823"
# artificial_sequences = "81077"
# coronaviridae = "11118"
# betacoronavirus = "694002"
# sars_cov = "694009"
# alphainfluenzavirus = "197911"
# enterovirus = "12059"
# orthoflavivirus = "3044782"
## Diamond confusion matrix
params["diamond_matrix_nprocesses"]=1
params["diamond_matrix_process_nthreads"]=1
params["diamond_matrix_input_suffix"]=".txt"
params["diamond_matrix_input_folder"]="5.2-filtered_contigs_diamond_sensitive"
params["diamond_matrix_output_folder"]="5.2.1-tabulated_result_diamond_sensitive"
params["diamond_matrix_delete_preexisting_output_folder"]=1
params["diamond_matrix_log_file"]="5.2.1-tabulated_result_diamond_logs.tar.gz"
params["diamond_matrix_metadata_path"]="${params[repository_src]}/../data/dataset_mock/metadata"
params["diamond_matrix_contigs_folder"]="5-filtered_contigs_blastn"
params["diamond_matrix_mapping_folder"]="4.3.1-viral_discovery_mapping_metaspades"
params["diamond_matrix_align_identity"]="80"
params["diamond_matrix_align_length"]="30"
params["diamond_matrix_align_evalue"]="0.001"

################################################################################
####################### DEFINE THE EXECUTION PARAMETERS ########################
################################################################################

# Pipeline script to be executed
pipeline_script=${params["repository_src"]}/pipeline_scripts/pipeline_viruses.sh

# Script that call the pipeline for each dataset
script_for_datasets=${params["repository_src"]}/pipeline_scripts/execute_pipeline_for_datasets.sh

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
################################################################################

echo "Execution command:" 
echo "    $command $script_for_datasets $pipeline_script"
echo "    $params_str"
echo "$sample_datasets"

$command $script_for_datasets "$pipeline_script" "$params_str" "$sample_datasets"

################################################################################
################################################################################
