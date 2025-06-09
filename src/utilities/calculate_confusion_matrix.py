import csv, copy
from . import taxonomy_tree_parser as TaxonomyParser
from . import blast_result_parser as BlastResultParser
from . import get_fastq_read_info as FastqReadInfo


#########################################################################################
#### INCLUDE SAMPLES METADATA
def load_accession_metadata(metadata_file):  
  accession_taxids = {}  
  with open(metadata_file, "r") as file:
    for line in file:
      row = line.split("\t")
      # update accession taxid
      accession = row[0].strip()
      taxid = row[1].strip()
      accession_taxids[accession] = taxid
  return accession_taxids

#########################################################################################
## SET GROUND TRUTH
def count_remaining_contigs_to_reads(remaining_contigs_file, contig_to_reads):
  accession_read_abundance = {}
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
  return accession_read_abundance


def set_ground_truth_tree_real_counts(accession_abundance, accession_taxids, ground_truth_tree, output_file):
  output_content = "read_accession_id,count\n"
  
  for accession, taxid in accession_taxids.items():
    if accession in accession_abundance:
      abundance = accession_abundance[accession].count
      ground_truth_tree[taxid].add_abundance(abundance)
      output_content += f"{accession},{abundance}\n"
    else:
      print(f"Accession {accession} not present in ground truth.")
  
  with open(output_file, "w") as out_file:
    out_file.write(output_content)


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
      classified_node.add_abundance(count)
      is_true_positive = True
    else:
      classified_node = classified_node.parent
  # return the true positive match or None
  return classified_node if is_true_positive else None


def load_blast_results(contig_reads, contig_to_blast_result, accession_taxids,
  blast_classified_tree, true_positive_tree, output_no_matched_contig_file):
  """
  Process BLAST results and update the classification and true positive trees.
  Parameters:
    contig_reads (dict): Mapping of contig to its read information.
    contig_to_blast_result (dict): Mapping of contig to its BLAST result.
    accession_taxids (dict): Mapping of accession to taxid.
    blast_classified_tree (TaxonomyTree): Tree representing classified results from BLAST.
    true_positive_tree (TaxonomyTree): Tree representing true positive results.
    output_no_matched_contig_file (str): File path to output contigs with no matches.
  
  The function iterates over contigs, updating the blast classified and true positive trees
  based on BLAST results. It writes contigs with no BLAST matches to a specified output file.
  """
  # initialize output content
  output_content = "contig\tread_count\n"
  
  for contig, contig_info in contig_reads.items():
    if contig in contig_to_blast_result:
      print(f"{contig}: {contig_info.accession_read_count}")
      # contig_info = contig_reads[contig]
      blast_result = contig_to_blast_result[contig]
      taxid = blast_result['staxids'].strip().split(";")[0]
      for accession, read_count in contig_info.accession_read_count.items():
        blast_classified_tree[taxid].add_abundance(read_count)
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


def include_results_in_level(previous_results, level_results, included_taxids, level, taxonomic_tree):
  for taxid, result_info in previous_results.items():
    node = taxonomic_tree[taxid]  
    level_enum = TaxonomyParser.Level(level)
    level_node = node.get_parent_by_level(level_enum)
    if level_node is not None:
      if level_node.taxid not in level_results:
        level_results[level_node.taxid] = result_info
      else:
        level_results[level_node.taxid].include_result_info(result_info)
      included_taxids.append(taxid)


def get_blast_result_per_level(contig_results, level, previous_results, taxonomic_tree):
  level_results, included_taxids = {}, []
  # Try to include previous results in current level
  include_results_in_level(previous_results, level_results, included_taxids, level, taxonomic_tree)
  include_results_in_level(contig_results, level_results, included_taxids, level, taxonomic_tree)
  # Remove the included taxids from previous results
  for taxid in included_taxids:
    contig_results.pop(taxid, None)
    previous_results.pop(taxid, None)
  # Keep the unused results in contig_results dict
  for taxid in previous_results:
    contig_results[taxid] = previous_results[taxid]
  
  return level_results


