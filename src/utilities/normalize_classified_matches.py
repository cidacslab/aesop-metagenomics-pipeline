import csv
from collections import defaultdict
from . import fastq_read_info as FastqReadInfo
from . import taxonomy_tree_parser as TaxonomyParser
from . import alignment_result_parser as AlignmentResultParser


#########################################################################################
#### LOAD READ COUNT
def count_contig_reads(mapping_file):
  # Dictionary to store contig to reads abudance
  # Open the file and read line by line
  contig_read_count = defaultdict(int)
  mapped_reads = defaultdict(int)
  with open(mapping_file, 'r') as file:
    reader = csv.reader(file, delimiter='\t')
    for row in reader:
      contig_name = row[0].strip()
      read_mapped_name = row[1].strip()
      mapped_reads[read_mapped_name] += 1
      if mapped_reads[read_mapped_name] > 2: 
        print(f"** MAPPING ERROR: read {read_mapped_name} was mapped to a contig " +
          f"{mapped_reads[read_mapped_name]} times")
      # Add the read to the set for the given contig
      contig_read_count[contig_name] += 1
  return contig_read_count, mapped_reads


def count_remaining_contigs_reads(remaining_contigs_file):
  total_abundance = 0
  contig_read_count = defaultdict(int)
  with open(remaining_contigs_file, "r") as file:
    reader = csv.reader(file, delimiter='\t')
    next(reader) # remove reader
    for row in reader:
      contig_name = row[0].strip()
      contig_count = int(row[1].strip())
      total_abundance += contig_count
      contig_read_count[contig_name] += contig_count
  return total_abundance, contig_read_count


#########################################################################################
#### NORMALIZE CLASSIFIED MATCHES
def normalize_classified_matches(total_reads, classified_tree, output_file):
  """
  Normalize classified matches by calculating the RPM (Reads Per Million) of each taxon.
  
  Parameters:
    total_reads (int): total number of reads in the sample
    classified_tree (dict): dictionary containing the classified tree with abundance
    output_file (str): output file name
  """
  print(f"Normalizing classified taxa: {output_file}")
  output_content = "level,parent_taxid,taxid,name,sample_total_reads,"
  output_content += "level_total_classified,nt_rpm\n"
  level_list = TaxonomyParser.level_list(above_level=1)
  included_taxids = set()
  
  for taxid,node in classified_tree.items():
    if (node.taxid not in included_taxids and node.acumulated_abundance > 0 and 
        node.level_enum in level_list and node.parent is not None and
        node.level_enum != node.parent.level_enum):
      # check if this node is the highest node at its level
      level_node = node.get_highest_node_at_level(node.level_enum)
      if level_node.taxid != node.taxid:
        continue
      # calculate the nt_rpm value
      abundance = node.acumulated_abundance
      nt_rpm = int((abundance*1000000)/total_reads)
      # get parent taxid as highest node at next level
      parent_node = node.get_highest_node_at_next_level()
      parent_taxid = parent_node.taxid if parent_node is not None else "0"
      # write the output content
      output_content += f"{node.level_enum},{parent_taxid},{node.taxid},{node.name},"
      output_content += f"{total_reads},{abundance},{nt_rpm}\n"
      included_taxids.add(node.taxid)
  
  with open(output_file, 'w') as file:
    file.write(output_content)


#########################################################################################
#### CALCULATE CONTIG READ COUNT
def load_read_count(count_reads_file, count_reads_extension, mapping_file, output_file):
  """
  Load the read count from either a fastq file or a csv file containing
  the remaining contigs after mapping.
  
  Parameters:
    count_reads_file (str): file containing the contig read count
    count_reads_extension (str): file extension of the count_reads_file
    mapping_file (str): csv file containing the mapping contigs to read names
  
  Returns:
    total_abundance (int): total number of reads
    contig_read_count (dict): mapping of contig_name to read count
    mapped_reads (dict): A mapping of read names to the number of times they were mapped.
  """
  # include the number of reads contig
  total_abundance, contig_read_count, mapped_reads = 0, {}, {}
  if count_reads_extension.endswith(".fastq.gz"):
    total_abundance = FastqReadInfo.get_total_abundance(count_reads_file)
    contig_read_count, mapped_reads = count_contig_reads(mapping_file)
    # double the abundance value to account for each mate from the sequencing
    total_abundance *= 2
  elif "_contig_unmatched_" in count_reads_extension:
    total_abundance, contig_read_count = count_remaining_contigs_reads(count_reads_file)
  else:
    print(f"Count read function doesn't exist for extension: {count_reads_extension}")

  # get contig read count
  output_content = "contig_name,read_count\n"
  for contig in contig_read_count:
    output_content += f"{contig},{contig_read_count[contig]}\n"
  # write output
  with open(output_file, "w") as file:
    file.write(output_content)
  
  return total_abundance, contig_read_count, mapped_reads


