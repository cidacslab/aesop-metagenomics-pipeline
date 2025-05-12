import os, sys, shutil, csv, copy
from datetime import datetime, timezone
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")

import utilities.taxonomy_tree_parser as TaxonomyParser
import utilities.blast_result_parser as BlastResultParser
import utilities.get_fastq_read_info as FastqReadInfo


#########################################################################################
#### INCLUDE SAMPLES METADATA

def load_accession_metadata(metadata_file):  
  accession_taxids = {}
  
  with open(metadata_file, "r") as file:
    for line in file:
      row = line.split()
      # update accession taxid
      accession = row[0].strip()
      taxid = row[1].strip()
      accession_taxids[accession] = taxid
  return accession_taxids

#########################################################################################
## SET GROUND TRUTH

def count_remaining_contigs_to_reads(remaining_contigs_file):
  accession_read_abundance,contig_to_reads = {},{}
  with open(remaining_contigs_file, "r") as file:
    reader = csv.reader(file, delimiter="\t")
    next(reader) # remove reader
    for row in reader:
      contig_name = row[0].strip()
      accessions = row[1].strip()[1:-1].split(",")
      if contig_name not in contig_to_reads:
        contig_to_reads[contig_name] = BlastResultParser.ContigInfo()
      for accession_count in accessions:
        count_splits = accession_count.split(":")
        accession = count_splits[0].strip().replace("'", "")
        abundance = int(count_splits[1].strip())
        if accession not in accession_read_abundance:
          accession_read_abundance[accession] = FastqReadInfo.ReadInfo()
        accession_read_abundance[accession].count += abundance
        contig_to_reads[contig_name].accession_read_count[accession] = abundance
  return accession_read_abundance,contig_to_reads


def set_ground_truth_tree_real_counts(accession_abundance, accession_taxids, ground_truth_tree, output_file):
  output_content = "read_accession_id,count\n"
  
  for accession, taxid in accession_taxids.items():
    if accession in accession_abundance:
      abundance = accession_abundance[accession].count
      ground_truth_tree[taxid].set_abundance(abundance)
      output_content += f"{accession},{abundance}\n"
    else:
      print(f"Accession {accession} not present in ground truth.")
  
  with open(output_file, "w") as out_file:
    out_file.write(output_content)


#########################################################################################
## INCLUDE KRAKEN RESULT

def get_accession_taxid_abundance(kout_file, output_file):
  print(f"Get accession taxid abundance from: {kout_file}")
  accession_results_by_taxid = {}
  
  with open(kout_file, "r") as kraken_file:
    for line in kraken_file:
      line = line.strip().split()
      if len(line) >= 3 and line[0] == "C":
        accession_id = line[1].rsplit('_', 2)[0].strip()
        taxid = line[2].strip()
        if len(accession_id) == 0 or len(taxid) == 0:
          continue 
        if accession_id not in accession_results_by_taxid:
          accession_results_by_taxid[accession_id] = {}
        if taxid not in accession_results_by_taxid[accession_id]:
          accession_results_by_taxid[accession_id][taxid] = 0
        accession_results_by_taxid[accession_id][taxid] += 1
  
  output_content = "read_accession_id,taxid,count\n"
  for accession_id, taxid_counts in accession_results_by_taxid.items():
    for taxid, count in taxid_counts.items():
      output_content += f"{accession_id},{taxid},{count}\n"
  with open(output_file, "w") as out_file:
    out_file.write(output_content)
  
  return accession_results_by_taxid


#########################################################################################
#### INCLUDE BLAST RESULT

def set_true_positive_in_taxonomy(true_taxid, classified_taxid, true_positive_tree, count):
  # get taxids of the correct accession full taxonomy
  true_positive_taxids = set()
  true_node = true_positive_tree.get(true_taxid, None)
  while true_node is not None:
    true_positive_taxids.add(true_node.taxid)
    true_node = true_node.parent
  #  for every taxid from the classified result taxonomy
  # check if any is equal to the expected result (true_node)
  is_true_positive = False
  classified_node = true_positive_tree.get(classified_taxid, None)
  while not is_true_positive and classified_node is not None:
    if classified_node.taxid in true_positive_taxids:
      classified_node.set_abundance(count)
      is_true_positive = True
    else:
      classified_node = classified_node.parent
  # return the true positive match or None
  return classified_node if is_true_positive else None


