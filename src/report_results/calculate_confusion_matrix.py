import os, sys, shutil, csv, copy
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")

import utilities.taxonomy_tree_parser as TaxonomyParser
import utilities.blast_result_parser as BlastResultParser
from utilities.utility_functions import get_files_in_folder
from utilities.get_fastq_read_info import count_reads_by_sequence_id


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

def set_ground_truth_tree_real_counts(accession_abundance, accession_taxids, ground_truth_tree, output_file):
  output_content = "read_accession_id,count\n"
  
  for accession, taxid in accession_taxids.items():
    abundance = accession_abundance[accession].count
    ground_truth_tree[taxid].set_abundance(abundance)
    output_content += f"{accession},{abundance}\n"
  
  with open(output_file, "w") as out_file:
    out_file.write(output_content)


def set_ground_truth_tree_real_counts_from_ground_truth_file(ground_truth_file, accession_taxids, ground_truth_tree):
  
  with open(ground_truth_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      accession = row[0].strip()
      abundance = row[1].strip()
      taxid = accession_taxids[accession]
      ground_truth_tree[taxid].set_abundance(abundance)  


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


def get_accession_taxid_abundance_from_classified_file(classified_file):
  print(f"Get accession taxid abundance from: {classified_file}")
  accession_results_by_taxid = {}
  with open(classified_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      accession_id = row[0].strip()
      taxid = row[1].strip()
      count = int(row[2].strip())        
      if accession_id not in accession_results_by_taxid:
        accession_results_by_taxid[accession_id] = {}
      accession_results_by_taxid[accession_id][taxid] = count
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
      taxid = blast_result['staxids'].strip()
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



def calculate_confusion_matrix(accession_taxids, sample_total_reads, ground_truth_tree, true_positive_tree, all_classified_tree, output_file):
  print(f"Calculating confusion matrix: {output_file}")
      
  output_content = "level,taxid,name,sample_total_reads,level_total_reads,"
  output_content += "level_total_classified,level_correct_reads,"
  output_content += "true_positive,true_negative,false_positive,false_negative\n"
  output_taxids = set()

  for accession, taxid in accession_taxids.items():
    node = ground_truth_tree[taxid]
    accession_total_reads = node.acumulated_abundance
    
    for level in range(9, 1, -1):
      level_enum = TaxonomyParser.Level(level)
      level_node = node.get_parent_by_level(level_enum)
      if level_node is None:
        continue
      if level_node.taxid in output_taxids:
        continue
      #
      level_total_reads = level_node.acumulated_abundance
      level_correct_reads = true_positive_tree[level_node.taxid].acumulated_abundance
      level_total_classified = all_classified_tree[level_node.taxid].acumulated_abundance
      #print(f"{level_node.taxid}, {level_node.name}, {level_total_reads}, {level_correct_reads}, {level_total_classified}")
      #
      level_metrics = get_confusion_matrix_values(sample_total_reads, level_total_reads, level_total_classified, level_correct_reads)
      #
      output_content += f"{level},{level_node.taxid},{level_node.name},{sample_total_reads},"
      output_content += f"{level_total_reads},{level_total_classified},{level_correct_reads},"
      output_content += f"{level_metrics[0]},{level_metrics[1]},{level_metrics[2]},{level_metrics[3]}\n"
      output_taxids.add(level_node.taxid)
      
  with open(output_file, "w") as out_file:
    out_file.write(output_content)


def main():
  project_path = "/home/pedro/aesop/github/aesop-metagenomics-pipeline/"
  results_path = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock"
  input_extension = ".txt"
  # input_fastq_path = os.path.join(results_path, "mock_metagenomes")
  # input_fastq_path = os.path.join(results_path, "1.2-bowtie_ercc_output")
  input_fastq_path = os.path.join(results_path, "4.1-viral_discovery_reads")
  input_kraken_path = os.path.join(results_path, "3-taxonomic_output")
  input_mapping_path = os.path.join(results_path, "4.3.1-viral_discovery_mapping_metaspades")
  # input_blast_path = os.path.join(results_path, "forth-blast_parameter_tweak/4.3.2-blastn_contigs_metaspades")
  input_blast_path = os.path.join(results_path, "4.3.3-diamond_contigs_metaspades/fast")
  # input_taxonkit_path = os.path.join(results_path, "4.3.3-blastn_taxonkit_metaspades")
  input_metadata_path = os.path.join(project_path, "data/dataset_mock/metadata")
  output_path = os.path.join(project_path, "data/dataset_mock/performance_metrics")
  
  ########################################################################################################
  # Load complete taxonomy tree
  input_taxonomy_path = "/home/pedro/aesop/pipeline/databases/taxdump"
  names_file = os.path.join(input_taxonomy_path, "names.dmp")
  nodes_file = os.path.join(input_taxonomy_path, "nodes.dmp")
  _, taxonomy_tree = TaxonomyParser.load_tree_from_taxonomy_files(names_file, nodes_file)
  
  # set Viruses Domain as root and deletes the rest of the tree
  viruses_root = taxonomy_tree["10239"]
  viruses_root.parent = None
  # get all viruses nodes and set them as kraken result tree
  viruses_tree = {}
  viruses_root.get_all_nodes(viruses_tree)
  TaxonomyParser.clear_abundance_from_tree(viruses_tree)
  
  # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
  ground_truth_tree = copy.deepcopy(viruses_tree)
  # create the blast result tree
  kraken_classified_tree = copy.deepcopy(viruses_tree)
  # create the true positive tree adding the abundance only if they are correctly mapped
  true_positive_tree = copy.deepcopy(viruses_tree)
  # create the blast result tree
  blast_classified_tree = copy.deepcopy(viruses_tree)
  
  # shutil.rmtree(output_path)
  os.makedirs(output_path, exist_ok=True)
  
  all_files = get_files_in_folder(input_blast_path, input_extension)
  print(all_files)
  
  for currfile in all_files:
    # fastq_file = all_files[0]
    print(f"Analyzing file: {currfile}")
    filename = os.path.basename(currfile).replace(input_extension, "")
    fastq_file = os.path.join(input_fastq_path, filename + "_1.fastq.gz")
    
    #######################################################################################################
    # GROUND TRUTH
    # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
    TaxonomyParser.clear_abundance_from_tree(ground_truth_tree)
    
    meta_filename = filename.rsplit("_", 1)[0]
    # meta_filename = "_".join(splits[0:-2])
    metadata_file = os.path.join(input_metadata_path, meta_filename + ".txt")
    loaded_accession_taxids = load_accession_metadata(metadata_file)
    accession_taxids = {}
    for accession,taxid in loaded_accession_taxids.items():
      node = taxonomy_tree[taxid]
      domain_node = node.get_parent_by_level(TaxonomyParser.Level.D)
      if domain_node.name.lower() == "viruses":
        accession_taxids[accession] = taxid
      else:
        print(f"Removing {accession}:{taxid} because its domain is {domain_node.name}")
    
    # include the number of reads of each accession as the abundance of each taxa species
    accession_abundance = count_reads_by_sequence_id(fastq_file)
    output_ground_truth_file = os.path.join(output_path, filename + "_ground_truth.csv")
    set_ground_truth_tree_real_counts(accession_abundance, accession_taxids, ground_truth_tree, output_ground_truth_file)
    # set_ground_truth_tree_real_counts_from_ground_truth_file(output_ground_truth_file, accession_accession_taxid, ground_truth_tree)
    # double the abundance value to account for each mate from the sequencing
    for k,node in ground_truth_tree.items():
      node.acumulated_abundance *= 2
    total_abundance = sum([accession_abundance[acc].count for acc in accession_abundance]) * 2
    
    #######################################################################################################
    # KRAKEN CLASSIFIED
    # create the all_classified_tree from the kraken output
    report_file = os.path.join(input_kraken_path, filename + ".kreport")
    _, report_tree = TaxonomyParser.load_tree_from_kraken_report(report_file)
    
    TaxonomyParser.clear_abundance_from_tree(kraken_classified_tree)
    
    # set Viruses Domain as root and deletes the rest of the tree
    viruses_root = report_tree["10239"]
    viruses_root.parent = None
    # get all viruses nodes and set them as kraken result tree
    report_tree = {}
    viruses_root.get_all_nodes(report_tree)
    
    for k,node in report_tree.items():
      if k not in kraken_classified_tree:
        print(f"Node not found in taxonomy tree: {node}")
      else:
        kraken_classified_tree[k].set_abundance(node.abundance * 2)
    
    #######################################################################################################
    # KRAKEN TRUE POSITIVE
    # create the true positive tree adding the abundance only if they are correctly mapped
    TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
    
    accession_taxid_abundance_file = os.path.join(input_kraken_path, filename + ".kout")
    output_class_file = os.path.join(output_path, filename + "_classified.csv")
    accession_results_by_taxid = get_accession_taxid_abundance(accession_taxid_abundance_file, output_class_file)
    # double the abundance value to account for each mate from the sequencing
    for accession in accession_results_by_taxid:
      for taxid in accession_results_by_taxid[accession]:
        accession_results_by_taxid[accession][taxid] *= 2
    # accession_results_by_taxid = get_accession_taxid_abundance_from_classified_file(output_class_file)
    set_true_positive_tree_counts(accession_results_by_taxid, accession_taxids, true_positive_tree)
    
    # Calculate confusion matrix for kraken
    output_file = os.path.join(output_path, filename + "_kraken_metrics.csv")
    calculate_confusion_matrix(accession_taxids, total_abundance, ground_truth_tree, true_positive_tree, kraken_classified_tree, output_file)
    
    #######################################################################################################
    # BLASTN RESULTS
    # create the true positive tree adding the abundance only if they are correctly mapped
    TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
    # create the blast result tree
    TaxonomyParser.clear_abundance_from_tree(blast_classified_tree)
    
    # get blast results for the contigs and the reads mapped to each contig
    blast_file = os.path.join(input_blast_path, filename + ".txt")
    contig_to_blast_result = BlastResultParser.get_best_result(blast_file, min_identity=80, max_evalue=0.001, min_length=30)
    mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
    contig_reads = BlastResultParser.count_contig_reads(mapping_file)
    # Set blast result tree and the true positive tree
    output_file = os.path.join(output_path, filename + "_contig_not_matched_blast.tsv")
    load_blast_results(contig_reads, contig_to_blast_result, accession_taxids, blast_classified_tree, true_positive_tree, output_file)
    # Calculate confusion matrix for blast
    output_file = os.path.join(output_path, filename + "_blast_metrics.csv")
    calculate_confusion_matrix(accession_taxids, total_abundance, ground_truth_tree, true_positive_tree, blast_classified_tree, output_file)
  
  print("Finished!")



if __name__ == '__main__':
    main()