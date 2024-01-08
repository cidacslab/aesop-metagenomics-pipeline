import os, sys, csv
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


def get_read_abundance(input_file):
    read_abundance = 0   
    with open(input_file, 'r') as fasta_file:
        for line in fasta_file:
            line = line.strip()
            if line.startswith('>'):
                read_abundance += 1
    return read_abundance


def count_abundance_by_species(report_by_taxid, total_reads, output_file):
    print(f"Count abundance by species, output file: {output_file}")
    output_content = "parent_tax_id,tax_level,category,tax_id,name,kraken_classified_reads,nt_rpm\n"

    for taxid, node in report_by_taxid.items():
        if node.level == 'S' or node.level_enum == KrakenParser.Level.G:
            parent_id = node.parent.taxid
            parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
            level = KrakenParser.Level.S - node.level_enum + 1
            abundance = node.acumulated_abundance
            nt_rpm = int((abundance/total_reads)*1000000)
            output_content += f"{parent_id},{level},{parent_domain},{taxid},{node.name},{abundance},{nt_rpm}\n"

    with open(output_file, 'w') as file:
        file.write(output_content)


def main():
    # dataset = "dataset_aju01"
    # input_extension = '.fasta'
    # input_fasta_path = f"/scratch/pablo.viana/aesop/{dataset}/2-bowtie_output"
    # input_kraken_path = f"/scratch/pablo.viana/aesop/{dataset}/3-kraken_results"
    # output_path = f"/opt/storage/raw/aesop/metagenomica/biome/{dataset}"
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    kraken_final_path = "" if len(sys.argv) < 4 else sys.argv[3]
    
    input_extension = '.fasta'
    input_fasta_path = f"{input_path}/2-bowtie_output"
    input_kraken_path = f"{input_path}/3-kraken_results{kraken_final_path}"

    all_files = get_files_in_folder(input_fasta_path, input_extension)
    print(all_files)

    if not os.path.exists(output_path):
        os.makedirs(output_path)

    for file in all_files:
        print(f"Analyzing file: {file}")
        filename = os.path.basename(file).split(".")[0]

        read_abundance_file = os.path.join(input_fasta_path, filename + input_extension)
        total_reads = get_read_abundance(read_abundance_file)
        print(f"Total reads: {total_reads}")

        input_file_path = os.path.join(input_kraken_path, filename)
        report_file = os.path.join(input_file_path, filename + ".report")
        _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
        report_reads_abundance = report_by_taxid['0'].acumulated_abundance + report_by_taxid['1'].acumulated_abundance
        print(f"Total reads on report tree: {report_reads_abundance}")

        abundance_by_species_file = os.path.join(output_path, filename + "_species_abundance.csv")
        count_abundance_by_species(report_by_taxid, total_reads, abundance_by_species_file)


if __name__ == '__main__':
    main()