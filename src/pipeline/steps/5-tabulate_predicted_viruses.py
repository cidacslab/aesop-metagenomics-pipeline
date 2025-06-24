import os, sys, csv, copy
from datetime import datetime, timezone
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")
sys.path.append("/home/pablo.viana/jobs/github/aesop-metagenomics-pipeline/src")
sys.path.append("/mnt/c/Users/pablo/Documents/github/aesop-metagenomics-pipeline/src")

import utilities.taxonomy_tree_parser as TaxonomyParser
import utilities.calculate_confusion_matrix as ConfusionMatrix


def tabulate_known_viruses(
  ground_truth_tree, classified_tree, true_positive_tree, accession_taxids,
  input_count_reads_path, count_reads_extension, input_mapping_path, align_filters,
  input_alignment_path, input_kraken_path, kraken_folder, filename, output_path):
  """
  Tabulates known viruses by creating a ground truth tree from mock data, setting up
  confusion matrices for BLAST and Kraken classification results.
  Parameters:
    ground_truth_tree: The taxonomy tree representing the true taxonomic structure.
    classified_tree: The taxonomy tree used for classification results.
    true_positive_tree: The taxonomy tree used to track true positive classifications.
    accession_taxids: A mapping of accession numbers to taxonomic IDs.
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
  1. Loads and processes the ground truth tree using mock data to determine the real taxa and their abundance.
  2. Sets up the alignment confusion matrix by loading the alignment result file, applying alignment filters, and calculating metrics.
  3. If provided, sets up the Kraken confusion matrix by loading the Kraken result and calculating metrics.
  """
  #######################################################################################################
  # GROUND TRUTH
  # contig to reads files  
  count_reads_file = os.path.join(input_count_reads_path, filename + count_reads_extension)
  mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
  output_file = os.path.join(output_path, filename + "_ground_truth.csv")
  # create the ground truth tree with the real taxa from the mocks and the number of reads from each one    
  total_abundance, contig_reads, mapped_reads = ConfusionMatrix.load_ground_truth_tree(
    ground_truth_tree, accession_taxids, count_reads_file, count_reads_extension,
    mapping_file, filename, output_file)
  
  #######################################################################################################
  # SET ALIGNMENT CONFUSION MATRIX
  # alignment files
  alignment_file = os.path.join(input_alignment_path, filename + ".txt")
  output_unmatches_file = os.path.join(output_path, filename + "_contig_unmatched_blast.tsv")
  output_matches_file = os.path.join(output_path, filename + "_contig_matched_blast.csv")
  # load alignment tree
  ConfusionMatrix.load_alignment_tree(classified_tree, true_positive_tree,
    accession_taxids, contig_reads, alignment_file, align_filters,
    output_unmatches_file, output_matches_file)
  # Calculate confusion matrix for alignment
  output_file = os.path.join(output_path, filename + "_blast_metrics.csv")
  ConfusionMatrix.calculate_confusion_matrix(accession_taxids, total_abundance,
    ground_truth_tree, true_positive_tree, classified_tree, output_file)
  
  #######################################################################################################
  # SET KRAKEN CONFUSION MATRIX
  if kraken_folder:
    # get kraken result for unmapped reads (the ones didn't form contigs)
    kout_file = os.path.join(input_kraken_path, filename + ".kout")
    k2result_accession_to_taxid = ConfusionMatrix.include_k2result_for_unmatched(
      classified_tree, true_positive_tree, accession_taxids, mapped_reads, kout_file)
    # Calculate confusion matrix for blast + kraken (all known viruses)
    output_file = os.path.join(output_path, filename + "_known_viruses_report.csv")
    ConfusionMatrix.calculate_confusion_matrix(accession_taxids, total_abundance,
      ground_truth_tree, true_positive_tree, classified_tree, output_file)
    
    # load kraken tree
    kreport_file = os.path.join(input_kraken_path, filename + ".kreport")
    ConfusionMatrix.load_kraken_tree(classified_tree, true_positive_tree,
      accession_taxids, kreport_file, k2result_accession_to_taxid)
    # Calculate confusion matrix for kraken
    output_file = os.path.join(output_path, filename + "_kraken_metrics.csv")
    ConfusionMatrix.calculate_confusion_matrix(accession_taxids, total_abundance,
      ground_truth_tree, true_positive_tree, classified_tree, output_file)



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
  input_alignment_path = input_dir
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
  merged_file = os.path.join(taxonomy_database, "merged.dmp")
  _, taxonomy_tree = TaxonomyParser.load_tree_from_taxonomy_files(names_file, nodes_file, merged_file)
  TaxonomyParser.clear_abundance_from_tree(taxonomy_tree)
  # create a copy of the taxonomy tree for the confusion matrix calculation
  ground_truth_tree = taxonomy_tree
  true_positive_tree = copy.deepcopy(taxonomy_tree)
  classified_tree = copy.deepcopy(taxonomy_tree)
  
  ########################################################################################################  
  # collect the expected taxid from accessions of the mock
  metadata_file = metadata_path
  # meta_filename = filename.rsplit("_", 1)[0]
  # metadata_file = os.path.join(metadata_path, meta_filename + ".txt")
  accession_taxids = ConfusionMatrix.load_accession_metadata(metadata_file)
  
  # USE "FOR" TO PROCESS MULTIPLE FILES
  for i in range(1, 11):
    # Print start message
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")
    filename = f"{os.path.basename(input_file).rsplit('_', maxsplit=1)[0]}_{i}"
    print(f"\n\nB_PID: {pid} [{timestamp}]: Started task Input: {filename}")
    
    tabulate_known_viruses(
      ground_truth_tree, classified_tree, true_positive_tree, accession_taxids,
      input_count_reads_path, count_reads_extension, input_mapping_path, align_filters,
      input_alignment_path, input_kraken_path, kraken_folder, filename, output_path)
  
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