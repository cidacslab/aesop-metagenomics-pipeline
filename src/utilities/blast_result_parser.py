import csv, math
from dataclasses import dataclass, field

#########################################################################################
#### BLAST DATA FUNCTIONS

@dataclass
class ContigInfo:
  reads: set = field(default_factory=set)
  accession_read_count: dict = field(default_factory=dict)

  def add_read_by_accession(self, read_seqid: str):
    # if read_seqid not in self.reads:
    accession = read_seqid.rsplit('_', 2)[0]
    if accession not in self.accession_read_count:
      self.accession_read_count[accession] = 0
    self.accession_read_count[accession] += 1
    self.reads.add(read_seqid)


@dataclass
class ResultInfo:
  contig_length: int = 0
  contig_coverage: list[int] = None
  hits_pident: list[int] = field(default_factory=list)

  def add_result(self, result_row):
    length = int(result_row['qlen'])
    identity = float(result_row['pident'])
    qstart = int(result_row['qstart'])
    qend = int(result_row['qend'])
    # init attributes when adding first result
    if self.contig_length == 0:
      self.contig_length = length
      self.contig_coverage = [0] * length
    elif self.contig_length != length:
      raise ValueError("Trying to include invalid result: " +
        f"{self.contig_length}/{result_row}")
    # update coverage with best identity for position
    for i in range(qstart-1, qend):
      if identity > self.contig_coverage[i]:
        self.contig_coverage[i] = identity
    # add hit identity
    self.hits_pident.append(identity)
  
  def include_result_info(self, result_info):
    if self.contig_length != result_info.contig_length:
      raise ValueError("Trying to include invalid result: " + 
        f"{self.contig_length}/{result_info.contig_length}")
    for i in range(0, self.contig_length):      
      if result_info.contig_coverage[i] > self.contig_coverage[i]:
        self.contig_coverage[i] = result_info.contig_coverage[i]
    self.hits_pident.extend(result_info.hits_pident)
  
  def get_stats_per_identity(self, min_identity):    
    values = [idt for idt in self.contig_coverage if idt >= min_identity]
    mean_identity = sum(values) / len(values) if len(values) > 0 else 0
    identity_coverage = len(values) * 100.0 / self.contig_length
    identity_hits = sum([1 for idt in self.hits_pident if idt >= min_identity])
    coverage_lenght = len(values)
    return (mean_identity, identity_coverage, coverage_lenght, identity_hits)


def get_taxid_result_info(result_rows, min_identity=90):
  result = ResultInfo()
  for row in result_rows:    
    identity = int(result_row['pidentity'])
    if(identity >=min_identity):
      result.add_result(r)


def count_contig_reads(mapping_file, contig_to_reads, mapped_reads):
  # Dictionary to store contig to unique reads mapping
  # Open the file and read line by line
  with open(mapping_file, 'r') as file:
    reader = csv.reader(file, delimiter='\t')
    for row in reader:
      contig_name = row[0].strip()
      read_mapped_name = row[1].strip()
      if read_mapped_name not in mapped_reads:
        mapped_reads[read_mapped_name] = 0
      mapped_reads[read_mapped_name] += 1
      if mapped_reads[read_mapped_name] > 2: 
        print(f"** MAPPING ERROR: read {read_mapped_name} was mapped to a contig {mapped_reads[read_mapped_name]}x")
      # Add the read to the set for the given contig
      if contig_name not in contig_to_reads:
        contig_to_reads[contig_name] = ContigInfo()
      contig_to_reads[contig_name].add_read_by_accession(read_mapped_name)


