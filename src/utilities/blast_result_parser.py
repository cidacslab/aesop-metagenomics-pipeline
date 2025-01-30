import csv
from dataclasses import dataclass, field

#########################################################################################[
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


def count_contig_reads(mapping_file):
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
      contig_to_reads[contig_name].add_read_by_accession(read_mapped_name)
  return contig_to_reads


def get_best_result(input_file, min_identity=95, max_evalue=0.00001, min_length=200):
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
        if not (identity < min_identity or evalue > max_evalue or length < min_length):
          contig_to_blast_result[contig_id] = row
        # else:          
          # print(f"Query didn't meet the filter criteria: {row}")
  return contig_to_blast_result


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