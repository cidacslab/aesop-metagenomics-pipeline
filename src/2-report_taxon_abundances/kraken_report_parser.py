"""
Author: Pablo Viana
Version: 1.0
Created: 2023/08/21

 Utility class used to load the taxonomic tree from a kraken report file.
"""
from dataclasses import dataclass
from typing import List
from enum import IntEnum

class Level(IntEnum):
    U = -1
    R = 1
    D = 2
    K = 3
    P = 4
    C = 5
    O = 6
    F = 7
    G = 8
    S = 9

@dataclass
class TreeNode:
    name: str
    taxid: str
    level: str
    level_enum: Level
    level_count: int
    abundance: int = 0
    acumulated_abundance: int = 0
    children: List['TreeNode'] = None
    parent: 'TreeNode' = None

    def __init__(self, name: str, taxid: str, level: str, abundance = 0, acumulated_abundance = 0):
        self.name = name.strip().replace(",",";")
        self.taxid = taxid.strip()
        self.level = level.strip()
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
        self.level_count = count_spaces
        self.level_enum = Level[level[0]] if level[0] in Level.__members__ else None
    
    def __hash__(self):
      return hash(self.taxid)
    
    def __str__(self):
        parent_name = self.parent.name if self.parent else ''
        parent_level = self.parent.level if self.parent else ''
        parent_taxid = self.parent.taxid if self.parent else ''
        return f"{self.taxid},{self.level},{self.level_enum},{str(self.level_count)}," + \
            f"{self.name},{parent_taxid},{parent_level},{parent_name}"

    def set_parent(self, last_node:'TreeNode'):
        # initialize parent node
        parent_node = last_node
        # look for parent       
        while parent_node is not None:
            if parent_node.level_count < self.level_count:
                # set children and parent attributes
                parent_node.children.append(self)
                self.parent = parent_node
                return True
            parent_node = parent_node.parent
        return False
    
    def get_parent_by_level(self, level: Level):
        parent_in_level = 'none'
        parent_node = self.parent
        while parent_node is not None:
            if parent_node.level_enum == level:
                parent_in_level = parent_node.name.lower()
            parent_node = parent_node.parent
        return parent_in_level

    def clear_abundance(self):
        self.abundance = 0
        self.acumulated_abundance = 0

    def set_abundance(self, abundance: int):
        self.abundance = abundance
        self.acumulated_abundance += abundance
        parent_node = self.parent
        while parent_node is not None:
            parent_node.acumulated_abundance += abundance
            parent_node = parent_node.parent

    def get_all_nodes(self, all_nodes_dict = None):
        nodes_from = []
        nodes_from.append(self)
        for child_node in self.children:
            nodes = child_node.get_all_nodes(all_nodes_dict)
            nodes_from.extend(nodes)
        if all_nodes_dict is not None:
            all_nodes_dict[self] = nodes_from
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


def clear_abundance_from_tree(dict_tree):
    # Loop throught all tree nodes and clear it
    for value in dict_tree.values():
        value.clear_abundance()


def load_kraken_report_tree(report_file: str):
    tree_by_taxid = {}
    root_node, last_node = None, None

    with open(report_file, 'r') as file:
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


def load_taxid_lineage_tree(report_file: str):
    tree_by_name = {}
    taxid_to_species_name = {}
    root_node = TreeNode("root", "1", "R")
    tree_by_name[root_node.name] = root_node

    levels = ["U", "R", "D", "P", "C", "O", "F", "G", "S"]
    with open(report_file, 'r') as file:
        next(file) #ignore header
        #,1081904,Bacteria,Bacteroidota,Bacteroidia,Bacteroidales,Prevotellaceae,Hoylesella,Hoylesella pleuritidis,2,976,200643,171549,171552,2974257,407975
        for line in file:
            last_node = root_node 
            taxid = root_node.taxid
            row = line.strip().split(",")
            for index in range(2, 9):
                name = row[index]
                level = levels[index]
                taxid = row[index+7]
                new_node = TreeNode(name, taxid, level)

                # check for invalid values
                if new_node.level_enum is None:
                    print(f"Invalid level: {line}")
                    continue
                if name in tree_by_name:
                    last_node = tree_by_name[name]
                    #print(f"Duplicate name: new='{line}' existing='{tree_by_name[name]}")
                    continue        

                # set parent of current node
                new_node.parent = last_node
                last_node.children.append(new_node)
                    
                # set node in dict tree
                tree_by_name[name] = new_node
                last_node = new_node
                # print(f"New node: {new_node}")
            taxid_to_species_name[row[1]] = row[8]
    print(f"Length report name tree: {len(tree_by_name)}")
    return root_node, taxid_to_species_name, tree_by_name
