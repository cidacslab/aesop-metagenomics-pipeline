#!/bin/bash

BIOPROJECT="PRJNA540900"
FASTQ_PATH="/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_paper1/0-raw_samples"

# 2.1: Query SRA for all runs in that BioProject, then get runinfo CSV:
esearch -db sra -query "$BIOPROJECT" \
  | efetch -format runinfo \
  > ${BIOPROJECT}_runinfo.csv

cut -d',' -f1 < ${BIOPROJECT}_runinfo.csv | sed 1d > ${BIOPROJECT}_SRR_list.txt

# 3.A.1: Make a folder to hold all FASTQ outputs
LOCAL_PATH=$(pwd)
mkdir -p ${FASTQ_PATH}
cd ${FASTQ_PATH}

# 3.A.2: Loop over every SRR in your list
while read SRR; do
  echo "=== Downloading $SRR ==="
  # create *_1.fastq and *_2.fastq for paired-end runs
  # adjust to how many cores you want to use
  # save in current directory
  prefetch $SRR
  fasterq-dump --threads 8 --skip-technical --outdir . --split-files $SRR
done < $LOCAL_PATH/${BIOPROJECT}_SRR_list.txt

