"""
Author: Pablo Viana
Version: 1.0
Created: 2023/08/21

 Utility class used to load the taxonomic tree from a kraken report file.
"""
from dataclasses import dataclass
from typing import List
from enum import IntEnum
import csv, time

valid_levels = {
  'NO RANK','DOMAIN','SUPERKINGDOM','KINGDOM','PHYLUM',
  'CLASS','ORDER','FAMILY','GENUS','SPECIES'
  }

class Level(IntEnum):
  U = -1 # Unclassifed
  N = 0  # No rank
  R = 1  # Root
  D = 2  # Domain/superkingdom
  K = 3  # Kingdom
  P = 4  # Philum
  C = 5  # Class
  O = 6  # Order
  F = 7  # Family
  G = 8  # Genus
  S = 9  # Species


@dataclass
class TreeNode:
  name: str
  taxid: str
  level: str
  level_enum: Level
  level_name_spaces: int
  abundance: int = 0
  acumulated_abundance: int = 0
  children: List['TreeNode'] = None
  parent: 'TreeNode' = None
  
  def __init__(self, name: str, taxid: str, level: str, abundance = 0, acumulated_abundance = 0):
    self.name = name.strip().replace(",",";")
    self.level = level.strip().upper()
    self.taxid = taxid.strip()
    self.abundance = abundance
    self.acumulated_abundance = acumulated_abundance
    self.children = []
    # count spaces at the begining of name
    count_spaces = 0
    for char in name:
      if char == " ":
        count_spaces += 1
      else:
        break
    self.level_name_spaces = count_spaces    
    if self.level not in valid_levels:
      self.level = "NO RANK"
    elif self.level == "SUPERKINGDOM":
      self.level = "DOMAIN"
    self.level_enum = Level[self.level[0]] if self.level[0] in Level.__members__ else None
    self.level = level.strip()
  
  def __hash__(self):
    return hash(self.taxid)
  
  def __str__(self):
    parent_name = self.parent.name if self.parent else ''
    parent_level = self.parent.level if self.parent else ''
    parent_taxid = self.parent.taxid if self.parent else ''
    return f"{self.taxid},{self.level},{self.level_enum}," + \
      f"{str(self.level_name_spaces)},{self.name}," + \
      f"{parent_taxid},{parent_level},{parent_name}"
  
  def __repr__(self):
    return self.__str__()
  
  def set_parent_node(self, parent_node:'TreeNode'):
    # set children and parent attributes
    parent_node.children.append(self)
    self.parent = parent_node
  
  def set_parent(self, last_node:'TreeNode'):
    # initialize parent node
    node = last_node
    # look for parent       
    while node is not None:
      if (node.level_enum < self.level_enum) or \
        (node.level_name_spaces < self.level_name_spaces):
        # set children and parent attributes
        self.set_parent_node(node)
        return True
      node = node.parent
    return False
  
  def get_parent_by_level(self, level: Level):
    parent_in_level, parent_node = None, self
    while parent_node is not None:
      if parent_node.level_enum == level:
        parent_in_level = parent_node
      # elif parent_in_level is None:
      #   if Level.N < parent_node.level_enum and parent_node.level_enum < level:
      #     parent_in_level = parent_node
      #     break
      parent_node = parent_node.parent
    return parent_in_level
  
  def clear_abundance(self):
    self.abundance = 0
    self.acumulated_abundance = 0

  def add_abundance(self, abundance: int):
    self.abundance += abundance
    self.acumulated_abundance += abundance
    parent_node = self.parent
    while parent_node is not None:
      parent_node.acumulated_abundance += abundance
      parent_node = parent_node.parent
  
  def get_all_nodes(self, all_nodes_dict = None):
    nodes_from = []
    nodes_from.append(self)
    if all_nodes_dict is not None:
      all_nodes_dict[self.taxid] = self
    for child_node in self.children:
      nodes = child_node.get_all_nodes(all_nodes_dict)
      nodes_from.extend(nodes)
    return nodes_from  
  
  def get_all_nodes_from_level(self, level: Level, higher_rank_dict = None):
    nodes_from_level = []
    if self.level_enum == level:
      nodes_from_level.append(self)
    for child_node in self.children:
      nodes = child_node.get_all_nodes_from_level(level, higher_rank_dict)
      nodes_from_level.extend(nodes)
    if higher_rank_dict is not None and self.level_enum < level:
      higher_rank_dict[self] = nodes_from_level
    return nodes_from_level 