def load_blast_results(contig_reads, contig_to_blast_result, accession_taxids, 
                        blast_classified_tree, true_positive_tree,
                        output_no_matched_contig_file):
  output_content = "contig\tread_count\n"
  
  for contig,contig_info in contig_reads.items():
    if contig in contig_to_blast_result:
      print(f"{contig}: {contig_info.accession_read_count}")
      # contig_info = contig_reads[contig]
      blast_result = contig_to_blast_result[contig]
      taxid = blast_result['staxids'].strip().split(";")[0]
      for accession, read_count in contig_info.accession_read_count.items():
        blast_classified_tree[taxid].set_abundance(read_count)
        # set true positive tree
        true_taxid = accession_taxids.get(accession, 0)
        blast_node = set_true_positive_in_taxonomy(true_taxid, taxid, true_positive_tree, read_count)
        is_true_positive = blast_node is not None
        #if not is_true_positive:
        print(f"{is_true_positive} positive for contig {contig}:{taxid} mapped {read_count} reads " + \
              f"from {accession}:{true_taxid}:{blast_node}.")
    else:
      # print(f"Contig {contig} had no read mapped!")
      output_content += f"{contig}\t{str(contig_info.accession_read_count)}\n"
  
  with open(output_no_matched_contig_file, "w") as out_file:
    out_file.write(output_content)


#########################################################################################
#### INCLUDE KRAKEN TRUE POSITIVE RESULT

def set_true_positive_tree_counts(accession_results_by_taxid, accession_taxids, true_positive_tree):
  # loop through all accessions
  for accession, true_taxid in accession_taxids.items():
    if accession not in accession_results_by_taxid:
      continue
    for taxid in accession_results_by_taxid[accession]:
      count = accession_results_by_taxid[accession][taxid]      
      # set true positive tree
      classified_node = set_true_positive_in_taxonomy(true_taxid, taxid, true_positive_tree, count)
      is_true_positive = classified_node is not None
      #if not is_true_positive:
      print(f"{is_true_positive} positive for {accession}:{true_taxid} mapping {count} reads " + \
            f"to {taxid}:{classified_node}")


#########################################################################################
#### CALCULATE COFUSION MATRIX

def get_confusion_matrix_values(sample_total_reads, total_tax_reads, total_mapped_to_tax, correct_tax_reads):
  # print(f"{sample_total_reads}, {total_tax_reads}, {total_mapped_to_tax}, {correct_tax_reads}")
  # reads from tax_id mapped to correct tax_id
  true_positive = correct_tax_reads
  # reads from tax_id not mapped to this tax_id
  false_negative = total_tax_reads - correct_tax_reads
  # reads not from tax_id mapped to this tax_id
  false_positive = total_mapped_to_tax - correct_tax_reads
  # reads not from tax_id not mapped to this tax_id
  true_negative = sample_total_reads - total_tax_reads - false_positive
  
  # accuracy = (true_positive + true_negative) / float(true_positive + false_negative + false_positive + true_negative)
  # sensitivity = (true_positive) / float(true_positive + false_negative)
  # specificity = (true_negative) / float(false_positive + true_negative)
  # precision = (true_positive) / float(true_positive + false_positive)
  return (true_positive, true_negative, false_positive, false_negative)


def get_output_for_confusion_matrix(node, included_taxids, sample_total_reads,
                                    ground_truth_tree, true_positive_tree, classified_tree):
  output_content = ""  
  if node.taxid not in included_taxids:
    total_reads = node.acumulated_abundance
    correct_reads = true_positive_tree[node.taxid].acumulated_abundance
    total_classified = classified_tree[node.taxid].acumulated_abundance
    #print(f"{node.taxid}, {node.name}, {total_reads}, {correct_reads}, {total_classified}")
    metrics = get_confusion_matrix_values(sample_total_reads, total_reads, total_classified, correct_reads)
    output_content += f"{node.level_enum},{node.taxid},{node.name},{sample_total_reads},"
    output_content += f"{total_reads},{total_classified},{correct_reads},"
    output_content += f"{metrics[0]},{metrics[1]},{metrics[2]},{metrics[3]}\n"
    included_taxids.add(node.taxid)
  return output_content


