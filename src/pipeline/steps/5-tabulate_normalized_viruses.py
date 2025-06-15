import os, sys, csv, copy
from datetime import datetime, timezone
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")
sys.path.append("/mnt/c/Users/pablo/Documents/github/aesop-metagenomics-pipeline/src")

import utilities.normalize_classified_matches as ClassifiedMatches
import utilities.taxonomy_tree_parser as TaxonomyParser


def tabulate_known_viruses(classified_tree, input_count_reads_path, count_reads_extension,
      input_mapping_path, align_filters, input_alignment_path, input_kraken_path,
      kraken_folder, filename, output_path):
  """
  Tabulates known viruses by creating a ground truth tree from mock data, setting up
  confusion matrices for BLAST and Kraken classification results.
  Parameters:
    classified_tree: The taxonomy tree used for classification results.
    input_count_reads_path: Path to the directory containing count reads files.
    count_reads_extension: File extension for count reads files.
    input_mapping_path: Path to the directory containing mapping files.
    align_filters: Filters for alignment results (e.g., coverage, identity).
    input_alignment_path: Path to the directory containing alignment result files.
    input_kraken_path: Path to the directory containing Kraken result files.
    kraken_folder: The folder containing Kraken results.
    filename: The base filename for input and output files.
    output_path: Path to the directory where output files will be saved.
  Processes:
  1. Loads the count read file to determine read abudance and contig abundance.
  2. Sets up the alignment normalization by loading the alignment result, applying alignment filters, and performing the calculation.
  3. If provided, sets up the Kraken normalization by loading the Kraken result and performing the calculation.
  """
  #######################################################################################################
  # GET READ COUNTS
  # contig to reads files  
  count_reads_file = os.path.join(input_count_reads_path, filename + count_reads_extension)
  mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
  # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
  total_abundance, contig_read_count, mapped_reads = ClassifiedMatches.load_read_count( 
    count_reads_file, count_reads_extension, mapping_file)
  
  #######################################################################################################
  # GET ALIGNMENT NORMALIZATION
  # alignment files
  alignment_file = os.path.join(input_blast_path, filename + ".txt")
  output_unmatches_file = os.path.join(output_path, filename + "_contig_unmatched_alignment.csv")
  output_matches_file = os.path.join(output_path, filename + "_contig_matched_alignment.csv")
  # load alignment tree
  ClassifiedMatches.load_alignment_tree(classified_tree, contig_read_count, 
    alignment_file, align_filters, output_unmatches_file, output_matches_file)
  # Calculate normalization for alignment results
  output_file = os.path.join(output_path, filename + "_alignment_report.csv")
  ClassifiedMatches.normalize_classified_matches(total_abundance, classified_tree, output_file)
  
  #######################################################################################################
  # GET KRAKEN NORMALIZATION
  if kraken_folder != "":
    # get kraken result for unmapped reads (the ones didn't form contigs)
    kout_file = os.path.join(input_kraken_path, filename + ".kout")
    ClassifiedMatches.include_k2result_for_unmatched(classified_tree, mapped_reads, kout_file)
    # Calculate normalization for alignment + kraken unmatched results (all known viruses)
    output_file = os.path.join(output_path, filename + "_known_viruses_report.csv")
    ClassifiedMatches.normalize_classified_matches(total_abundance, classified_tree, output_file)
    
    # load kraken tree
    kreport_file = os.path.join(input_kraken_path, filename + ".kreport")
    ClassifiedMatches.load_kraken_tree(classified_tree, kreport_file)
    # Calculate normalization for kraken results
    output_file = os.path.join(output_path, filename + "_kraken_report.csv")
    ClassifiedMatches.normalize_classified_matches(total_abundance, classified_tree, output_file)



def main():  
  # count=$1
  input_file = sys.argv[2]
  input_suffix = sys.argv[3]
  input_dir = sys.argv[4]
  output_dir = sys.argv[5]
  # nthreads=$6 
  align_coverage = float(sys.argv[7])
  align_identity = float(sys.argv[8])
  align_length = float(sys.argv[9])
  align_evalue = float(sys.argv[10])
  taxonomy_database = sys.argv[11]
  base_path = sys.argv[12]
  metadata_path = sys.argv[13]
  count_reads_folder = sys.argv[14]
  count_reads_extension = sys.argv[15]
  mapping_folder = sys.argv[16] if len(sys.argv) > 16 else ""
  kraken_folder = sys.argv[17] if len(sys.argv) > 17 else ""
  print(f"Parameters: {sys.argv}")
  
  input_count_reads_path = os.path.join(base_path, count_reads_folder)
  input_mapping_path = os.path.join(base_path, mapping_folder)
  input_kraken_path = os.path.join(base_path, kraken_folder)
  input_blast_path = input_dir
  align_filters = {
    "length": align_length, "identity": align_identity, 
    "coverage": align_coverage, "evalue": align_evalue }
  
  # Create the folder to place the output if it doesn't exist
  output_path = output_dir
  os.makedirs(output_path, exist_ok=True)
  
  ########################################################################################################
  # Load complete taxonomy tree
  names_file = os.path.join(taxonomy_database, "names.dmp")
  nodes_file = os.path.join(taxonomy_database, "nodes.dmp")
  _, taxonomy_tree = TaxonomyParser.load_tree_from_taxonomy_files(names_file, nodes_file)
  TaxonomyParser.clear_abundance_from_tree(taxonomy_tree)
  
  ########################################################################################################  
  # Print start message
  timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")
  filename = os.path.basename(input_file).split(".")[0]  
  print(f"\n\nB_PID: {pid} [{timestamp}]: Started task Input: {filename}")
  
  tabulate_known_viruses(taxonomy_tree, input_count_reads_path, count_reads_extension,
    input_mapping_path, align_filters, input_alignment_path, input_kraken_path,
    kraken_folder, filename, output_path)
  
  # Print end message
  print("Finished!")


if __name__ == '__main__':
  # Get the current process ID
  pid = os.getpid()
  input_count = sys.argv[1]
  input_file = sys.argv[2]
  input_id = os.path.basename(input_file).split(".", 1)[0]
  timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")
  
  # # Replace stdout with an unbuffered version
  # sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
  # Print start message
  print(f"B_PID: {pid} [{timestamp}]: Started task Input: {input_file} Count: {input_count}", flush=True)  
  # Open the log file in line-buffered mode and assign sys.stdout
  f = open(f"{pid}_{input_id}.log", "w", buffering=1)  # buffering=1 => line buffering
  sys.stdout = f
  
  try:
    # RUN MAIN CODE
    main()
  finally:
    # Restore original stdout and close the log file
    sys.stdout = sys.__stdout__
    f.close()