def load_best_blast_results(contig_reads, blast_results, align_filters, accession_taxids, 
  blast_classified_tree, true_positive_tree, output_unmatches_file, output_matches_file):
  """
  Process BLAST results and update the classification and true positive trees.
  Parameters:
    contig_reads (dict): Mapping of contig to its read information.
    contig_to_blast_result (dict): Mapping of contig to its BLAST result.
    accession_taxids (dict): Mapping of accession to taxid.
    blast_classified_tree (TaxonomyTree): Tree representing classified results from BLAST.
    true_positive_tree (TaxonomyTree): Tree representing true positive results.
    output_no_matched_contig_file (str): File path to output contigs with no matches.
  
  The function iterates over contigs, updating the blast classified and true positive trees
  based on BLAST results. It writes contigs with no BLAST matches to a specified output file.
  """
  # initialize output content
  output_not_match = "contig\tread_count\n"
  output_matches = "contig,level,taxid,name,identity_threshold,mean_identity,identity_coverage,coverage_lenght,identity_hits\n"
  identity_thresholds = [99, 98, 97, 95, 92, 90, 85, 80, 70, 60, 50, 40, 30]  
  # identity_thresholds = [97, 90, 70, 50, 30]
  
  for contig, contig_info in contig_reads.items():    
    contig_results = BlastResultParser.get_contig_results(
      blast_results, contig, align_filters['evalue'], align_filters['length'])
    if len(contig_results) == 0:
      output_not_match += f"{contig}\t{str(contig_info.accession_read_count)}\n"
      continue    
    print(f"{contig}: {contig_info.accession_read_count}")
    
    level_results = {}
    species_results = {}
    for level in range(9, 1, -1):
      level_results = get_blast_result_per_level(
        contig_results, level, level_results, blast_classified_tree)
      if level == 9:
        species_results = copy.deepcopy(level_results) # save species level_results
      for taxid, result_info in level_results.items():
        for min_identity in identity_thresholds:
          idt,cov,hits,length = result_info.get_stats_per_identity(min_identity)
          name = blast_classified_tree[taxid].name
          output_matches += f"{contig},{level},{taxid},{name},{min_identity},{idt},{cov},{length},{hits}\n"
    
    print(f"{contig}: matched with species: {species_results.keys()}")
    best_taxids = BlastResultParser.get_best_result(
      species_results, align_filters["identity"], align_filters["coverage"])
    if len(best_taxids) == 0:
      output_not_match += f"{contig}\t{str(contig_info.accession_read_count)}\n"
      continue
    
    for accession, read_count in contig_info.accession_read_count.items():
      true_taxid = accession_taxids.get(accession, 0)
      true_node = true_positive_tree.get(true_taxid, None)
      true_species = true_node.get_parent_by_level(TaxonomyParser.Level.S) if true_node is not None else None
      # get true tax id at species level
      true_species_taxid = true_species.taxid if true_species is not None else 0
      taxid = best_taxids[0]
      # check if true species taxid is in best taxids
      for taxid in best_taxids:
        if taxid == true_species_taxid:
          break
      # set classified tree for chosen taxid
      blast_classified_tree[taxid].add_abundance(read_count)
      # set true positive tree
      blast_node = set_true_positive_in_taxonomy(true_taxid, taxid, true_positive_tree, read_count)
      is_true_positive = blast_node is not None
      print(f"{is_true_positive} positive for contig {contig}:{taxid} mapped {read_count} reads " + \
            f"from {accession}:{true_taxid}:{blast_node}.")
  
  with open(output_unmatches_file, "w") as out_file:
    out_file.write(output_not_match)
  
  with open(output_matches_file, "w") as contig_file:
    contig_file.write(output_matches)


#########################################################################################
## INCLUDE KRAKEN RESULT

def include_k2result_for_unmatched(classified_tree, true_positive_tree, accession_taxids, mapped_reads, kout_file):
  print(f"Get accession taxid abundance from: {kout_file}")
  k2result_accession_to_taxid = {}
  with open(kout_file, "r") as kraken_file:
    for line in kraken_file:
      line = line.strip().split()
      if len(line) >= 3 and line[0] == "C":
        read_name = line[1].strip()
        accession_id = read_name.rsplit('_', 2)[0]
        taxid = line[2].strip()
        if len(accession_id) == 0 or len(taxid) == 0:
          continue
        # get result if unmapped
        read_unmapped_count = 2 - mapped_reads.get(read_name, 0)
        if read_unmapped_count > 0:
          classified_tree[taxid].add_abundance(read_unmapped_count)
          true_taxid = accession_taxids[accession_id]
          set_true_positive_in_taxonomy(true_taxid, taxid, true_positive_tree, read_unmapped_count)
        # get result by accession
        if accession_id not in k2result_accession_to_taxid:
          k2result_accession_to_taxid[accession_id] = {}
        if taxid not in k2result_accession_to_taxid[accession_id]:
          k2result_accession_to_taxid[accession_id][taxid] = 0
        k2result_accession_to_taxid[accession_id][taxid] += 1
  return k2result_accession_to_taxid


