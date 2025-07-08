import os, csv, copy
from typing import List, Tuple
from collections import defaultdict
from dataclasses import dataclass, field
from .utility_functions import is_equal, bigger_or_equal
from . import taxonomy_tree_parser as TaxonomyParser


#########################################################################################
#### ALIGNMENT DATA FUNCTIONS

@dataclass
class ResultInfo:
  contig_length: int = 0
  contig_coverage: List[float] = field(default_factory=list)
  hits_pident: List[Tuple[str, float]] = field(default_factory=list)
  
  def add_alignment_result(self, result_row):
    length   = int(result_row['qlen'])
    identity = float(result_row['pident'])
    qstart   = int(result_row['qstart'])
    qend     = int(result_row['qend'])
    subject  = result_row['sseqid'].strip()
    # init attributes when adding first result
    if self.contig_length == 0:
      self.contig_length = length
      self.contig_coverage = [0.0] * length
    elif self.contig_length != length:
      raise ValueError("Trying to include invalid result: "
        f"contig length: {self.contig_length} / result: {result_row}")
    # update coverage with best identity for position
    start = min(qstart, qend)
    end = max(qstart, qend)
    for i in range(start-1, end):
      if identity > self.contig_coverage[i]:
        self.contig_coverage[i] = identity
    # add hit identity
    self.hits_pident.append((subject, identity))
  
  def include_result_info(self, result_info):
    if self.contig_length != result_info.contig_length:
      raise ValueError("Trying to include invalid result: "
        f"contig length: {self.contig_length} / result: {result_row}")
    for i in range(self.contig_length):      
      if result_info.contig_coverage[i] > self.contig_coverage[i]:
        self.contig_coverage[i] = result_info.contig_coverage[i]
    self.hits_pident.extend(result_info.hits_pident)
  
  def get_stats_per_identity(self, min_identity):    
    values = [idt for idt in self.contig_coverage if bigger_or_equal(idt, min_identity)]
    mean_identity = sum(values) / len(values) if len(values) > 0 else 0
    coverage_percentage = len(values) * 100.0 / self.contig_length if self.contig_length > 0 else 0
    coverage_lenght = len(values)
    identity_hits = [sseqid for sseqid,idt in self.hits_pident if bigger_or_equal(idt, min_identity)]
    total_hits = len(identity_hits)
    unique_hits = len(set(identity_hits))
    return (mean_identity, coverage_percentage, coverage_lenght, total_hits, unique_hits)


#########################################################################################
#### GET RESULTS FROM ALIGNMENT FILE

def get_alignment_results(input_file):
  # fixing size limit error
  csv.field_size_limit(sys.maxsize)
  # Dictionary to store each query ID and its corresponding row
  alignment_results = []
  if os.path.exists(input_file) and os.path.getsize(input_file) > 0:
    # Open the alignment output file and use csv.DictReader to read it
    with open(input_file, 'r') as infile:      
      # remove comments and the last column 'salltitles'
      uncommented_lines = (line for line in infile if not line.startswith('#'))
      filtered_lines = (line.rsplit('\t', 1)[0] for line in uncommented_lines)
      # Use DictReader to automatically map columns to fieldnames
      reader = csv.DictReader(filtered_lines, delimiter='\t', fieldnames=[
        'qseqid', 'sseqid', 'pident', 'length', 'qlen', 'slen', 'qcovhsp',
        'mismatch', 'gapopen', 'gaps', 'qstart', 'qend', 'sstart', 'send',
        'evalue', 'bitscore', 'staxids']) #, 'salltitles'
      for row in reader:
        # append row
        alignment_results.append(row)
  return alignment_results


def get_contig_result_infos(alignment_results, contig, max_evalue=0.00001, min_length=200):
  # Dictionary to store each contig ResultInfo()
  contig_result_infos = defaultdict(ResultInfo)
  
  for row in alignment_results:
    # Store the first occurrence of each query in the dictionary
    contig_id = row['qseqid'].strip()
    evalue    = float(row['evalue'])
    length    = int(row['length'])
    taxids    = row['staxids'].strip().split(';')   
    if contig_id != contig:
      continue
    
    # already_included_hit = False
    if bigger_or_equal(max_evalue, evalue) and length >= min_length:
      for taxid in taxids:
        taxid = taxid.strip()
        if taxid != '':
          contig_result_infos[taxid].add_alignment_result(row)
        else:
          print(f"Query error invalid taxid: {taxid}; in row: {row}")
    else:
      print(f"Query didn't meet the filter criteria: {row}")
  return contig_result_infos


def get_best_hit_taxids(results, min_identity=97.0, min_coverage=95.0):
  best_taxids, best_coverage = [], 0
  # get result info stats with specified thresholds for each taxid
  for taxid, result_info in results.items():
    result_identity,result_coverage,_,_,_ = result_info.get_stats_per_identity(min_identity)
    if (bigger_or_equal(result_identity, min_identity) and
        bigger_or_equal(result_coverage, min_coverage)):
      # if identity is bigger than threshold the best hit is the best coverage
      if bigger_or_equal(result_coverage, best_coverage):
        if is_equal(result_coverage, best_coverage):
          best_coverage = min(best_coverage, result_coverage)
          best_taxids.append(taxid)
        else: # else if coverage is bigger
          best_coverage = result_coverage
          best_taxids = [taxid]
  return best_taxids


