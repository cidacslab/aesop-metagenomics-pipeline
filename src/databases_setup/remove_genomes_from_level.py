import time


def filter_virus_genomes_efficiently(
  fasta_file, metadata_file, excluded_level_index,
  excluded_level_taxid, output_file, buffer_size=100000
  ):
  """
  Efficiently filters a large FASTA file to exclude genomes from a specific genus.
  
  Parameters:
  - fasta_path: Path to the input FASTA file.
  - csv_path: Path to the CSV metadata file.
  - excluded_genus_taxid: The genus_taxid to exclude.
  - output_path: Path to the output FASTA file.
  - write_buffer_size: Number of lines to batch before writing to disk.
  """
  # Step 1: Parse the CSV file to get a set of accessions to exclude
  valid_accessions = set()
  with open(metadata_file, 'r') as file:
    next(file) # remove header
    for line in file:
      row = line.strip().split(",")
      accession = row[0].strip()
      level_taxid = row[excluded_level_index].strip()
      #if level_taxid != "" and 
      if level_taxid != excluded_level_taxid:
        valid_accessions.add(accession)
  
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
        buffer.clear()
        write_count += 1
      
      # if write_count > 1000:
      #   break
  
  print(f"Count written: {write_count}")
  # Write any remaining lines in the buffer
  if len(buffer) > 0:
    with open(output_file, 'a') as out_file:
      out_file.writelines(buffer)


def main():
  
  fasta_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/viral_genomes.fasta"
  metadata_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/accession_metadata.csv"
  output_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/viruses_removed_alphainfluenzavirus.fasta"
  excluded_level_index = 4
  # excluded_level_taxid = "11118" # Coronaviridae
  # excluded_level_taxid = "694002" # Betacoronavirus
  # excluded_level_taxid = "197911" # Alphainfluenzavirus
  excluded_level_taxid = "12059" # Enterovirus
  # excluded_level_taxid = "3044782" # Orthoflavivirus
  buffer_size = 1000000
  
  # End the timer
  start_time = time.time()  
  
  filter_virus_genomes_efficiently(
    fasta_file, metadata_file, excluded_level_index,
    excluded_level_taxid, output_file, buffer_size
    )
  
  # End the timer
  end_time = time.time()  
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Total execution time: {total_time:.3f} seconds\n")



if __name__ == "__main__":
  main()
