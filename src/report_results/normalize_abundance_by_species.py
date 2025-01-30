import os, sys, csv, gzip, shutil
import kraken_report_parser as KrakenParser


def get_files_in_folder(input_path, input_extension):
  print("Start process")
  files_fullpath = []
  gz_extension = input_extension + ".gz"
  for root, dirs, files in os.walk(input_path):
    for file_name in files:
      if file_name.endswith(input_extension) or file_name.endswith(gz_extension):
        file_path = os.path.join(root, file_name)
        files_fullpath.append(file_path)
  return files_fullpath


def get_read_abundance(input_file):
  line_counter = 0
  if input_file.endswith(".gz"):
    with gzip.open(input_file, 'rt') as fastq_file:
      for line in fastq_file:
        line = line.strip()
        if len(line) > 0:
          line_counter += 1
  else:
    with open(input_file, 'rt') as fastq_file:
      for line in fastq_file:
        line = line.strip()
        if len(line) > 0:
          line_counter += 1
  return int(line_counter/4)


def count_kraken_abundance_by_species(report_file, total_reads, output_file):
  print(f"Count abundance by species, output file: {output_file}")
  output_content = "parent_tax_id,tax_level,category,tax_id,name,"
  output_content += "kraken_classified_reads,nt_rpm\n"
  
  _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
  u_count = KrakenParser.get_abundance(report_by_taxid, "0")
  c_count = KrakenParser.get_abundance(report_by_taxid, "1")
  print(f"Total reads on report tree: {u_count+c_count} | U = {u_count} | C = {c_count}")
  
  for taxid, node in report_by_taxid.items():
    if node.level == 'S' or node.level_enum == KrakenParser.Level.G:
      parent_id = node.parent.taxid
      parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
      level = KrakenParser.Level.S - node.level_enum + 1
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
  
  _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
  u_count = KrakenParser.get_abundance(report_by_taxid, "0")
  c_count = KrakenParser.get_abundance(report_by_taxid, "1")
  print(f"Total reads on report tree: {u_count+c_count} | U = {u_count} | C = {c_count}")
  
  with open(bracken_file, 'r') as csvfile:
    csvreader = csv.reader(csvfile, delimiter='\t')
    next(csvreader) # remove header
    for row in csvreader:
      tax_id = row[1].strip()
      node = report_by_taxid[tax_id]
      parent_id = node.parent.taxid
      parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
      level = KrakenParser.Level.S - node.level_enum + 1
      tax_name = row[0].strip().replace(",",";")
      kraken_abundance = row[3].strip()
      bracken_abundance = int(row[5].strip())
      nt_rpm = int((bracken_abundance*1000000)/total_reads)
      output_content += f"{parent_id},{level},{parent_domain},{tax_id},{tax_name},"
      output_content += f"{kraken_abundance},{bracken_abundance},{nt_rpm}\n"
  
  with open(output_file, 'w') as file:
    file.write(output_content)


def main():  
  print(f"Normalization args: {sys.argv}")
  
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
  # Number of parallel threads to be run in each process
  # nthreads="$8"
  # Extra arguments
  base_path = sys.argv[9]
  args_folders = sys.argv[10]
  
  if delete_output_dir == "1":
    try:
      shutil.rmtree(output_dir) # Folder and its content removed
      print(f"Output folder {output_dir} and its content removed.") 
    except:
      print(f"Output folder {output_dir} doesn't exist")
  
  folders = {}
  for folders_split in args_folders.split():
    in_out_splits = folders_split.split(":", 1)
    input_folder = in_out_splits[0]
    output_folder = in_out_splits[1]
    folders[input_folder] = output_folder
  
  print(f"Running normalization with input: [{input_path}] [{input_extension}]")
  print(f"    For folders: {folders}")
  all_files = get_files_in_folder(input_path, input_extension)
  print(all_files)
  
  for file in all_files:
    print(f"Analyzing input file: {file}")
    total_reads = get_read_abundance(file)
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
  # Destination of the log file
  log_file = sys.argv[4]
  # Open the file where you want to redirect the prints
  stdout_file = open(log_file, "w")
  # Redirect sys.stdout to the file
  sys.stdout = stdout_file
  
  main()
  
  # Reset sys.stdout to its default value
  sys.stdout = sys.__stdout__
  # Close the file
  stdout_file.close()