#########################################################################################
#### GET ALIGNMENT RESULTS
def load_alignment_tree(classified_tree, contig_read_count, alignment_file,
  align_filters, output_unmatches_file, output_matches_file):
  # clean the alignment result tree
  """
  Load the alignment results for the contigs and the reads mapped to each contig.
  
  Parameters:
    classified_tree (TaxonomyTree): The taxonomy tree representing alignment classified results.
    contig_read_count (dict): A mapping of contigs to the number of reads mapped to each contig.
    alignment_file (str): The file containing the alignment results.
    align_filters (dict): The alignment filters.
    output_unmatches_file (str): The file to write the alignment unmatched contigs.
    output_matches_file (str): The file to write the alignment matches.  
  
  The function cleans the alignment result tree, loads the alignment results for the contigs
  and the reads mapped to each contig, and adds the abundance of the best hit for each contig
  to the classified tree.
  """
  TaxonomyParser.clear_abundance_from_tree(classified_tree)
  
  # get alignment results for the contigs and the reads mapped to each contig
  _, contig_species_taxids = AlignmentResultParser.load_alignment_results(
    contig_read_count, alignment_file, align_filters, classified_tree,
    output_unmatches_file, output_matches_file)
    
  for contig in contig_species_taxids:
    species_best_taxids = contig_species_taxids[contig]
    if contig not in contig_read_count or len(species_best_taxids) == 0: 
      print(f"Didn't find best hit for species in {contig}")
      continue
    read_count = contig_read_count[contig]
    taxid = species_best_taxids[0]
    classified_tree[taxid].add_abundance(read_count)


#########################################################################################
## SET KRAKEN RESULT IN CLASSIFIED TREE

def include_k2result_for_unmatched(classified_tree, mapped_reads, kout_file):
  """
  Include the Kraken 2 result for reads that are not mapped to contigs in the classified tree.
  
  Parameters:
    classified_tree (TaxonomyTree): The taxonomy tree representing alignment classified results.
    mapped_reads (dict): A mapping of read names to the number of times they were mapped.
    kout_file (str): The file containing Kraken 2 results.
  
  The function reads the Kraken 2 output file and adds the abundance of unmapped reads
  to the classified tree for each taxid.
  """
  print(f"Get accession taxid abundance from: {kout_file}")
  with open(kout_file, "r") as kraken_file:
    for line in kraken_file:
      line = line.strip().split()
      if len(line) >= 3 and line[0] == "C":
        read_name = line[1].strip()
        taxid = line[2].strip()
        if len(read_name) == 0 or len(taxid) == 0 or taxid not in classified_tree:
          print(f"Error not included k2result: read_name: {read_name}, taxid: {taxid}")
          continue
        # get result if unmapped
        read_unmapped_count = 2 - mapped_reads.get(read_name, 0)
        if read_unmapped_count > 0:
          classified_tree[taxid].add_abundance(read_unmapped_count)


def load_kraken_tree(classified_tree, kreport_file):
  """
  Load and process Kraken report results, updating the classified taxonomy tree.
  
  Parameters:
    classified_tree (TaxonomyTree): The taxonomy tree representing Kraken classified results.
    kreport_file (str): The file containing Kraken report results.
  
  The function cleans the classified tree, processes the Kraken report results to find
  the best hit species for each read, and updates the classification tree based
  on these results.
  """
  # clean the kraken result tree
  TaxonomyParser.clear_abundance_from_tree(classified_tree)
  
  # create the classified_tree from the kraken report
  _, report_tree = TaxonomyParser.load_tree_from_kraken_report(kreport_file)  
  # set values from the kraken report in the classified_tree
  for k,node in report_tree.items():
    if k not in classified_tree:
      print(f"Node not found in taxonomy tree: {node}")
    elif node.abundance > 0:
      classified_tree[k].add_abundance(node.abundance * 2)