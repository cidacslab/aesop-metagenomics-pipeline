#!/bin/bash


awk 'NR==FNR {exclude[$1]; next} !($3 in exclude)' /home/pedro/aesop/pipeline/databases/taxdump/taxids_by_taxons/enterovirus.txt \
    prelim_map_viruses_complte.txt > prelim_map.txt



grep -F -f /home/pedro/aesop/pipeline/databases/taxdump/taxids_by_taxons/enterovirus.txt prelim_map_viruses_complte.txt



 nohup kraken2-build --threads 32 --db aesop_k2db_20250207 --build &> kraken_build_entero.log &



#  awk -F'\t' 'FNR==1{delete seen; first=1} /^#/ {next} !seen[$1]++&&(($3+0)<97||($4+0)<100||($5+0)<90){if(first){print "###   " FILENAME "   ==============================="; first=0} print}' 4.3.2-blastn_contigs_metaspades/CST1_FLU_1_*