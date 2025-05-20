import sys, os, csv
from datetime import datetime, timezone


def filter_virus_genomes_efficiently(fasta_file, valid_accessions, output_file, buffer_size=100000):
  """
  Efficiently filters a large FASTA file to exclude genomes from a specific accessions.  
  Parameters:
  - fasta_path: Path to the input FASTA file.
  - valid_accessions: List of valid accessions to include in the output.
  - output_path: Path to the output FASTA file.
  - buffer_size: Number of lines to batch before writing to disk.
  """
  print(f"Valid accessions to write: {len(valid_accessions)}")
  with open(output_file, "w") as out_file:
    out_file.write("")
  
  write_count = 0  
  write_flag = False
  buffer = []  # Buffer to accumulate lines for batch writing
  
  # Step 2: Process the FASTA file in chunks and batch write
  with open(fasta_file, "r") as in_file:
    for line in in_file:
      if line.startswith(">"):  # Header line
        accession = line.split()[0][1:]  # Extract accession (remove ">")
        write_flag = accession in valid_accessions
        # print(f"{accession}: {write_flag}")      
      if write_flag:
        buffer.append(line)      
      # Flush buffer to file when it reaches the buffer size
      if len(buffer) >= buffer_size:  
        with open(output_file, "a") as out_file:
          out_file.writelines(buffer)
          write_count += 1
        buffer.clear()
        
  # Write any remaining lines in the buffer
  if len(buffer) > 0:
    with open(output_file, "a") as out_file:
      out_file.writelines(buffer)
      write_count += 1
  print(f"Count blocks written: {write_count}")



def main():
  # count=$1
  input_file=sys.argv[2]
  input_suffix=sys.argv[3]
  input_dir=sys.argv[4]
  output_dir=sys.argv[5]
  # nthreads=$6 
  contigs_dir=sys.argv[7]
  contigs_extension=sys.argv[8]
  print(sys.argv)
  
  input_id = os.path.basename(input_file).replace(input_suffix,"")
  accession_file = os.path.join(input_dir, input_id + input_suffix)
  fasta_file = os.path.join(contigs_dir, input_id + contigs_extension)
  output_file = os.path.join(output_dir, input_id + contigs_extension)
  
  valid_accessions = set()
  with open(accession_file, "r") as file:
    csv_reader = csv.reader(file, delimiter="\t")
    next(csv_reader) # remove header
    for row in csv_reader:
      valid_accessions.add(row[0].strip())
  
  filter_virus_genomes_efficiently(fasta_file, valid_accessions, output_file, buffer_size=100000)



if __name__ == "__main__":
  # Get the current process ID
  pid = os.getpid()
  input_count = sys.argv[1]
  input_file = sys.argv[2]
  input_id = os.path.basename(input_file).split(".", 1)[0]
  timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S+0000")
  
  # # Replace stdout with an unbuffered version
  # sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)
  # Print start message
  print(f"B_PID: {pid} [{timestamp}]: Started task Input: {input_file} Count: {input_count}", flush=True)
  
  # Open the log file in line-buffered mode and assign sys.stdout
  f = open(f"{pid}_{input_id}.log", "w", buffering=1)  # buffering=1 => line buffering
  sys.stdout = f
  
  try:
    # RUN MAIN CODE
    main()
  finally:
    # Restore original stdout and close the log file
    sys.stdout = sys.__stdout__
    f.close()
    
