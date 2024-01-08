import os, sys
import kraken_report_parser as KrakenParser


def get_files_in_folder(input_path, input_extension):
    print("Start process")
    files_fullpath = []
    for root, dirs, files in os.walk(input_path):
        for file_name in files:
            if file_name.endswith(input_extension):
                file_path = os.path.join(root, file_name)
                files_fullpath.append(file_path)
    return files_fullpath


def count_abundance_by_species(accession_taxid_counts, accession_abundance, tree_by_taxid, output_file):
    print(f"Count abundance by species, output file: {output_file}")
    output_content = "parent_taxid,level,taxid,name,kraken_classifed_reads,NT_rPM\n"

    KrakenParser.clear_abundance_from_tree(tree_by_taxid)
    for taxid_counts in accession_taxid_counts.values():
        for taxid, counts in taxid_counts.items():
            if taxid not in tree_by_taxid:
                print(f"Invalid taxid: {taxid}")
                continue
            tree_by_taxid[taxid].set_abundance(counts)

    total_reads = float(sum(accession_abundance.values()))
    for taxid, node in tree_by_taxid.items():
        if node.level == 'S' or node.level_enum == KrakenParser.Level.G:
            level = node.level_enum - KrakenParser.Level.G + 1
            abundance = node.acumulated_abundance
            nt_rpm = int((abundance/total_reads)*1000000)
            output_content += f"{node.parent.taxid},{level},{taxid},{node.name},{abundance},{nt_rpm}\n"

    with open(output_file, "w") as file:
        file.write(output_content)


def count_abundance_by_accession_reads(accession_taxid_counts, accession_abundance, accession_metadata, tree_by_taxid, output_file):
    print(f"Count abundance by level, output file: {output_file}")
        
    output_content = "read_accession_id,read_accession_total_count,root,kraken_classified_root"
    output_content += ",superkingdom,kraken_classified_superkingdom,phylum,kraken_classified_phylum"
    output_content += ",class,kraken_classified_class,order,kraken_classified_order,family,kraken_classified_family"
    output_content += ",genus,kraken_classified_genus,species,kraken_classified_species\n"

    for accession_id, taxid_counts in accession_taxid_counts.items():
        KrakenParser.clear_abundance_from_tree(tree_by_taxid)
        for taxid, counts in taxid_counts.items():
            if taxid not in tree_by_taxid:
                print(f"Invalid taxid: {taxid}")
                continue
            tree_by_taxid[taxid].set_abundance(counts)

        accession_lineage = accession_metadata[accession_id]
        output_content += f"{accession_id},{accession_abundance[accession_id]}"
        for taxid, name in accession_lineage:
            abundance = 0
            if taxid in tree_by_taxid:
                abundance = tree_by_taxid[taxid].acumulated_abundance
            output_content += f",{name},{abundance}"
        output_content += "\n"
                      
    with open(output_file, "w") as file:
        file.write(output_content)  



def get_accession_abundance(input_file):
    print(f"Get accession abundance from: {input_file}")
    accession_abundance = {}    
    with open(input_file, 'r') as fasta_file:       
        for line in fasta_file:
            line = line.strip()
            if line.startswith('>'):
                accession_id = None
                splits = line[1:].split('.')
                accession_id = splits[0] + "." + splits[1].split('_')[0]
                
                if accession_id not in accession_abundance:
                    accession_abundance[accession_id] = 0
                accession_abundance[accession_id] += 1

    return accession_abundance


