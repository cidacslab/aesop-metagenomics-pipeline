import os, sys, time
sys.path.append("/home/pedro/aesop/github/aesop-metagenomics-pipeline/src")

from utilities.utility_functions import get_files_in_folder
from utilities.taxonomy_tree_parser import load_tree_from_taxonomy_files 



def get_valid_accessions_by_level(metadata_file, excluded_level_index, excluded_level_taxid):
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
  return valid_accessions



def create_valid_taxid_list(taxonomy_tree, metadata_file, taxid_index, excluded_taxid, output_file):
  """
  Filters the tax ids from the metadata file, excluding the ones that have the excluded taxid as parent,
  in any taxonomy level. The output will contain a list of valid tax ids.
  
  Parameters:
  - taxonomy_tree: complete taxonomy tree.
  - metadata_file: Path to the input file containing all tax ids.
  - taxid_index: index of the tax id in the metadata file.
  - excluded_taxid: the tax id of the taxonomy to not be part of the output.
  - output_file: Path to the output file that will contains all valid tax ids.
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
  return valid_accessions



def create_valid_taxid_list(taxonomy_tree, output_file, include_subtree='1', exclude_subtree='0'):
  """
  Creates a list of all tax ids excluding the excluded_taxid and all its subtree.
  The output will contain a list of valid tax ids.
  
  Parameters:
  - taxonomy_tree: complete taxonomy tree.
  - excluded_taxid: the tax id of the taxonomy to not be part of the output.
  - output_file: Path to the output file that will contains all valid tax ids.
  """
  valid_taxids = set()
  for taxid, node in taxonomy_tree.items():
    valid_taxid, exclude_taxid = False, False
    current_node = node
    while current_node is not None:
      valid_taxid = valid_taxid or (current_node.taxid == include_subtree)
      exclude_taxid = exclude_taxid or (current_node.taxid == exclude_subtree)
      current_node = current_node.parent
    if valid_taxid and not exclude_taxid:
      valid_taxids.add(taxid)
  
  sorted_taxids = sorted(valid_taxids)
  with open(output_file, "w") as file:
    file.write("\n".join(sorted_taxids))    
    file.write("\n")
  return valid_taxids



# def main_remove_viral_genomes_from_level():  
#   fasta_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/viral_genomes.fasta"
#   metadata_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/accession_metadata.csv"
#   output_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/viruses_removed_alphainfluenzavirus.fasta"
#   excluded_level_index = 4
#   # excluded_level_taxid = "11118" # Coronaviridae
#   # excluded_level_taxid = "694002" # Betacoronavirus
#   # excluded_level_taxid = "197911" # Alphainfluenzavirus
#   excluded_level_taxid = "12059" # Enterovirus
#   # excluded_level_taxid = "3044782" # Orthoflavivirus
#   buffer_size = 1000000
  
#   # End the timer
#   start_time = time.time()  
#   acc_list = get_valid_accessions_by_level(metadata_file, excluded_level_index, excluded_level_taxid)  
#   filter_virus_genomes_efficiently(fasta_file, acc_list, output_file, buffer_size)
  
#   # End the timer
#   end_time = time.time()  
#   # Calculate and display total execution time
#   total_time = end_time - start_time
#   print(f"Total execution time: {total_time:.3f} seconds\n")



def main_remove_viral_genomes_from_level():  
  input_path = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/4.3-viral_discovery_contigs_metaspades"
  output_path = "/home/pedro/aesop/pipeline/results/viral_discovery_v1/dataset_mock/5.1-viral_discovery_unmatched_contigs"
  input_extension = ".contigs.fa"
  buffer_size = 1000000
  
  # start the timer
  start_time = time.time()  
  
  accession_list = set()
  for file in all_input_files:
    with open(file, "r") as acc_file:
      for line in acc_file:
        accession = line.strip()
        if accession != "" and accession[0] != "#":
          accession_list.add(accession)
    filename = os.path.basename(file).replace(input_extension, "")
    output_file = os.path.join(output_path, filename)
    filter_virus_genomes_efficiently(fasta_file, accession_list, output_file, buffer_size)
  
  # End the timer
  end_time = time.time()  
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Total execution time: {total_time:.3f} seconds\n")


def main_create_valid_taxons_list():  
  # Start the timer
  start_time = time.time()
  
  taxdump_dir = "/home/pedro/aesop/pipeline/databases/taxonomy/taxdump_20250616"
  names_file = os.path.join(taxdump_dir, "names.dmp")
  nodes_file = os.path.join(taxdump_dir, "nodes.dmp")
  root_node,taxid_tree = load_tree_from_taxonomy_files(names_file, nodes_file)

  none_taxid = "0"
  root_taxid = "1"
  cellular_organisms_taxid = "131567"
  bacteria_taxid = "2"
  archaea_taxid = "2157"
  eukaryota_taxid = "2759"
  homo_sapiens_taxid = "9606"
  viruses_taxid = "10239"
  coronaviridae_taxid = "11118"
  betacoronavirus_taxid = "694002"
  sars_cov2_species_taxid = "3418604"
  alphainfluenzavirus_taxid = "197911"
  enterovirus_taxid = "12059"
  orthoflavivirus_taxid = "3044782"
  
  # End the timer
  end_time = time.time()
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Build tree time: {total_time:.3f} seconds\n")
  
  # Restart the timer
  start_time = time.time()
  
  # acc_list = create_valid_taxid_list(taxid_tree, output_file, root_taxid, none_taxid)
  # print(f"Found {len(acc_list)} root_taxid.")
  output_file = os.path.join(taxdump_dir, "viruses.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, viruses_taxid, none_taxid)
  print(f"Found {len(acc_list)} viruses_taxid.")

  output_file = os.path.join(taxdump_dir, "coronaviridae.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, coronaviridae_taxid, none_taxid)
  print(f"Found {len(acc_list)} coronaviridae_taxid.")
  
  output_file = os.path.join(taxdump_dir, "betacoronavirus.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, betacoronavirus_taxid, none_taxid)
  print(f"Found {len(acc_list)} betacoronavirus_taxid.")
  
  output_file = os.path.join(taxdump_dir, "sars_cov2_species.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, sars_cov2_species_taxid, none_taxid)
  print(f"Found {len(acc_list)} sars_cov_taxid.")
  
  output_file = os.path.join(taxdump_dir, "alphainfluenzavirus.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, alphainfluenzavirus_taxid, none_taxid)
  print(f"Found {len(acc_list)} alphainfluenzavirus_taxid.")
  
  output_file = os.path.join(taxdump_dir, "enterovirus.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, enterovirus_taxid, none_taxid)
  print(f"Found {len(acc_list)} enterovirus_taxid.")
  
  output_file = os.path.join(taxdump_dir, "orthoflavivirus.txt")
  acc_list = create_valid_taxid_list(taxid_tree, output_file, orthoflavivirus_taxid, none_taxid)
  print(f"Found {len(acc_list)} orthoflavivirus_taxid.")
  # filter_virus_genomes_efficiently(fasta_file, acc_list, output_file, buffer_size)
  
  # End the timer
  end_time = time.time()  
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Total execution time: {total_time:.3f} seconds\n")



if __name__ == "__main__":
  main_create_valid_taxons_list()
