import os, sys, shutil, csv, copy
from dataclasses import dataclass, field
import kraken_report_parser as KrakenParser
from utility_functions import get_files_in_folder
from get_fastq_read_info import count_reads_by_sequence_id


#########################################################################################[
#### BLAST DATA FUNCTIONS

@dataclass
class ContigInfo:
  reads: set = field(default_factory=set)
  read_accession: dict = field(default_factory=dict)

  def add_read(self, read_seqid: str):
    # if read_seqid not in self.reads:
    accession = read_seqid.rsplit('_', 2)[0]
    if accession not in self.read_accession:
      self.read_accession[accession] = 0
    self.read_accession[accession] += 1
    self.reads.add(read_seqid)


def count_contig_unique_reads(mapping_file):
  # Dictionary to store contig to unique reads mapping
  contig_to_reads = {}
  # Open the file and read line by line
  with open(mapping_file, 'r') as file:
    reader = csv.reader(file, delimiter='\t')
    for row in reader:
      contig_name = row[0].strip()
      read_mapped_name = row[1].strip()
      # Add the read to the set for the given contig
      if contig_name not in contig_to_reads:
        contig_to_reads[contig_name] = ContigInfo()
      contig_to_reads[contig_name].add_read(read_mapped_name)
  return contig_to_reads


def get_blast_results(input_file):
  # Dictionary to store each query ID and its corresponding row
  contig_to_blast_result = {}
  # Open the BLAST output file and use csv.DictReader to read it
  with open(input_file, 'r') as infile:
    filtered_lines = (line for line in infile if not line.startswith('#'))
    # Use DictReader to automatically map columns to fieldnames
    reader = csv.DictReader(filtered_lines, delimiter='\t', fieldnames=[
      'qseqid', 'sseqid', 'pident', 'length', 'mismatch', 'gapopen', 
      'qstart', 'qend', 'sstart', 'send', 'evalue', 'bitscore', 
      'staxids', 'salltitles'])
    for row in reader:
      # Store the first occurrence of each query in the dictionary
      contig_id = row['qseqid']
      identity = float(row['pident'])
      evalue = float(row['evalue'])
      length = float(row['length'])
      if contig_id not in contig_to_blast_result:
        if identity < 95 and evalue > 0.00001 and length < 200:
          print(f"Query didn't meet the filter criteria: {row}")
        else:          
          contig_to_blast_result[contig_id] = row
  return contig_to_blast_result


def load_blast_results(contig_reads, contig_to_blast_result, blast_taxid_to_species_taxid, \
                        accession_species_taxid, blast_classified_tree, true_positive_tree):
  # Example: Print the dictionary for each contig
  for contig, blast_result in contig_to_blast_result.items():
    if contig in contig_reads:
      contig_info = contig_reads[contig]
      taxid = blast_result['staxids'].strip()
      species_taxid = blast_taxid_to_species_taxid[taxid]
      print(f"{contig}: {contig_info.read_accession}")
      for accession, read_count in contig_info.read_accession.items():
        blast_classified_tree[species_taxid].set_abundance(read_count)
        accession_taxid = accession_species_taxid.get(accession, 0)
        # run through the accession node and the true positive node until find root
        # looking if there is an equal taxid in any step of the route
        true_node = true_positive_tree[species_taxid]
        accession_node = true_positive_tree.get(accession_taxid, None)
        is_true_positive = False
        while not is_true_positive and true_node is not None:
          node = accession_node
          while not is_true_positive and node is not None:
            if node.taxid == true_node.taxid:
              node.set_abundance(read_count)
              is_true_positive = True
              # print(f"For {accession}:{taxid} found true positive node {node} for {accession}:{species_taxid}:{accession_true_node}")
            node = node.parent
          true_node = true_node.parent
        if not is_true_positive:
          print(f"False positive for contig {contig}:{species_taxid} got mapped by {accession}:{accession_taxid}")
    else:
      print(f"Contig {contig} had no read mapped!")

#### INCLUDE BLAST METADATA
def update_report_tree_with_metadata_blast(metadata_file, all_classified_tree):  
  print(f"Get accession taxa tree from: {metadata_file}")
  print(f"Initial report tree size: {len(all_classified_tree)}")
  taxid_to_species_taxid = {}

  with open(metadata_file, "r") as file:
    csv_reader = csv.reader(file)
    # next(csv_reader)
    for row in csv_reader:
      domain = row[1].strip().lower()
      if domain != "viruses":
        continue
      # update accession taxid
      taxid = row[0].strip()
      species_taxid = row[-1].strip()
      taxid_to_species_taxid[taxid] = species_taxid
      # update report tree
      names = row[1:8]
      taxids = row[8:]
      domain_taxid = taxids[0].strip()
      last_node = all_classified_tree[domain_taxid]
      for i in range(1, 7):
        taxid = taxids[i].strip()
        if not taxid:
          continue
        if taxid not in all_classified_tree:
          level = KrakenParser.Level(i + 3).name
          node = KrakenParser.TreeNode(names[i], taxid, level)
          node.set_parent(last_node)
          all_classified_tree[taxid] = node
          # print(names)
          # print(taxids)
          # print(f"  Included node {i}: {node}")
        else:
          node = all_classified_tree[taxid]
        last_node = node
  print(f"Final all_classified_tree size: {len(all_classified_tree)}")
  return taxid_to_species_taxid

