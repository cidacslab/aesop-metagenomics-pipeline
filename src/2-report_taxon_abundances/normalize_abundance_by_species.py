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


def count_kraken_abundance_by_species(report_file, total_reads, output_file):
    print(f"Count abundance by species, output file: {output_file}")
    output_content = "parent_tax_id,tax_level,category,tax_id,name,kraken_classified_reads,nt_rpm\n"

    _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
    unclass_count = report_by_taxid['0'].acumulated_abundance
    class_count = report_by_taxid['1'].acumulated_abundance
    print(f"Total reads on report tree: {unclass_count + class_count} | U = {unclass_count} | C = {class_count}")
    
    for taxid, node in report_by_taxid.items():
        if node.level == 'S' or node.level_enum == KrakenParser.Level.G:
            parent_id = node.parent.taxid
            parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
            level = KrakenParser.Level.S - node.level_enum + 1
            name = node.name.replace(",",";")
            abundance = node.acumulated_abundance
            nt_rpm = int((abundance*1000000)/total_reads)
            output_content += f"{parent_id},{level},{parent_domain},{taxid},{name},{abundance},{nt_rpm}\n"

    with open(output_file, 'w') as file:
        file.write(output_content)
        
        
def count_bracken_abundance_by_species(report_file, bracken_file, total_reads, output_file):
    print(f"Count abundance by species, output file: {output_file}")
    output_content = "parent_tax_id,tax_level,category,tax_id,name,kraken_classified_reads,bracken_classified_reads,nt_rpm\n"

    _, report_by_taxid = KrakenParser.load_kraken_report_tree(report_file)
    unclass_count = report_by_taxid['0'].acumulated_abundance
    class_count = report_by_taxid['1'].acumulated_abundance
    print(f"Total reads on report tree: {unclass_count + class_count} | U = {unclass_count} | C = {class_count}")

    with open(bracken_file, 'r') as csvfile:
        csvreader = csv.reader(csvfile, delimiter='\t')
        next(csvreader) # remove header
        for row in csvreader:
            tax_id = row[1].strip()
            node = report_by_taxid[tax_id]
            parent_id = node.parent.taxid
            parent_domain = node.get_parent_by_level(KrakenParser.Level.D)
            level = KrakenParser.Level.S - node.level_enum + 1
            # parent_id = 0
            # parent_domain = 0
            # level = 1
            tax_name = row[0].strip().replace(",",";")
            kraken_abundance = row[3].strip()
            bracken_abundance = int(row[5].strip())
            nt_rpm = int((bracken_abundance*1000000)/total_reads)
            output_content += f"{parent_id},{level},{parent_domain},{tax_id},{tax_name},{kraken_abundance},{bracken_abundance},{nt_rpm}\n"

    with open(output_file, 'w') as file:
        file.write(output_content)


def main():
    
    base_path = sys.argv[1]
    
    folders = {
        "3-kraken_results":"5-kraken_reports", 
        "3-kraken_czid_results":"5-kraken_czid_reports", 
        "4-bracken_results":"6-bracken_reports", 
        "4-bracken_czid_results":"6-bracken_czid_reports"
    }
    if len(sys.argv) > 3:
        input_folder = sys.argv[2]
        output_folder = sys.argv[3]
        folders = { input_folder:output_folder }
    
    input_extension = '_L001_R1_001.fastq.gz'
    input_raw_file =  f"{base_path}/0-raw_samples"
    all_files = get_files_in_folder(input_raw_file, input_extension)
    print(all_files)

    for file in all_files:
        print(f"Analyzing file: {file}")
        total_reads = get_read_abundance(file)
        print(f"Total reads on raw fastq: {total_reads}")
        filename = os.path.basename(file).split(input_extension)[0]
        
        for input_folder in folders:
            if input_folder.startswith("3-kraken"):
                report_file = os.path.join(f"{base_path}/{input_folder}", filename + ".kreport")
                output_path = f"{base_path}/{folders[input_folder]}"
                os.makedirs(output_path, exist_ok=True)
                    
        
                abundance_by_species_file = os.path.join(output_path, filename + "_" + input_folder + "_species_abundance.csv")
                count_kraken_abundance_by_species(report_file, total_reads, abundance_by_species_file)
                
            elif input_folder.startswith("4-bracken"):
                bracken_file = os.path.join(f"{base_path}/{input_folder}", filename + ".bracken")
                output_path = f"{base_path}/{folders[input_folder]}"
                os.makedirs(output_path, exist_ok=True)
                
                report_file = bracken_file.replace(".bracken", ".kreport").replace("4-bracken", "3-kraken")
                abundance_by_species_file = os.path.join(output_path, filename + "_" + input_folder + "_species_abundance.csv")
                count_bracken_abundance_by_species(report_file, bracken_file, total_reads, abundance_by_species_file)


if __name__ == '__main__':
    main()