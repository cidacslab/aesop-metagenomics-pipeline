import sys


def filter_virus_genomes_efficiently(fasta_file, valid_accessions, output_file, buffer_size=100000):
  """
  Efficiently filters a large FASTA file to exclude genomes from a specific genus.
  
  Parameters:
  - fasta_path: Path to the input FASTA file.
  - valid_accessions: List of valid accessions to include in the output.
  - output_path: Path to the output FASTA file.
  - buffer_size: Number of lines to batch before writing to disk.
  """
  print(f"Valid accessions to write: {len(valid_accessions)}")
  with open(output_file, 'w') as out_file:
    out_file.write("")
  write_count = 0
  
  # Step 2: Process the FASTA file in chunks and batch write
  with open(fasta_file, 'r') as in_file:
    buffer = []  # Buffer to accumulate lines for batch writing
    write_flag = False
    
    for line in in_file:
      if line.startswith('>'):  # Header line
        accession = line.split()[0][1:]  # Extract accession (remove '>')
        write_flag = accession in valid_accessions
        # print(f"{accession}: {write_flag}")
      
      if write_flag:
        buffer.append(line)
      
      # Flush buffer to file when it reaches the buffer size
      if len(buffer) >= buffer_size:  
        with open(output_file, 'a') as out_file:
          out_file.writelines(buffer)
          write_count += 1
        buffer.clear()
      
      # if write_count > 1000:
      #   break
  
  # Write any remaining lines in the buffer
  if len(buffer) > 0:
    with open(output_file, 'a') as out_file:
      out_file.writelines(buffer)
      write_count += 1
  print(f"Count blocks written: {write_count}")



def main():

  # Dataset name
  # dataset_name="$1"
  # Extract the number of proccesses to be run in parallel
  # num_processes="$2"
  # Delete preexisting output directory
  delete_output_dir = sys.argv[3]
  # Tar Log file name
  # tar_log_file="$4"
  # Suffix of the input files
  input_extension = sys.argv[5]
  # Path containing the input files
  input_path = sys.argv[6]
  # Destination folder for the output files
  output_dir = sys.argv[7]


  fasta_file = sys.argv[1]
  accession_file = sys.argv[2]
  output_file = sys.argv[3]
  
  valid_accessions = set()
  with open(accession_file, "r") as file:
    for line in file:
      valid_accessions.add(line.strip())
  
  filter_virus_genomes_efficiently(fasta_file, valid_accessions, output_file, buffer_size=100000)



if __name__ == "__main__":
  main()