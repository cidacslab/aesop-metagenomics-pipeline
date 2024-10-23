import os, sys, csv, gzip
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
  
  base_path = sys.argv[1]
  input_extension = '_L001_R1_001.fastq.gz'
  input_path =  f"{base_path}/0-raw_samples"

  # folders = {
  #   # "3-kraken_results":"5-kraken_reports", 
  #   "4-bracken_results":"5-bracken_reports"
  # }

  if len(sys.argv) > 3:        
      input_extension = sys.argv[2]
      input_path = f"{sys.argv[3]}"
  
  if len(sys.argv) > 5:
    folders = {}
    for i, o in zip(range(4, len(sys.argv), 2), range(5, len(sys.argv), 2)):
      input_folder = sys.argv[i]
      output_folder = sys.argv[o]
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
    
    
    for input_folder in folders:
      bracken_file = os.path.join(f"{base_path}/{input_folder}", filename + ".bracken")
      output_path = f"{base_path}/{folders[input_folder]}"
      os.makedirs(output_path, exist_ok=True)
      
      report_file = bracken_file.replace(".bracken", ".kreport")#.replace("4-bracken", "3-kraken")
      abundance_by_species_file = os.path.join(output_path, filename + "_" + input_folder + "_bracken_species_abundance.csv")
      count_bracken_abundance_by_species(report_file, bracken_file, total_reads, abundance_by_species_file)


if __name__ == '__main__':
    main()