## INCLUDE KRAKEN TRUE POSITIVE RESULT
def set_true_positive_tree_counts(k2result_accession_to_taxid, accession_taxids, true_positive_tree):
  # loop through all accessions
  for accession, true_taxid in accession_taxids.items():
    if accession not in k2result_accession_to_taxid:
      continue
    for taxid in k2result_accession_to_taxid[accession]:
      count = k2result_accession_to_taxid[accession][taxid]      
      # set true positive tree
      classified_node = set_true_positive_in_taxonomy(true_taxid, taxid, true_positive_tree, count)
      is_true_positive = classified_node is not None
      #if not is_true_positive:
      print(f"{is_true_positive} positive for {accession}:{true_taxid} mapping {count} reads " + \
            f"to {taxid}:{classified_node}")


#########################################################################################
#### CALCULATE CONFUSION MATRIX
def get_confusion_matrix_values(sample_total_reads, total_tax_reads, total_mapped_to_tax, correct_tax_reads):
  """
  Calculate the values for a single node in the confusion matrix.
  Parameters:
    sample_total_reads (int): total number of reads in the sample
    total_tax_reads (int): total number of reads from the taxid
    total_mapped_to_tax (int): total number of reads mapped to the taxid
    correct_tax_reads (int): total number of reads correctly mapped to the taxid
  Returns:
    tuple: containing the true positive, true negative, false positive, and false negative values
  """
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


def get_output_for_confusion_matrix(
  node, parent_taxid, included_taxids, sample_total_reads,
  ground_truth_tree, true_positive_tree, classified_tree):
  """
  Get the output for a single node in the confusion matrix.
  Parameters:
    node (Node): node to get the output for
    included_taxids (set): set of taxids already included in the output
    sample_total_reads (int): total number of reads in the sample
    ground_truth_tree (TaxonomyTree): ground truth tree
    true_positive_tree (TaxonomyTree): true positive tree
    classified_tree (TaxonomyTree): classified tree
  Returns:
    str: output for the node in the confusion matrix
  """
  output_content = ""  
  if node.taxid not in included_taxids:
    total_reads = node.acumulated_abundance
    correct_reads = true_positive_tree[node.taxid].acumulated_abundance
    total_classified = classified_tree[node.taxid].acumulated_abundance
    #print(f"{node.taxid}, {node.name}, {total_reads}, {correct_reads}, {total_classified}")
    metrics = get_confusion_matrix_values(sample_total_reads, total_reads, total_classified, correct_reads)
    output_content += f"{node.level_enum},{parent_taxid},{node.taxid},{node.name},{sample_total_reads},"
    output_content += f"{total_reads},{total_classified},{correct_reads},"
    output_content += f"{metrics[0]},{metrics[1]},{metrics[2]},{metrics[3]}\n"
    included_taxids.add(node.taxid)
  return output_content


def calculate_confusion_matrix(
  accession_taxids, sample_total_reads, ground_truth_tree,
  true_positive_tree, classified_tree, output_file):
  """
  Calculate the confusion matrix for the given accession-taxid mapping.
  Parameters:
    accession_taxids (dict): mapping of accession to taxid
    sample_total_reads (int): total number of reads in the sample
    ground_truth_tree (TaxonomyTree): ground truth tree
    true_positive_tree (TaxonomyTree): true positive tree
    classified_tree (TaxonomyTree): classified tree
    output_file (str): file to write the output to
  """
  print(f"Calculating confusion matrix: {output_file}")
  output_content = "level,parent_taxid,taxid,name,sample_total_reads,level_total_reads,"
  output_content += "level_total_classified,level_correct_reads,"
  output_content += "true_positive,true_negative,false_positive,false_negative\n"
  included_taxids = set()
  
  parent_taxid = 0
  for accession, taxid in accession_taxids.items():
    node = ground_truth_tree[taxid]
    accession_total_reads = node.acumulated_abundance
    
    domain_node = node.get_parent_by_level(TaxonomyParser.Level.D)
    if domain_node.name.lower() != "viruses":
      output_content += get_output_for_confusion_matrix(
        domain_node, parent_taxid, included_taxids, sample_total_reads,
        ground_truth_tree, true_positive_tree, classified_tree)  
      continue
    
    nodes_by_level = []
    for level in range(9, 1, -1):
      level_enum = TaxonomyParser.Level(level)
      level_node = node.get_parent_by_level(level_enum)
      if level_node is not None:
        nodes_by_level.append(level_node)
    
    for i in range(len(nodes_by_level)):
      level_node = nodes_by_level[i]
      parent_taxid = nodes_by_level[i+1].taxid if i+1 < len(nodes_by_level) else 0
      output_content += get_output_for_confusion_matrix(
        level_node, parent_taxid, included_taxids, sample_total_reads,
        ground_truth_tree, true_positive_tree, classified_tree)
  
  with open(output_file, "w") as out_file:
    out_file.write(output_content)