def get_best_result(input_file, min_coverage=90, min_identity=97, max_evalue=0.00001, min_length=200):
  # Dictionary to store each query ID and its corresponding row
  contig_to_blast_result = {}
  # Open the BLAST output file and use csv.DictReader to read it
  with open(input_file, 'r') as infile:
    filtered_lines = (line for line in infile if not line.startswith('#'))
    # Use DictReader to automatically map columns to fieldnames
    reader = csv.DictReader(filtered_lines, delimiter='\t', fieldnames=[
      'qseqid', 'sseqid', 'pident', 'length', 'qcovs', 'qcovhsp', 'mismatch',
      'gapopen', 'gaps', 'qstart', 'qend', 'sstart', 'send', 'evalue', 
      'bitscore', 'staxids', 'salltitles'])
    
    for row in reader:
      # Store the first occurrence of each query in the dictionary
      contig_id = row['qseqid'].strip()
      identity = float(row['pident'])
      evalue = float(row['evalue'])
      length = float(row['length'])
      coverage = float(row.get('qcovs', 0))
      taxids = row['staxids'].strip()
      if not taxids:
        continue
      if contig_id not in contig_to_blast_result:
        if ((coverage >= min_coverage and identity >= min_identity and evalue <= max_evalue and length >= min_length) 
            or (coverage >= 90 and identity >= 99 and evalue <= 0.00001 and length >= 100)):
          contig_to_blast_result[contig_id] = row
        else:
          # print(f"Query didn't meet the filter criteria: {row}")
          print(f"Query didn't meet the filter criteria: {row['qseqid']}:{row['sseqid']}")
  return contig_to_blast_result


def get_blast_results(input_file):  
  # Dictionary to store each query ID and its corresponding row
  blast_results = []
  # Open the BLAST output file and use csv.DictReader to read it
  with open(input_file, 'r') as infile:
    filtered_lines = (line for line in infile if not line.startswith('#'))
    # Use DictReader to automatically map columns to fieldnames
    reader = csv.DictReader(filtered_lines, delimiter='\t', fieldnames=['qseqid', 'sseqid', 
      'pident', 'length', 'qlen', 'slen', 'mismatch', 'gapopen', 'gaps', 'qstart', 'qend',
      'sstart', 'send', 'evalue', 'bitscore', 'staxids', 'salltitles'])
    for row in reader:
      blast_results.append(row)
  return blast_results


def get_contig_results(blast_results, contig, max_evalue=0.00001, min_length=200):
  # Dictionary to store each contig ResultInfo()
  contig_results = {}
  
  for row in blast_results:
    # Store the first occurrence of each query in the dictionary
    contig_id = row['qseqid'].strip()
    evalue = float(row['evalue'])
    length = float(row['length'])
    taxids = row['staxids'].strip().split(';')   
    if contig_id != contig:
      continue
    
    if (evalue <= max_evalue and length >= min_length):
      for taxid in taxids:
        if taxid not in contig_results:
          contig_results[taxid] = ResultInfo()
        contig_results[taxid].add_result(row)
    else:
      print(f"Query didn't meet the filter criteria: {row}")
  return contig_results


def get_best_result(results, min_identity=97, min_coverage=95):
  best_taxids, best_identity, best_coverage = [], 0, 0
  
  for taxid, result_info in results.items():
    result_identity,result_coverage,_,_ = result_info.get_stats_per_identity(min_identity)
    if result_coverage >= min_coverage and result_identity >= min_identity:
      if (result_identity > best_identity or 
          (math.isclose(result_identity, best_identity, rel_tol=1e-3) and
          result_coverage > best_coverage)):
        best_coverage = result_coverage
        best_identity = result_identity
        best_taxids = [taxid]
      elif (math.isclose(result_identity, best_identity, rel_tol=1e-3) and 
            math.isclose(result_coverage, best_coverage, rel_tol=1e-3)):
        best_taxids.append(taxid)
  return best_taxids


def results_as_accession_to_taxid(contig_reads, query_to_row):
  accession_taxid = {}
  # Example: Print the dictionary for each query
  for query, row in query_to_row.items():
    if query in contig_reads:
      taxid = row['staxids']    
      contig_info = contig_reads[query]
      for accession, read_count in contig_info.accession_read_count.items():
        if accession not in accession_taxid:
          accession_taxid[accession] = {}
        if taxid not in accession_taxid[accession]:
          accession_taxid[accession][taxid] = 0          
        accession_taxid[accession][taxid] += read_count
  return accession_taxid


def main():
  # File paths
  # Replace with your input BLAST output file path
  blast_file = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3.2-blastn_contigs_metaspades/SI035_1.txt"
  query_to_row = get_best_result(blast_file)
  mapping_file = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3.1-viral_discovery_mapping_metaspades/SI035_1_contig_reads.tsv"
  contig_reads = count_contig_reads(mapping_file)
  accession_taxid = results_as_accession_to_taxid(contig_reads, query_to_row)
  print(f"{accession_taxid}")


if __name__ == '__main__':
    main()