def calculate_confusion_matrix(accession_taxids, sample_total_reads, ground_truth_tree,
                                true_positive_tree, classified_tree, output_file):
  print(f"Calculating confusion matrix: {output_file}")
  output_content = "level,taxid,name,sample_total_reads,level_total_reads,"
  output_content += "level_total_classified,level_correct_reads,"
  output_content += "true_positive,true_negative,false_positive,false_negative\n"
  included_taxids = set()
  
  for accession, taxid in accession_taxids.items():
    node = ground_truth_tree[taxid]
    accession_total_reads = node.acumulated_abundance
    
    domain_node = node.get_parent_by_level(TaxonomyParser.Level.D)
    if domain_node.name.lower() != "viruses":
      output_content += get_output_for_confusion_matrix(domain_node, included_taxids,
        sample_total_reads, ground_truth_tree, true_positive_tree, classified_tree)  
      continue
    
    for level in range(9, 1, -1):
      level_enum = TaxonomyParser.Level(level)
      level_node = node.get_parent_by_level(level_enum)
      if level_node is None:
        continue
      output_content += get_output_for_confusion_matrix(level_node, included_taxids,
        sample_total_reads, ground_truth_tree, true_positive_tree, classified_tree)
  
  with open(output_file, "w") as out_file:
    out_file.write(output_content)



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
  ground_truth_tree = copy.deepcopy(taxonomy_tree)
  true_positive_tree = copy.deepcopy(taxonomy_tree)
  classified_tree = copy.deepcopy(taxonomy_tree)
  
  ########################################################################################################
  
  print(f"Analyzing file: {input_file}")
  filename = os.path.basename(input_file).replace(input_suffix, "")
  
  #######################################################################################################
  # GROUND TRUTH
  # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
  
  # clean the ground truth tree
  TaxonomyParser.clear_abundance_from_tree(ground_truth_tree)
  
  # include the number of reads of each accession as the abundance of each taxa species
  count_reads_file = os.path.join(input_count_reads_path, filename + count_reads_extension)
  accession_abundance,contig_reads = {},{}
  if count_reads_extension.endswith(".fastq.gz"):
    accession_abundance = FastqReadInfo.count_reads_by_sequence_id(count_reads_file)
    # double the abundance value to account for each mate from the sequencing
    for acc in accession_abundance:
      accession_abundance[acc].count *= 2
  elif count_reads_extension.endswith("_contig_not_matched_blast.tsv"):
    accession_abundance,contig_reads = count_remaining_contigs_to_reads(count_reads_file)
  else:
    print(f"Count read function doesn't exist for extension: {count_reads_extension}")
    return
  # calculate total abundance
  total_abundance = sum([accession_abundance[acc].count for acc in accession_abundance])
  
  # collect the expected taxid count from accessions of the mock
  metadata_file = metadata_path
  # meta_filename = filename.rsplit("_", 1)[0]
  # metadata_file = os.path.join(metadata_path, meta_filename + ".txt")
  accession_taxids = load_accession_metadata(metadata_file)
  
  # set counts on the ground_truth_tree
  output_ground_truth_file = os.path.join(output_path, filename + "_ground_truth.csv")
  set_ground_truth_tree_real_counts(
    accession_abundance, accession_taxids, ground_truth_tree, output_ground_truth_file)
  
  
  #######################################################################################################
  # SET KRAKEN CONFUSION MATRIX
  
  if kraken_folder != "":    
    # clean the true positive tree
    TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
    # clean the kraken result tree
    TaxonomyParser.clear_abundance_from_tree(classified_tree)
    
    # create the classified_tree from the kraken output
    report_file = os.path.join(input_kraken_path, filename + ".kreport")
    _, report_tree = TaxonomyParser.load_tree_from_kraken_report(report_file)
    
    # set values from the kraken report in the classified_tree
    for k,node in report_tree.items():
      if k not in classified_tree:
        print(f"Node not found in taxonomy tree: {node}")
      else:
        classified_tree[k].set_abundance(node.abundance * 2)
    
    # load the kraken classified count by taxid
    accession_taxid_abundance_file = os.path.join(input_kraken_path, filename + ".kout")
    output_file = os.path.join(output_path, filename + "_classified.csv")
    accession_results_by_taxid = get_accession_taxid_abundance(accession_taxid_abundance_file, output_file)  
    # double the abundance value to account for each mate from the sequencing
    for accession in accession_results_by_taxid:
      for taxid in accession_results_by_taxid[accession]:
        accession_results_by_taxid[accession][taxid] *= 2
    
    # create the true positive tree adding the abundance only if they are correctly mapped
    set_true_positive_tree_counts(accession_results_by_taxid, accession_taxids, true_positive_tree)
    
    # Calculate confusion matrix for kraken
    output_file = os.path.join(output_path, filename + "_kraken_metrics.csv")
    calculate_confusion_matrix(
      accession_taxids, total_abundance, ground_truth_tree, true_positive_tree, classified_tree, output_file)
  
  #######################################################################################################
  # SET BLAST CONFUSION MATRIX
  
  # clean the true positive tree
  TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
  # clean the blast result tree
  TaxonomyParser.clear_abundance_from_tree(classified_tree)
  
  # get blast results for the contigs and the reads mapped to each contig
  blast_file = os.path.join(input_blast_path, filename + ".txt")
  contig_to_blast_result = BlastResultParser.get_best_result(
    blast_file, align_coverage, align_identity, align_evalue, align_length)
  
  if len(contig_reads) == 0:
    mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
    contig_reads = BlastResultParser.count_contig_reads(mapping_file)
  
  # Set blast classified tree and the true positive
  output_file = os.path.join(output_path, filename + "_contig_not_matched_blast.tsv")
  load_blast_results(
    contig_reads, contig_to_blast_result, accession_taxids, classified_tree, true_positive_tree, output_file)
  
  # Calculate confusion matrix for blast
  output_file = os.path.join(output_path, filename + "_blast_metrics.csv")
  calculate_confusion_matrix(
    accession_taxids, total_abundance,ground_truth_tree, true_positive_tree, classified_tree, output_file)
  
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