def get_self_and_all_parents(node: TreeNode):
  all_parents = set()
  while node is not None:
    all_parents.add(node)
    node = node.parent
  return all_parents

def clear_abundance_from_tree(tree_by_taxid):
  # Loop throught all tree nodes and clear it
  for value in tree_by_taxid.values():
    value.clear_abundance()


def get_abundance(tree_by_taxid, taxid):
  abundance = 0
  if taxid in tree_by_taxid:
    abundance = tree_by_taxid[taxid].acumulated_abundance
  return abundance


def load_tree_from_taxonomy_files(names_file: str, nodes_file: str):
  taxid_names = {}
  with open(names_file, "r") as f:
    reader = csv.reader(f, delimiter='|')
    for row in reader:
      tax_id = row[0].strip()
      name_txt = row[1].strip()
      name_class = row[3].strip()
      if name_class == "scientific name":
        taxid_names[tax_id] = name_txt
  print(f"Length of names by taxid tree: {len(taxid_names)}")  
  tree_by_taxid = {}
  parent_by_taxid = {}
  with open(nodes_file, "r") as file:
    csv_reader = csv.reader(file, delimiter='|')
    for row in csv_reader:
      if len(row) > 3:
        taxid = row[0].strip()
        level = row[2].strip()
        name = taxid_names[taxid]
        new_node = TreeNode(name, taxid, level)
        # check for invalid values
        # if new_node.level_enum is None:
        #   # print(f"Invalid level: '{row}'")
        #   continue
        if taxid in tree_by_taxid:                    
          print(f"Duplicate taxid: new='{row}' existing='{tree_by_taxid[taxid]}")
          continue         
        # set node in dict tree
        tree_by_taxid[taxid] = new_node
        # set parent for taxid
        parent_by_taxid[taxid] = row[1].strip()
      else:
        print(f"Invalid line: {row}")
  for taxid,node in tree_by_taxid.items():
    parent_taxid = parent_by_taxid[taxid]
    if parent_taxid == taxid:
      print(f"Setting parent none for node: {node}")
      continue
    parent_node = tree_by_taxid[parent_taxid]
    node.set_parent_node(parent_node)
  for taxid,node in tree_by_taxid.items():    
    parent_node = node.parent
    while parent_node is not None and node.level_enum is None:
      if parent_node.level_enum is not None:
        node.level_enum = parent_node.level_enum
      parent_node = parent_node.parent
  print(f"Length of taxonomy taxid tree: {len(tree_by_taxid)}")
  return tree_by_taxid["1"], tree_by_taxid


def load_tree_from_kraken_report(kraken_report_file: str):
  tree_by_taxid = {}
  root_node, last_node = None, None
  with open(kraken_report_file, 'r') as file:
    for line in file:
      line = line.strip()
      line_splits = line.split("\t", maxsplit=5)
      if len(line_splits) >= 6:
        name = line_splits[5]
        taxid = line_splits[4]
        level = line_splits[3] 
        abundance = int(line_splits[2]) 
        acumulated_abundance = int(line_splits[1]) 
        new_node = TreeNode(name, taxid, level, abundance, acumulated_abundance)
        # check for invalid values
        if new_node.level_enum is None:
          print(f"Invalid level: {line}")
          continue
        if taxid in tree_by_taxid:                    
          print(f"Duplicate taxid: new='{line}' existing='{tree_by_taxid[taxid]}")
          continue                
        # set parent of current node
        has_parent = new_node.set_parent(last_node)
        if not has_parent:
          root_node = new_node
        # set node in dict tree
        tree_by_taxid[taxid] = new_node
        last_node = new_node
        # print(f"New node: {new_node}")
      else:
        print(f"Invalid line: {line}")
  print(f"Length report taxid tree: {len(tree_by_taxid)}")
  return root_node, tree_by_taxid


def main():
  # Start the timer
  start_time = time.time()
  
  names_file = "/home/pedro/aesop/viruses_pipeline/viruses_accessions/taxdump_20241211/names.dmp"
  nodes_file = "/home/pedro/aesop/viruses_pipeline/viruses_accessions/taxdump_20241211/nodes.dmp"
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



if __name__ == '__main__':
    main()