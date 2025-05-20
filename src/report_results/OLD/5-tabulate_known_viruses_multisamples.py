import os, sys, shutil, csv, copy
from datetime import datetime, timezone
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")

import utilities.taxonomy_tree_parser as TaxonomyParser
import utilities.calculate_confusion_matrix as CMTrees


def main():
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
  
  # Create the folder to place the output if it doesn't exist
  output_path = output_dir
  os.makedirs(output_path, exist_ok=True)
  
  ########################################################################################################
  # Load complete taxonomy tree
  names_file = os.path.join(taxonomy_database, "names.dmp")
  nodes_file = os.path.join(taxonomy_database, "nodes.dmp")
  _, taxonomy_tree = TaxonomyParser.load_tree_from_taxonomy_files(names_file, nodes_file)
  TaxonomyParser.clear_abundance_from_tree(taxonomy_tree)
  # create a copy of the taxonomy tree for the confusion matrix calculation
  ground_truth_tree = taxonomy_tree
  true_positive_tree = copy.deepcopy(taxonomy_tree)
  classified_tree = copy.deepcopy(taxonomy_tree)
  
  ########################################################################################################
  
  # collect the expected taxid count from accessions of the mock
  metadata_file = metadata_path
  # meta_filename = filename.rsplit("_", 1)[0]
  # metadata_file = os.path.join(metadata_path, meta_filename + ".txt")
  accession_taxids = CMTrees.load_accession_metadata(metadata_file)
  
  for i in range(1, 11):
    # Print start message
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")
    filename = f"{os.path.basename(input_file).replace(input_suffix,'')}_{i}"
    print(f"\n\nB_PID: {pid} [{timestamp}]: Started task Input: {filename}")
    # print(f"Analyzing file: {input_file}")
    # filename = os.path.basename(input_file).split(".")[0]
    
    #######################################################################################################
    # GROUND TRUTH
    # contig to reads files
    contig_reads = {}
    count_reads_file = os.path.join(input_count_reads_path, filename + count_reads_extension)
    output_file = os.path.join(output_path, filename + "_ground_truth.csv")
    # create the ground truth tree with the real taxa from the mocks and the number of reads from each one    
    accession_abundance = CMTrees.load_ground_truth_tree(
      ground_truth_tree, accession_taxids, count_reads_file,
      count_reads_extension, contig_reads, filename, output_file)    
    # calculate total abundance
    total_abundance = sum([accession_abundance[acc].count for acc in accession_abundance])
    
    #######################################################################################################
    # SET BLAST CONFUSION MATRIX
    # blast files
    blast_file = os.path.join(input_blast_path, filename + ".txt")
    mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
    output_file = os.path.join(output_path, filename + "_contig_not_matched_blast.tsv")
    # load blast tree
    CMTrees.load_blast_tree(
      classified_tree, true_positive_tree, accession_taxids, contig_reads,
      align_filters, blast_file, mapping_file, output_file)    
    # Calculate confusion matrix for blast
    output_file = os.path.join(output_path, filename + "_blast_metrics.csv")
    CMTrees.calculate_confusion_matrix(
      accession_taxids, total_abundance, ground_truth_tree,
      true_positive_tree, classified_tree, output_file)
    
    #######################################################################################################
    # SET KRAKEN CONFUSION MATRIX    
    if kraken_folder != "":
      # kraken files
      kreport_file = os.path.join(input_kraken_path, filename + ".kreport")
      kout_file = os.path.join(input_kraken_path, filename + ".kout")
      output_classified_file = os.path.join(output_path, filename + "_classified.csv")
      # load kraken tree
      CMTrees.load_kraken_tree(
        classified_tree, true_positive_tree, accession_taxids,
        kreport_file, kout_file, output_classified_file)      
      # Calculate confusion matrix for kraken
      output_file = os.path.join(output_path, filename + "_kraken_metrics.csv")
      CMTrees.calculate_confusion_matrix(
        accession_taxids, total_abundance, ground_truth_tree,
        true_positive_tree, classified_tree, output_file)
  
  print("Finished!")



if __name__ == '__main__':
  # Get the current process ID
  pid = os.getpid()
  input_count = sys.argv[1]
  input_file = sys.argv[2]
  input_id = os.path.basename(input_file).rsplit(".", 1)[0]
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