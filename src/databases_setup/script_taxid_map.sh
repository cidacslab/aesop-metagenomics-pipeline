#!/bin/bash

# create alias to echo command to log time at each call
echo() {
    command echo "B_PID: $BASHPID [$(date +"%Y-%m-%dT%H:%M:%S%z")]: $@"
}

# Start profiling
start=$(date +%s.%N)
echo "Started Executing taxid_map script!"

# Define filenames as variables
# project_fullpath="/home/pedro/aesop/github/aesop-metagenomics-pipeline"

# taxid_map="taxid_map"
# missing_accessions="missing_accessions"
# final_taxid_map_file="final_taxid_map.txt"
# file="SI035"
file="SI041_1"
taxid_map="taxid_map_${file}"
missing_accessions="missing_accessions_${file}"
final_taxid_map_file="${file}.txt"

genome_accessions_file="${file}.tsv"
# viral_genomes_file="complete_genome_viruses.fasta"
# genome_accessions_file="viral_genome_accessions.txt"
# genome_accessions_file="../composition/SI035.tsv"

# echo "Getting all accessions of downloaded genomes..."
# grep ">" "$viral_genomes_file" | sed 's/>//' > "$genome_accessions_file"
echo "Checking for duplicated lines in ${genome_accessions_file}, if any appears it will be printed:"
awk '{count[$1]++} END {for (acc in count) if (count[acc] > 1) print acc, count[acc]}' "$genome_accessions_file"

# Initialize taxid map file
>"$final_taxid_map_file"

accession2taxid_files=( "nucl_gb" "dead_nucl" "nucl_wgs" )
# accession2taxid_files=( "dead_nucl" )

for file in "${accession2taxid_files[@]}"; do
  accession_map_file="${file}.accession2taxid.gz"
  # Initialize taxid map file
  taxid_map_file="${taxid_map}_from_${file}.txt"
  missing_accessions_file="${missing_accessions}_from_${file}.txt"
  >"$taxid_map_file"
  
  # # Download GenBank nucleotide accessions
  # echo "Downloading all genbank nucleotide accessions..."
  # wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/accession2taxid/$accession_map_file
  
  # echo "Checking for duplicated lines in ${accession_map_file}, if any appears it will be printed:"
  # zcat $accession_map_file | awk '{count[$1]++} END {for (acc in count) if (count[acc] > 1) print acc, count[acc]}'
  
  echo ""
  # Count the number of lines (elements) in the file
  num_elements=$(wc -l < "$genome_accessions_file")
  echo "Looking for ${num_elements} accession from file ${genome_accessions_file} in the ${accession_map_file}"
  zcat $accession_map_file | awk '
  NR==FNR {
    k1 = $1
    sub(/\.[0-9]+$/, "", k1); # Normalize accessions in the first file
    acc[k1] = $1; # Store the original accession
    next
  }
  {
    if ($1 in acc) {
      print acc[$1] " " $3 > "'"$taxid_map_file"'"; # Write to file with a tab separator
      delete acc[$1]; # Remove matched accession
      if (length(acc) == 0) {
        print "Found all accessions. Exiting..." > "'"/dev/stdout"'";
        exit 0;
      }
    }
  }
  END {
    for (k in acc) print acc[k] > "'"$missing_accessions_file"'"; # Output unmatched accessions
  }' "$genome_accessions_file" -
  
  num_elements=$(wc -l < "$taxid_map_file")
  echo "Adding ${num_elements} taxids found to final mapping file ${final_taxid_map_file}!"
  cat $taxid_map_file >> $final_taxid_map_file
  
  # Check if the file exists
  if [ ! -f "$missing_accessions_file" ]; then
    echo "All accessions were mapped correctly!"
    break
  else
    # Count the number of lines (elements) in the file
    num_elements=$(wc -l < "$missing_accessions_file")
    echo "The ${num_elements} missing accessions were stored in file ${missing_accessions_file}!"
    genome_accessions_file="$missing_accessions_file"
  fi  
done

# Finish script profile
finish=$(date +%s.%N)
runtime=$(awk -v a=$finish -v b=$start 'BEGIN{printf "%.3f", (a-b)}')
echo "Finished script! Total elapsed time: ${runtime} s."
