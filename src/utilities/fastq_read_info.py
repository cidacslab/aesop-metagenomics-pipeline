import gzip
from Bio import SeqIO
from dataclasses import dataclass


def get_total_abundance(fastq_file):
  # Check if the file is gzipped
  if fastq_file.endswith(".fastq.gz"):
    file_handle = gzip.open
  elif fastq_file.endswith(".fastq"):
    file_handle = open
  else:
    raise ValueError(f"Trying to read invalid fastq file: {fastq_file}")
  # Count reads in the FASTQ file
  line_counter = 0
  with file_handle(fastq_file, "rt") as file:
    for line in file:
      line = line.strip()
      if len(line) > 0:
        line_counter += 1
  return int(line_counter/4)


@dataclass
class ReadInfo:
  count: int = 0
  lengths: int = 0
  abundance: int = 0
  
  def mean_length(self):
    return 0 if self.count == 0 else self.lengths/self.count


def count_reads_by_sequence_id(fastq_file):
  # Check if the file is gzipped
  if fastq_file.endswith(".fastq.gz"):
    file_handle = gzip.open
  elif fastq_file.endswith(".fastq"):
    file_handle = open
  else:
    raise ValueError(f"Trying to read invalid fastq file: {fastq_file}")  
  # Parse the FASTQ file
  reads = {}
  total_read_count = 0  
  with file_handle(fastq_file, "rt") as file:
    for record in SeqIO.parse(file, "fastq"):
      # Increment the count for this sequence ID
      record_id = record.id.rsplit('_', 2)[0]
      if record_id not in reads:
        reads[record_id] = ReadInfo()
      reads[record_id].lengths += len(record.seq)
      reads[record_id].count += 1
      total_read_count += 1
  
  count = 0
  abundance_sum = 0.0
  mean_length_sum = 0.0
  
  # Print the counts
  sorted_reads = sorted(reads.keys())
  for sequence_id in sorted_reads[:-1]:
    read = reads[sequence_id]
    read.abundance = round(read.count / total_read_count, 18)
    # print(f"{sequence_id},{read.count},{read.mean_length()},{read.abundance:.18f}")
    mean_length_sum += read.mean_length()
    abundance_sum += read.abundance
    count += 1
  # print(f"{abundance_sum:.18f},{count}")
  
  # Last read
  last_seq_id = sorted_reads[-1]
  read = reads[last_seq_id]
  read.abundance = round(1 - abundance_sum, 18)
  # print(f"{last_seq_id},{read.count},{read.mean_length()},{read.abundance:.18f}")
  abundance_sum += read.abundance
  mean_length_sum += read.mean_length()
  count += 1
  
  print(f"Contents of file {fastq_file}:")
  print(f"  {count},{total_read_count},{mean_length_sum/count},{abundance_sum:.18f}")
  return reads