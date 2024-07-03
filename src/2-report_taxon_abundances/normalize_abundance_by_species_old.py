import os, sys, csv, gzip
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
    line_counter = 0
    with gzip.open(input_file, 'rt') as fastq_file:
        for line in fastq_file:
            line = line.strip()
            if len(line) > 0:
                line_counter += 1
    return int(line_counter/4)


def count_abundance_by_species(report_by_taxid, total_reads, output_file):
    print(f"Count abundance by species, output file: {output_file}")
    output_content = "parent_tax_id,tax_level,category,tax_id,name,kraken_classified_reads,nt_rpm\n"

    for taxid, node in report_by_taxid.items():
        if node.level == 'S' or node.level_enum == KrakenParser.Level.G:
            parent_id = node.parent.taxid
            parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
            level = KrakenParser.Level.S - node.level_enum + 1
            name = node.name.replace(",",";")
            abundance = node.acumulated_abundance
            nt_rpm = int((abundance/total_reads)*1000000)
            output_content += f"{parent_id},{level},{parent_domain},{taxid},{name},{abundance},{nt_rpm}\n"

    with open(output_file, 'w') as file:
        file.write(output_content)


def main():
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    input_kraken_folder = "3-kraken_results" if len(sys.argv) < 4 else sys.argv[3]
    input_kraken_path = f"{input_path}/{input_kraken_folder}"
    input_extension = '_L001_R1_001.fastq.gz'
    input_raw_file =  f"{input_path}/0-raw_samples"

    all_files = get_files_in_folder(input_raw_file, input_extension)
    print(all_files)

    if not os.path.exists(output_path):
        os.makedirs(output_path)

    for file in all_files:
        print(f"Analyzing file: {file}")
        total_reads = get_read_abundance(file) * 2
        print(f"Total reads on raw fastq: {total_reads}")
            
        filename = os.path.basename(file).split(input_extension)[0]
        report_file = os.path.join(input_kraken_path, filename + ".kreport")
            
        _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
        unclass_count = report_by_taxid['0'].acumulated_abundance
        class_count = report_by_taxid['1'].acumulated_abundance
        #total_reads = class_count
        
        print(f"Total reads on report tree: {unclass_count + class_count} | U = {unclass_count} | C = {class_count}")

        abundance_by_species_file = os.path.join(output_path, filename + "_" + input_kraken_folder + "_species_abundance.csv")
        count_abundance_by_species(report_by_taxid, total_reads, abundance_by_species_file)


if __name__ == '__main__':
    main()