#########################################################################################
#### CALCULATE ALIGNMENT RESULTS PER LEVEL
def include_results_in_level(previous_results, level_results, level, taxonomy_tree):
  included_taxids = []
  for taxid, result_info in previous_results.items():
    if taxid not in taxonomy_tree:
      print(f"Taxid {taxid} not found in taxonomy tree, skipping.")
      continue
    node = taxonomy_tree[taxid]
    level_node = node.get_highest_node_at_level(level)
    if level_node is not None:
      if level_node.taxid not in level_results:
        level_results[level_node.taxid] = result_info
      else:
        level_results[level_node.taxid].include_result_info(result_info)
      included_taxids.append(taxid)  
  # Remove the included taxids from previous results
  for taxid in included_taxids:
    previous_results.pop(taxid)


def get_alignment_result_per_level(contig_results, level, previous_results, taxonomy_tree):
  level_results = {}
  # Try to include previous level results in current level
  include_results_in_level(previous_results, level_results, level, taxonomy_tree)
  include_results_in_level(contig_results, level_results, level, taxonomy_tree)
  # Keep the unused results in contig_results dict
  for taxid in previous_results:
    if taxid not in contig_results:
      contig_results[taxid] = previous_results[taxid]
    else:
      raise ValueError(f"Taxid {taxid} is in both contig_results and previous_results")
  # Return the level results
  return level_results


def load_alignment_results(contig_reads, alignment_file, align_filters,
  taxonomy_tree, output_unmatches_file, output_matches_file):
  """
  Load alignment results from alignment results file, filter the results
  by given filters, and write the unmatched contigs and matched contigs
  to different files.
  
  Parameters:
    contig_reads (dict): mapping of contigs
    alignment_file (str): alignment output file
    align_filters (dict): alignment filters
    taxonomy_tree (TaxonomyTree): taxonomy tree
    output_unmatches_file (str): file to write the unmatched contigs
    output_matches_file (str): file to write the matched contigs
  
  Returns:
    contig_results_by_level (dict): mapping of contig to alignment results by level
    contig_species_taxids (dict): mapping of contig to best hit taxids at species level
  """
  # initialize output content
  output_not_match = "contig\tread_count\n"
  output_matches = ("contig,level,parent_taxid,taxid,name,identity_threshold,"
    "mean_identity,coverage_perc,coverage_lenght,total_hits,unique_hits\n")
  identity_thresholds = [99, 98, 97, 95, 92, 90, 85, 80, 70, 60, 50, 40, 30]
  # identity_thresholds = [97, 90, 70, 50, 30]
  
  # get alignment results from file
  alignment_results = get_alignment_results(alignment_file)
  
  contig_species_taxids = {}  
  contig_results_by_level = defaultdict(dict)
  # get alignment results for the contigs
  for contig in contig_reads:
    # get contig alignment results
    print(f"Getting alignment results for contig {contig}: {str(contig_reads[contig])}")    
    contig_results = get_contig_result_infos(alignment_results, contig,
      align_filters['evalue'], align_filters['length'])
    # write unmatched contigs with alignment results
    if len(contig_results) == 0:
      output_not_match += f"{contig}\t{str(contig_reads[contig])}\n"
      continue
    
    level_results = {}
    # get result info per level
    for level in reversed(TaxonomyParser.level_list(above_level=1)):
      level_results = get_alignment_result_per_level(
        contig_results, level, level_results, taxonomy_tree)
      # collect matches by identity threshold
      for taxid, result_info in level_results.items():
        name = taxonomy_tree[taxid].name
        parent_node = taxonomy_tree[taxid].get_highest_node_at_next_level()
        parent_taxid = parent_node.taxid if parent_node is not None else "0"
        
        for min_idt in identity_thresholds:
          pidt,pcov,lcov,hits,uhits = result_info.get_stats_per_identity(min_idt)
          # write matches by identity threshold
          if hits > 0:
            output_matches += (f"{contig},{level},{parent_taxid},{taxid},"
              f"{name},{min_idt},{pidt},{pcov},{lcov},{hits},{uhits}\n")
      # save level_results in contig_results_by_level
      contig_results_by_level[contig][level] = copy.deepcopy(level_results)
    
    # get species result info
    species_results = contig_results_by_level[contig][TaxonomyParser.Level.S]
    print(f"{contig}: matched with species: {species_results.keys()}")
    # collect species taxids of best hits
    species_best_hit_taxids = get_best_hit_taxids(species_results,
      align_filters["identity"], align_filters["coverage"])
    contig_species_taxids[contig] = species_best_hit_taxids
    # write unmatched contigs at species level
    if len(species_best_hit_taxids) == 0:
      output_not_match += f"{contig}\t{str(contig_reads[contig])}\n"
  
  # write unmatched contigs to results
  with open(output_unmatches_file, "w") as unmatched_file:
    unmatched_file.write(output_not_match)
  # write matched contigs to results in different identity thresholds and levels
  with open(output_matches_file, "w") as matched_file:
    matched_file.write(output_matches)
  
  return contig_results_by_level, contig_species_taxids


#########################################################################################
#### MAIN TEST

def main():
  # File paths
  # Replace with your input BLAST output file path
  blast_file = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3.2-blastn_contigs_metaspades/SI035_1.txt"
  alignment_results = get_alignment_results(blast_file)
  mapping_file = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3.1-viral_discovery_mapping_metaspades/SI035_1_contig_reads.tsv"
  contig_reads, mapped_reads = count_contig_reads(mapping_file)
  for contig in contig_reads:
    contig_results = get_contig_results(alignment_results, contig)
    # accession_taxid = results_as_accession_to_taxid(contig_reads, query_to_row)
    # print(f"{accession_taxid}")


if __name__ == '__main__':
    main()