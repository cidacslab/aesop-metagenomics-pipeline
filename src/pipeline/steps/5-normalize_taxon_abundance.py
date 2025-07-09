import os, sys, csv, gzip, shutil
from datetime import datetime, timezone
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")
sys.path.append("/home/pablo.viana/jobs/github/aesop-metagenomics-pipeline/src")
sys.path.append("/mnt/c/Users/pablo/Documents/github/aesop-metagenomics-pipeline/src")

import utilities.taxonomy_tree_parser as TaxonomyParser
from utilities.utility_functions import get_files_in_folder
from utilities.fastq_read_info import get_total_abundance


def count_kraken_abundance_by_species(report_file, total_reads, output_file):
  print(f"Count abundance by species, output file: {output_file}")
  output_content = "parent_tax_id,tax_level,category,tax_id,name,"
  output_content += "kraken_classified_reads,nt_rpm\n"
  
  _, report_by_taxid = TaxonomyParser.load_kraken_report_tree(report_file)
  u_count = TaxonomyParser.get_abundance(report_by_taxid, "0")
  c_count = TaxonomyParser.get_abundance(report_by_taxid, "1")
  print(f"Total reads on report tree: {u_count+c_count} | U = {u_count} | C = {c_count}")
  
  for taxid, node in report_by_taxid.items():
    if node.level_enum == TaxonomyParser.Level.S or node.level_enum == TaxonomyParser.Level.G:
      parent_id = node.parent.taxid
      parent_domain = node.get_parent_by_level(TaxonomyParser.Level.D)
      level = TaxonomyParser.Level.S - node.level_enum + 1
      name = node.name.replace(",",";")
      abundance = node.acumulated_abundance
      nt_rpm = int((abundance*1000000)/total_reads)
      output_content += f"{parent_id},{level},{parent_domain},{taxid},"
      output_content += f"{name},{abundance},{nt_rpm}\n"
  
  with open(output_file, 'w') as file:
    file.write(output_content)


def count_bracken_abundance_by_species(report_file, bracken_file, total_reads, output_file):
  print(f"Count abundance by species, output file: {output_file}")
  output_content = "parent_tax_id,tax_level,category,tax_id,name,"
  output_content += "kraken_classified_reads,bracken_classified_reads,nt_rpm\n"
  
  _, report_by_taxid = TaxonomyParser.load_kraken_report_tree(report_file)
  u_count = TaxonomyParser.get_abundance(report_by_taxid, "0")
  c_count = TaxonomyParser.get_abundance(report_by_taxid, "1")
  print(f"Total reads on report tree: {u_count+c_count} | U = {u_count} | C = {c_count}")
  
  with open(bracken_file, 'r') as csvfile:
    csvreader = csv.reader(csvfile, delimiter='\t')
    next(csvreader) # remove header
    for row in csvreader:
      tax_id = row[1].strip()
      node = report_by_taxid[tax_id]
      parent_id = node.parent.taxid
      parent_domain = node.get_parent_by_level(TaxonomyParser.Level.D)
      level = TaxonomyParser.Level.S - node.level_enum + 1
      tax_name = row[0].strip().replace(",",";")
      kraken_abundance = row[3].strip()
      bracken_abundance = int(row[5].strip())
      nt_rpm = int((bracken_abundance*1000000)/total_reads)
      output_content += f"{parent_id},{level},{parent_domain},{tax_id},{tax_name},"
      output_content += f"{kraken_abundance},{bracken_abundance},{nt_rpm}\n"
  
  with open(output_file, 'w') as file:
    file.write(output_content)


def main():  
  input_file = sys.argv[2]
  input_extension = sys.argv[3]
  input_path = sys.argv[4]
  output_path = sys.argv[5]
  # nthreads=$6 
  base_path = sys.argv[7]
  args_folders = sys.argv[8]
  print(f"Parameters: {sys.argv}")
  
  folders = {}
  for folders_split in args_folders.split():
    in_out_splits = folders_split.split(":", 1)
    input_folder = in_out_splits[0]
    output_folder = in_out_splits[1]
    folders[input_folder] = output_folder
  
  print(f"Running normalization with input: [{input_path}] [{input_extension}]")
  print(f"    For folders: {folders}")
  file = input_file
  
  print(f"Analyzing input file: {file}")
  total_reads = get_total_abundance(file)
  print(f"Total reads on input fastq: {total_reads}")
  filename = os.path.basename(file).split(input_extension)[0].replace("_metadata", "")
  
  for input_folder,output_folder in folders.items():
    bracken_file = os.path.join(f"{base_path}/{input_folder}", filename + ".bracken")
    output_path = f"{base_path}/{output_folder}"
    os.makedirs(output_path, exist_ok=True)
    
    report_file = bracken_file.replace(".bracken", ".kreport")#.replace("4-bracken", "3-kraken")
    abundance_by_species_file = os.path.join(output_path, filename + "_" + input_folder + "_bracken_species_abundance.csv")
    count_bracken_abundance_by_species(report_file, bracken_file, total_reads, abundance_by_species_file)



if __name__ == '__main__':
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