def get_accession_taxid_abundance(input_file, output_file):
    print(f"Get accession taxid abundance from: {input_file}")
    accession_taxid_counts = {}

    with open(input_file, 'r') as classified_file:
        for line in classified_file:
            line = line.strip().split()
            if len(line) >= 2:
                splits = line[0][1:].split('.')
                accession_id = splits[0] + "." + splits[1].split('_')[0]
                taxid = line[1].split("|")[1]
                
                if accession_id not in accession_taxid_counts:
                    accession_taxid_counts[accession_id] = {}
                if taxid not in accession_taxid_counts[accession_id]:
                    accession_taxid_counts[accession_id][taxid] = 0
                accession_taxid_counts[accession_id][taxid] += 1

    output_content = "read_accession_id,taxid,count\n"
    for accession_id, taxid_counts in accession_taxid_counts.items():
        for taxid, count in taxid_counts.items():
            output_content += f"{accession_id},{taxid},{count}\n"

    with open(output_file, 'w') as out_file:
        out_file.write(output_content)

    return accession_taxid_counts


def get_accession_taxid_by_level(input_file):
    print(f"Get accession taxid by level from: {input_file}")
    accession_taxid_by_level = {}

    with open(input_file, 'r') as file:
        header = True
        for line in file:
            if header:
                header = False
                continue

            line_splits = line.strip().split(',')
            accession_id = line_splits[0]
            lineage = line_splits[3:10]
            taxids = line_splits[10:]

            if accession_id in accession_taxid_by_level:
                print(f"Duplicated accession id {accession_id}")
                continue

            lineage_list = []
            lineage_list.append(('1', 'root'))
            lineage_list.extend( [(taxids[i], lineage[i]) for i in range(0, 7)])
            accession_taxid_by_level[accession_id] = lineage_list

    return accession_taxid_by_level


def main():
    #folder_path = sys.argv[1] if len(sys.argv) > 1 else ''
    # input_extension = '.fasta'
    # input_fasta_path = r"/scratch/pablo.viana/aesop/throat_mocks/2-bowtie_output"
    # input_kraken_path = r"/scratch/pablo.viana/aesop/throat_mocks/3-kraken_results"
    # input_metadata_path = r"/opt/storage/raw/aesop/metagenomica/biome/throat_mocks_done"
    # output_path = r"/opt/storage/raw/aesop/metagenomica/biome/throat_mocks/kraken_results"
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    input_extension = '_reads.fasta'
    input_fasta_path = f"{input_path}/2-bowtie_output"
    input_kraken_path = f"{input_path}/3-kraken_results"
    input_metadata_path = f"{input_path}/metadata"
    

    if not os.path.exists(output_path):
        os.makedirs(output_path)
    #if not os.path.isdir(input_path):
    #    print("Invalid input path")
    #    return

    all_files = get_files_in_folder(input_fasta_path, input_extension)
    print(all_files)

    for file in all_files:
        print(f"Analyzing file: {file}")
        filename = os.path.basename(file).split(".")[0]

        accession_abundance_file = os.path.join(input_fasta_path, filename + ".fasta")
        accession_abundance = get_accession_abundance(accession_abundance_file)

        input_path = os.path.join(input_kraken_path, filename)
        report_file = os.path.join(input_path, filename + ".report")
        _, tree_by_taxid = KrakenParser.load_kraken_report_tree(report_file)        

        splits = filename.split("_")
        meta_filename = "_".join(splits[0:-2])
        metadata_file = os.path.join(input_metadata_path, meta_filename + "_metadata.csv")
        accession_metadata = get_accession_taxid_by_level(metadata_file)

        accession_taxid_abundance_file = os.path.join(input_path, filename + ".class")
        output_class_file = os.path.join(output_path, filename + "_out.csv")
        accession_taxid_counts = get_accession_taxid_abundance(accession_taxid_abundance_file, output_class_file)

        abundance_by_level_file = os.path.join(output_path, filename + "_level_abundance.csv")
        count_abundance_by_accession_reads(accession_taxid_counts, accession_abundance, accession_metadata, tree_by_taxid, abundance_by_level_file)

        abundance_by_species_file = os.path.join(output_path, filename + "_species_abundance.csv")
        count_abundance_by_species(accession_taxid_counts, accession_abundance, tree_by_taxid, abundance_by_species_file)

        #output_file = os.path.join(output_path, filename + "_tree_out.csv")
        #write_output_file(read_counts, output_file)


if __name__ == '__main__':
    main()