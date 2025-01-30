#!/bin/bash

# Variables
FASTA_FILE="viruses_removed_betacoronavirus.fasta"
BLAST_DB_NAME="viruses_no_betacoronavirus_blast_db"
RAMDISK_DIR="/dev/shm/viruses_no_betacoronavirus"
OUTPUT_DIR="/home/pedro/aesop/pipeline/databases/blastn_db"

# Create the RAM disk directory
mkdir -p "$RAMDISK_DIR"

# Copy the FASTA file to the RAM disk
cp "$FASTA_FILE" "$RAMDISK_DIR"
cp taxid_map.txt "$RAMDISK_DIR"

# Change to the RAM disk directory
cd "$RAMDISK_DIR"

# Create the BLAST database
makeblastdb -in "$FASTA_FILE" -dbtype nucl -parse_seqids -taxid_map taxid_map.txt -out "$BLAST_DB_NAME" -title "Viral Database without Betacoronavirus"

# Remove the original FASTA file
rm -rf "$FASTA_FILE"

# Copy the resulting BLAST database files back to the output directory
cp -r "$RAMDISK_DIR" "$OUTPUT_DIR"

echo "BLAST database creation complete and files copied to $OUTPUT_DIR."