#########################################################################################
#### LOAD TAXONOMY TREES
#########################################################################################
def load_ground_truth_tree(
  ground_truth_tree, accession_taxids, count_reads_file,
  count_reads_extension, contig_reads, filename, output_file):
  """
  Create the ground truth tree with the real taxa from the mocks and the number of reads from each one.
  Parameters:
    ground_truth_tree (TaxonomyTree): ground truth tree
    accession_taxids (dict): mapping of accession to taxid
    count_reads_file (str): file to read the number of reads from each accession
    count_reads_extension (str): file extension for the type of count read function to use
    contig_reads (dict): mapping of contig to reads
    filename (str): filename to use for the output
    output_file (str): file to write the output to  
  Returns:
    dict: mapping of accession to count
  """
  # clean the ground truth tree
  TaxonomyParser.clear_abundance_from_tree(ground_truth_tree)
  
  # include the number of reads of each accession as the abundance of each taxa species
  accession_abundance = {}
  if count_reads_extension.endswith(".fastq.gz"):
    accession_abundance = FastqReadInfo.count_reads_by_sequence_id(count_reads_file)
    # double the abundance value to account for each mate from the sequencing
    for acc in accession_abundance:
      accession_abundance[acc].count *= 2
  elif count_reads_extension.endswith("_contig_not_matched_blast.tsv"):
    accession_abundance = count_remaining_contigs_to_reads(count_reads_file, contig_reads)
  else:
    print(f"Count read function doesn't exist for extension: {count_reads_extension}")
    return  
  
  # set counts on the ground_truth_tree
  set_ground_truth_tree_real_counts(
    accession_abundance, accession_taxids, ground_truth_tree, output_file)
  
  return accession_abundance


def load_blast_tree(classified_tree, true_positive_tree, accession_taxids, contig_reads,
  align_filters, blast_file, mapping_file, output_unmatches_file, output_matches_file):  
  """
  Calculate the blast classified tree and the true positive tree.
  Parameters:
    classified_tree (TaxonomyTree): blast classified tree
    true_positive_tree (TaxonomyTree): true positive tree
    accession_taxids (dict): mapping of accession to taxid
    contig_reads (dict): mapping of contig to reads
    align_filters (AlignmentFilters): alignment filters
    blast_file (str): blast output file
    mapping_file (str): file to map reads to contigs
    output_file (str): file to write the output to
  """
  # clean the true positive tree
  TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
  # clean the blast result tree
  TaxonomyParser.clear_abundance_from_tree(classified_tree)
  
  mapped_reads = {}
  # get blast results for the contigs and the reads mapped to each contig
  blast_result = BlastResultParser.get_blast_results(blast_file)
  if len(contig_reads) == 0:
    BlastResultParser.count_contig_reads(mapping_file, contig_reads, mapped_reads)
  
  # Set blast classified tree and the true positive
  load_best_blast_results(contig_reads, blast_result, align_filters, accession_taxids,
    classified_tree, true_positive_tree, output_unmatches_file, output_matches_file)
  return mapped_reads


def load_kraken_tree(
  classified_tree, true_positive_tree, accession_taxids,
  kreport_file, k2result_accession_to_taxid):
  """
  Calculate the kraken classified tree and the true positive tree.
  Parameters:
    classified_tree (TaxonomyTree): kraken classified tree
    true_positive_tree (TaxonomyTree): true positive tree
    accession_taxids (dict): mapping of accession to taxid
    kreport_file (str): kraken report file
    k2result_accession_to_taxid (dict): read accession to kraken result taxid
  """
  # clean the true positive tree
  TaxonomyParser.clear_abundance_from_tree(true_positive_tree)
  # clean the kraken result tree
  TaxonomyParser.clear_abundance_from_tree(classified_tree)
  
  # create the classified_tree from the kraken report
  _, report_tree = TaxonomyParser.load_tree_from_kraken_report(kreport_file)  
  # set values from the kraken report in the classified_tree
  for k,node in report_tree.items():
    if k not in classified_tree:
      print(f"Node not found in taxonomy tree: {node}")
    else:
      classified_tree[k].add_abundance(node.abundance * 2)
  
  # double the abundance value to account for each mate from the sequencing
  for accession in k2result_accession_to_taxid:
    for taxid in k2result_accession_to_taxid[accession]:
      k2result_accession_to_taxid[accession][taxid] *= 2
  
  # create the true positive tree adding the abundance only if they are correctly mapped
  set_true_positive_tree_counts(
    k2result_accession_to_taxid, accession_taxids, true_positive_tree)