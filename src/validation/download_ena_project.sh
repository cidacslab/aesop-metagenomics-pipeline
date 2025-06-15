#!/bin/bash

JOBS=2
PROJECT="PRJEB74559"
FASTQ_PATH="/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_paper2/0-raw_samples"


echo "=== Downloading $PROJECT ==="
curl -s "https://www.ebi.ac.uk/ena/portal/api/search?result=read_run&query=study_accession=${PROJECT}&fields=run_accession,fastq_ftp,fastq_aspera,fastq_md5,fastq_bytes&format=tsv" > ${PROJECT}_ena_runinfo.tsv


echo "=== Collecting FASTQ URL LIST ==="
# Skip the header (first line), then print field 2 (the FTP path)
awk 'BEGIN {FS="\t"} NR>1 { print $2 }' ${PROJECT}_ena_runinfo.tsv | \
  tr ';' '\n' > ${PROJECT}_fastq_ftp_list.txt

# Create a directory to hold FASTQs
LOCAL_PATH=$(pwd)
mkdir -p ${FASTQ_PATH}
cd ${FASTQ_PATH}

echo "=== Downloading FASTQs ==="
# ‣ Build a stream of FTP URLs and pipe them to xargs
sed 's|^|ftp://|' $LOCAL_PATH/${PROJECT}_fastq_ftp_list.txt | \
  xargs -n 1 -P $JOBS wget -nv -c -P . 


# # Then download everything with ascp (preserving filenames):
# while read -r aspera_line; do
#   # aspera_line starts with "aspera#era-fasp@fasp.sra.ebi.ac.uk:/path/to/fastq"
#   # Convert `aspera#` to straight `ascp ` invocation
#   URL=${aspera_line#aspera#}
#   ascp -QT -l 100m -P33001 -i /path/to/asperaweb_id_dsa.openssh "$URL" .
# done < ${PROJECT}_fastq_aspera_list.txt