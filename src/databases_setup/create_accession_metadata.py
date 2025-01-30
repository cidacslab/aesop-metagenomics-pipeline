
from utilities.taxonomy_tree_parser import load_tree_from_taxonomy_files 


def main():
  # Start the timer
  start_time = time.time()
  
  names_file = "./data/database/taxdump_20241211/names.dmp"
  nodes_file = "./data/database/taxdump_20241211/nodes.dmp"
  root_node,taxid_tree = load_tree_from_taxonomy_files(names_file, nodes_file)
  # print(f"{root_node}")
  # print(f"{taxid_tree['131567']}")
  # print(f"{taxid_tree['2']}")
  # print(f"{taxid_tree['10239']}")
  # print(f"{taxid_tree['2157']}")
  # print(f"{taxid_tree['2759']}")
  # print(f"{taxid_tree['9606']}")
  
  # End the timer
  end_time = time.time()  
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Total execution time: {total_time:.3f} seconds\n")
  
  levels = set()
  for taxid,node in taxid_tree.items():
    levels.add(node.level)
  print(str(levels) + "\n")
  return
  
  # restart the timer
  start_time = end_time
  
  output_content = "accession,taxid,name,species_taxid,genera_taxid,family_taxid"
  output_content += ",order_taxid,class_taxid,phylum_taxid,domain_taxid,root_taxid\n"
  taxid_map_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/taxid_map.txt"
  genera_map_file = "/home/pedro/aesop/viruses_pipeline/viruses_genomes/accession_metadata.csv"
  
  count_no_exist = {}
  for level in range(9, 0, -1):
    count_no_exist[level] = 0
  
  with open(taxid_map_file, "r") as file:
    for line in file:
      row = line.split()
      accession = row[0].strip()
      taxid = row[1].strip()
      node = taxid_tree[taxid]
      
      output_content += f"{accession},{taxid},{node.name}"
      for level in range(9, 0, -1):
        level_enum = Level(level)
        level_node = node.get_parent_by_level(level_enum)
        count_no_exist[level] += 1 if level_node is None else 0
        level_taxid = level_node.taxid if level_node is not None else ''
        output_content += f",{level_taxid}"
      output_content += f"\n"
  
  print(f"No exist level: {count_no_exist}")
  # with open(genera_map_file, "w") as file:
  #   file.write(output_content)
    
  # print(f"tax id != species_taxid: {count};  no_species_taxid: {count_no_species};  ")
  # print(f"no_genera_taxid: {count_no_genera};  no_family_taxid: {count_no_family};\n")
  
  # End the timer
  end_time = time.time() 
  # Calculate and display total execution time
  total_time = end_time - start_time
  print(f"Total execution time: {total_time:.2f} seconds")



if __name__ == '__main__':
    main()