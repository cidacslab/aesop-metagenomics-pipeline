import csv
from dataclasses import dataclass, field


@dataclass
class ContigInfo:
  reads: set = field(default_factory=set)
  read_accession: dict = field(default_factory=dict)

  def add_read(self, read_seqid: str):
    if read_seqid not in self.reads:
      accession = read_seqid.split('_')[0]
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
  query_to_row = {}
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
      query_id = row['qseqid']
      identity = float(row['pident'])
      evalue = float(row['evalue'])
      length = float(row['length'])
      if query_id not in query_to_row:
        if identity < 95 and evalue > 0.00001 and length < 200:
          print(f"Query didn't meet the filter criteria: {row}")
        else:          
          query_to_row[query_id] = row
  return query_to_row


def results_as_accession_to_taxid(contig_reads, query_to_row):
  accession_taxid = {}
  # Example: Print the dictionary for each query
  for query, row in query_to_row.items():
    if query in contig_reads:
      taxid = row['staxids']    
      contig_info = contig_reads[query]
      for accession, read_count in contig_info.read_accession.items():
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
  query_to_row = get_blast_results(blast_file)
  mapping_file = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3.1-viral_discovery_mapping_metaspades/SI035_1_contig_reads.tsv"
  contig_reads = count_contig_unique_reads(mapping_file)
  accession_taxid = results_as_accession_to_taxid(contig_reads, query_to_row)
  print(f"{accession_taxid}")


if __name__ == '__main__':
    main()