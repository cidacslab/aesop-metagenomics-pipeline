import os, sys, shutil, csv, copy
import utils.kraken_report_parser as KrakenParser
from utils.utility_functions import get_files_in_folder
from utils.get_fastq_read_info import count_reads_by_sequence_id


def update_report_tree_with_metadata_taxa(metadata_file, all_classified_tree):  
  print(f"Get accession taxa tree from: {metadata_file}")
  print(f"Initial report tree size: {len(all_classified_tree)}")
  accession_species_taxid = {}

  with open(metadata_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      # update accession taxid
      accession = row[0].strip()
      species_taxid = row[-1].strip()
      accession_species_taxid[accession] = species_taxid
      # update report tree
      names = row[2:9]
      taxids = row[9:]
      domain_taxid = taxids[0]
      last_node = all_classified_tree[domain_taxid]
      for i in range(1, 7):
        taxid = taxids[i]
        if taxid not in all_classified_tree:
          level = KrakenParser.Level(last_node.level_enum + 1).name
          node = KrakenParser.TreeNode(names[i], taxid, level)
          node.set_parent(last_node)
          all_classified_tree[taxid] = node
          print(f"  Included node {node}")
        else:
          node = all_classified_tree[taxid]
          if node.parent.taxid != last_node.taxid:
            node.set_parent(last_node)
        last_node = node
  print(f"Final all_classified_tree size: {len(all_classified_tree)}")
  return accession_species_taxid



def set_ground_truth_tree_real_counts(accession_abundance, accession_species_taxid, ground_truth_tree, output_file):
  KrakenParser.clear_abundance_from_tree(ground_truth_tree)
  output_content = "read_accession_id,count\n"

  for accession in accession_abundance:
    abundance = accession_abundance[accession].count
    taxid = accession_species_taxid[accession]
    ground_truth_tree[taxid].set_abundance(abundance)
    output_content += f"{accession},{abundance}\n"

  with open(output_file, "w") as out_file:
    out_file.write(output_content)



def set_ground_truth_tree_real_counts_from_ground_truth_file(ground_truth_file, accession_species_taxid, ground_truth_tree):
  KrakenParser.clear_abundance_from_tree(ground_truth_tree)

  with open(ground_truth_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      accession = row[0].strip()
      abundance = row[1].strip()
      taxid = accession_species_taxid[accession]
      ground_truth_tree[taxid].set_abundance(abundance)  
  


def get_accession_taxid_abundance(kout_file, output_file):
  print(f"Get accession taxid abundance from: {kout_file}")
  accession_taxid_counts = {}

  with open(kout_file, "r") as kraken_file:
    for line in kraken_file:
      line = line.strip().split()
      if len(line) >= 3 and line[0] == "C":
        accession_id = line[1].rsplit('_', 2)[0].strip()
        taxid = line[2].strip()
        if len(accession_id) == 0 or len(taxid) == 0:
          continue 
        if accession_id not in accession_taxid_counts:
          accession_taxid_counts[accession_id] = {}
        if taxid not in accession_taxid_counts[accession_id]:
          accession_taxid_counts[accession_id][taxid] = 0
        accession_taxid_counts[accession_id][taxid] += 1

  output_content = "read_accession_id,taxid,count\n"
  for accession_id, taxid_counts in accession_taxid_counts.items():
    for taxid, count in taxid_counts.items():
      output_content += f"{accession_id},{taxid},{count}\n"
  with open(output_file, "w") as out_file:
    out_file.write(output_content)

  return accession_taxid_counts



def get_accession_taxid_abundance_from_classified_file(classified_file):
  print(f"Get accession taxid abundance from: {classified_file}")
  accession_taxid_counts = {}
  with open(classified_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      accession_id = row[0].strip()
      taxid = row[1].strip()
      count = int(row[2].strip())        
      if accession_id not in accession_taxid_counts:
        accession_taxid_counts[accession_id] = {}
      accession_taxid_counts[accession_id][taxid] = count
  return accession_taxid_counts



def set_true_positive_tree_counts(accession_taxid_counts, accession_species_taxid, true_positive_tree):
  KrakenParser.clear_abundance_from_tree(true_positive_tree)

  for accession in accession_taxid_counts:
    species_taxid = accession_species_taxid[accession]

    for taxid in accession_taxid_counts[accession]:
      abundance = accession_taxid_counts[accession][taxid]
      accession_true_node = true_positive_tree[species_taxid]
      classified_node = true_positive_tree[taxid]
      is_true_positive = False
      while not is_true_positive and accession_true_node is not None:
        node = classified_node
        while not is_true_positive and node is not None:
          if node.taxid == accession_true_node.taxid:
            accession_true_node.set_abundance(abundance)
            is_true_positive = True
            # print(f"For {accession}:{taxid} found true positive node {node} for {accession}:{species_taxid}:{accession_true_node}")
          node = node.parent
        accession_true_node = accession_true_node.parent



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



def calculate_confusion_matrix(accession_species_taxid, ground_truth_tree, true_positive_tree, all_classified_tree, output_file):
  print(f"Calculating confusion matrix: {output_file}")
      
  output_content = "accession_id,total_reads,genus,genus_taxid,genus_true_positive,genus_true_negative,"
  output_content += "genus_false_positive,genus_false_negative,species,species_taxid,species_true_positive,"
  output_content += "species_true_negative,species_false_positive,species_false_negative\n"
  
  sample_total_reads = 0
  for accession in accession_species_taxid:
    species_taxid = accession_species_taxid[accession]
    sample_total_reads += ground_truth_tree[species_taxid].acumulated_abundance

  for accession in accession_species_taxid:
    species_taxid = accession_species_taxid[accession]
    accession_species_node = ground_truth_tree[species_taxid]
    accession_total_reads = accession_species_node.acumulated_abundance

    species_name = accession_species_node.name
    species_total_reads = accession_species_node.acumulated_abundance
    species_correct_reads = true_positive_tree[species_taxid].acumulated_abundance
    species_total_classified = all_classified_tree[species_taxid].acumulated_abundance
    
    accession_genus_node = accession_species_node.parent
    genus_taxid = accession_genus_node.taxid
    genus_name = accession_genus_node.name 
    genus_total_reads = accession_genus_node.acumulated_abundance
    genus_correct_reads = true_positive_tree[genus_taxid].acumulated_abundance
    genus_total_classified = all_classified_tree[genus_taxid].acumulated_abundance
    if accession_genus_node.level_enum != KrakenParser.Level.G:
      genus_name = "Undefined genus in " + genus_name

    print(f"{species_taxid}, {species_name}, {species_total_reads}, {species_correct_reads}, {species_total_classified}")
    print(f"{genus_taxid}, {genus_name}, {genus_total_reads}, {genus_correct_reads}, {genus_total_classified}")
    
    genus_metrics = get_confusion_matrix_values(sample_total_reads, genus_total_reads, genus_total_classified, genus_correct_reads)
    species_metrics = get_confusion_matrix_values(sample_total_reads, species_total_reads, species_total_classified, species_correct_reads)

    output_content += f"{accession},{accession_total_reads},{genus_name},{genus_taxid},{genus_metrics[0]},"
    output_content += f"{genus_metrics[1]},{genus_metrics[2]},{genus_metrics[3]},{species_name},{species_taxid},"
    output_content += f"{species_metrics[0]},{species_metrics[1]},{species_metrics[2]},{species_metrics[3]}\n"
      
  with open(output_file, "w") as out_file:
    out_file.write(output_content)



def main():
  base_path = "results/mocks_sample_based"
  input_extension = "_1.fastq"
  # input_fastq_path = f"{base_path}/mock_metagenomes"
  input_fastq_path = f"{base_path}/pipeline_outputs/1-fastp_output"
  input_kraken_path = f"{base_path}/pipeline_outputs/2-kraken_results"
  input_metadata_path = f"{base_path}/metadata"
  output_path = f"{base_path}/performance_metrics"
  output_extension = "_metrics.csv"  
  
  # shutil.rmtree(output_path)
  os.makedirs(output_path, exist_ok=True)

  all_files = get_files_in_folder(input_fastq_path, input_extension)
  print(all_files)

  for fastq_file in all_files:
    # fastq_file = all_files[0]
    print(f"Analyzing file: {fastq_file}")
    filename = os.path.basename(fastq_file).replace(input_extension, "")

    # if filename.startswith("SI041_2_"):
    #   continue
    
    # create the all_classified_tree from the kraken output
    report_file = os.path.join(input_kraken_path, filename + ".kreport")
    _, all_classified_tree = KrakenParser.load_kraken_report_tree(report_file)

    splits = filename.split("_")
    meta_filename = "_".join(splits[0:-2])
    metadata_file = os.path.join(input_metadata_path, meta_filename + ".csv")
    # add the taxa from the accession metadata if they are not in the classified tree
    accession_species_taxid = update_report_tree_with_metadata_taxa(metadata_file, all_classified_tree)
    #######################################################################################################

    # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
    ground_truth_tree = copy.deepcopy(all_classified_tree)

    # include the number of reads of each accession as the abundance of each taxa species
    accession_abundance = count_reads_by_sequence_id(fastq_file)
    output_ground_truth_file = os.path.join(output_path, filename + "_ground_truth.csv")
    set_ground_truth_tree_real_counts(accession_abundance, accession_species_taxid, ground_truth_tree, output_ground_truth_file)
    # set_ground_truth_tree_real_counts_from_ground_truth_file(output_ground_truth_file, accession_species_taxid, ground_truth_tree)
    #######################################################################################################

    # create the true positive tree adding the abundance only if they are correctly mapped
    true_positive_tree = copy.deepcopy(ground_truth_tree)

    accession_taxid_abundance_file = os.path.join(input_kraken_path, filename + ".kout")
    output_class_file = os.path.join(output_path, filename + "_classified.csv")
    accession_taxid_counts = get_accession_taxid_abundance(accession_taxid_abundance_file, output_class_file)
    # accession_taxid_counts = get_accession_taxid_abundance_from_classified_file(output_class_file)
    set_true_positive_tree_counts(accession_taxid_counts, accession_species_taxid, true_positive_tree)

    # Calculate confusion matrix
    output_file = os.path.join(output_path, filename + output_extension)
    calculate_confusion_matrix(accession_species_taxid, ground_truth_tree, true_positive_tree, all_classified_tree, output_file)
    # return
  

if __name__ == '__main__':
    main()