#########################################################################################
#### INCLUDE SAMPLES METADATA

def update_report_tree_with_metadata_taxa(metadata_file, all_classified_tree):  
  print(f"Get accession taxa tree from: {metadata_file}")
  print(f"Initial report tree size: {len(all_classified_tree)}")
  accession_species_taxid = {}

  with open(metadata_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      domain = row[2].strip().lower()
      if domain != "viruses":
        continue
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
        taxid = taxids[i].strip()
        if not taxid:
          continue
        if taxid not in all_classified_tree:
          level = KrakenParser.Level(i + 3).name
          node = KrakenParser.TreeNode(names[i], taxid, level)
          node.set_parent(last_node)
          all_classified_tree[taxid] = node
          # print(f"  Included node {node}")
        else:
          node = all_classified_tree[taxid]
          # if node.parent.taxid != last_node.taxid:
          #   node.set_parent(last_node)
        last_node = node
  print(f"Final all_classified_tree size: {len(all_classified_tree)}")
  return accession_species_taxid



def set_ground_truth_tree_real_counts(accession_abundance, accession_species_taxid, ground_truth_tree, output_file):
  KrakenParser.clear_abundance_from_tree(ground_truth_tree)
  output_content = "read_accession_id,count\n"
  total_abundance = 0

  for accession in accession_species_taxid:
    abundance = accession_abundance[accession].count
    taxid = accession_species_taxid[accession]
    ground_truth_tree[taxid].set_abundance(abundance)
    output_content += f"{accession},{abundance}\n"
    total_abundance += abundance

  with open(output_file, "w") as out_file:
    out_file.write(output_content)

  return total_abundance



def set_ground_truth_tree_real_counts_from_ground_truth_file(ground_truth_file, accession_species_taxid, ground_truth_tree):
  KrakenParser.clear_abundance_from_tree(ground_truth_tree)
  total_abundance = 0

  with open(ground_truth_file, "r") as file:
    csv_reader = csv.reader(file)
    next(csv_reader)
    for row in csv_reader:
      accession = row[0].strip()
      abundance = row[1].strip()
      taxid = accession_species_taxid[accession]
      ground_truth_tree[taxid].set_abundance(abundance)  
      total_abundance += abundance

  return total_abundance
  


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
  # loop through all accessions
  for accession, species_taxid in accession_species_taxid.items():
    for taxid in accession_taxid_counts[accession]:
      abundance = accession_taxid_counts[accession][taxid]
      accession_true_node = true_positive_tree[species_taxid]
      classified_node = true_positive_tree.get(taxid, None)
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



def calculate_confusion_matrix(accession_species_taxid, sample_total_reads, ground_truth_tree, true_positive_tree, all_classified_tree, output_file):
  print(f"Calculating confusion matrix: {output_file}")
      
  output_content = "accession_id,total_reads,genus,genus_taxid,genus_true_positive,genus_true_negative,"
  output_content += "genus_false_positive,genus_false_negative,species,species_taxid,species_true_positive,"
  output_content += "species_true_negative,species_false_positive,species_false_negative\n"

  for accession in accession_species_taxid:
    species_taxid = accession_species_taxid[accession]
    accession_species_node = ground_truth_tree[species_taxid]
    accession_total_reads = accession_species_node.acumulated_abundance

    species_name = accession_species_node.name
    species_total_reads = accession_species_node.acumulated_abundance
    species_correct_reads = true_positive_tree[species_taxid].acumulated_abundance
    species_total_classified = all_classified_tree[species_taxid].acumulated_abundance
    
    accession_genus_node = accession_species_node.parent
    while accession_genus_node.parent.level_enum == KrakenParser.Level.G:
      accession_genus_node = accession_genus_node.parent

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
  base_path = "./data/dataset_mock"
  input_extension = "_1.fastq.gz"
  # input_fastq_path = os.path.join(base_path, "mock_metagenomes")
  # input_fastq_path = os.path.join(base_path, "1.2-bowtie_ercc_output")
  input_fastq_path = os.path.join(base_path, "4.1-viral_discovery_reads")
  input_kraken_path = os.path.join(base_path, "3-taxonomic_output")
  input_mapping_path = os.path.join(base_path, "4.3.1-viral_discovery_mapping_metaspades")
  input_blast_path = os.path.join(base_path, "4.3.2-blastn_contigs_metaspades")
  input_taxonkit_path = os.path.join(base_path, "4.3.3-blastn_taxonkit_metaspades")
  input_metadata_path = os.path.join(base_path,  "metadata")
  output_path = os.path.join(base_path, "performance_metrics")
  
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
    _, report_tree = KrakenParser.load_kraken_report_tree(report_file)
    # set Viruses Domain as root and deletes the rest of the tree
    viruses_root = report_tree["10239"]
    viruses_root.parent = None
    # get all viruses nodes and set them as kraken result tree
    kraken_classified_tree = {}
    viruses_root.get_all_nodes(kraken_classified_tree)

    meta_filename = filename.rsplit("_", 1)[0]
    # meta_filename = "_".join(splits[0:-2])
    metadata_file = os.path.join(input_metadata_path, meta_filename + "_metadata.csv")
    # add the taxa from the accession metadata if they are not in the classified tree
    accession_species_taxid = update_report_tree_with_metadata_taxa(metadata_file, kraken_classified_tree)
    # add the taxa from the blast result metadata if they are not in the classified tree
    blast_metadata_file = os.path.join(input_taxonkit_path, filename + "_metadata.csv")
    blast_taxid_to_species_taxid = update_report_tree_with_metadata_blast(blast_metadata_file, kraken_classified_tree)
    # double the abundance value to account for each mate from the sequencing
    for k,node in kraken_classified_tree.items():
      node.acumulated_abundance *= 2

    #######################################################################################################
    # create the ground truth tree with the real taxa from the mocks and the number of reads from each one
    ground_truth_tree = copy.deepcopy(kraken_classified_tree)
    KrakenParser.clear_abundance_from_tree(ground_truth_tree)

    # include the number of reads of each accession as the abundance of each taxa species
    accession_abundance = count_reads_by_sequence_id(fastq_file)
    output_ground_truth_file = os.path.join(output_path, filename + "_ground_truth.csv")
    total_abundance = set_ground_truth_tree_real_counts(accession_abundance, accession_species_taxid, ground_truth_tree, output_ground_truth_file)
    # set_ground_truth_tree_real_counts_from_ground_truth_file(output_ground_truth_file, accession_species_taxid, ground_truth_tree)
    # double the abundance value to account for each mate from the sequencing
    for k,node in ground_truth_tree.items():
      node.acumulated_abundance *= 2
    total_abundance *= 2

    #######################################################################################################
    # create the true positive tree adding the abundance only if they are correctly mapped
    true_positive_tree = copy.deepcopy(kraken_classified_tree)
    KrakenParser.clear_abundance_from_tree(true_positive_tree)
    # create the blast result tree
    blast_classified_tree = copy.deepcopy(kraken_classified_tree)
    KrakenParser.clear_abundance_from_tree(blast_classified_tree)  
    # get blast results for the contigs and the reads mapped to each contig
    blast_file = os.path.join(input_blast_path, filename + ".txt")
    contig_to_blast_result = get_blast_results(blast_file)
    mapping_file = os.path.join(input_mapping_path, filename + "_contig_reads.tsv")
    contig_reads = count_contig_unique_reads(mapping_file)
    # Set blast result tree and the true positive tree
    load_blast_results(contig_reads, contig_to_blast_result, blast_taxid_to_species_taxid, \
      accession_species_taxid, blast_classified_tree, true_positive_tree)
    # Calculate confusion matrix for blast
    output_file = os.path.join(output_path, filename + "_blast_metrics.csv")
    calculate_confusion_matrix(accession_species_taxid, total_abundance, ground_truth_tree, true_positive_tree, blast_classified_tree, output_file)
    
    #######################################################################################################     
    # create the true positive tree adding the abundance only if they are correctly mapped
    true_positive_tree = copy.deepcopy(kraken_classified_tree)
    KrakenParser.clear_abundance_from_tree(true_positive_tree)

    accession_taxid_abundance_file = os.path.join(input_kraken_path, filename + ".kout")
    output_class_file = os.path.join(output_path, filename + "_classified.csv")
    accession_taxid_counts = get_accession_taxid_abundance(accession_taxid_abundance_file, output_class_file)
    # double the abundance value to account for each mate from the sequencing
    for accession in accession_taxid_counts:
      for taxid in accession_taxid_counts[accession]:
        accession_taxid_counts[accession][taxid] *= 2
    # accession_taxid_counts = get_accession_taxid_abundance_from_classified_file(output_class_file)
    set_true_positive_tree_counts(accession_taxid_counts, accession_species_taxid, true_positive_tree)

    # Calculate confusion matrix for kraken
    output_file = os.path.join(output_path, filename + "_kraken_metrics.csv")
    calculate_confusion_matrix(accession_species_taxid, total_abundance, ground_truth_tree, true_positive_tree, kraken_classified_tree, output_file)
  
    # for accession,taxid in accession_species_taxid.items():
    #   domain = ground_truth_tree[taxid].get_parent_by_level(KrakenParser.Level.D)
    #   if(domain != "viruses"):
    #     continue
    #   ground_abundance = ground_truth_tree[taxid].acumulated_abundance
    #   kraken_abundance = kraken_classified_tree[taxid].acumulated_abundance
    #   blast_abundance = blast_classified_tree[taxid].acumulated_abundance
    #   true_positive_abundance = true_positive_tree[taxid].acumulated_abundance
      
    #   print(f"{accession}:{taxid} -> {ground_abundance} ; {kraken_abundance} ;" + \
    #     f" {blast_abundance} ; {true_positive_abundance}")

  

if __name__ == '__main__':
    main()