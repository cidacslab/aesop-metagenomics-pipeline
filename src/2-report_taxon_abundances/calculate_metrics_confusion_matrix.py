import os, sys


def get_files_in_folder(input_path, input_extension):
    files_fullpath = []
    for root, dirs, files in os.walk(input_path):
        for file_name in files:
            if file_name.endswith(input_extension):
                file_path = os.path.join(root, file_name)
                files_fullpath.append(file_path)
    return files_fullpath

def load_accession_taxids(input_file):
    accession_taxids = {}
    with open(input_file, 'r') as file:
        header = True
        for line in file:
            if header:
                header = False
                continue
            
            line_splits = line.strip().split(',')
            accession_id = line_splits[0]
            genus_taxid = line_splits[-2]
            species_taxid = line_splits[-1]
            accession_taxids[accession_id] = (genus_taxid, species_taxid)
    return accession_taxids


def load_reported_tax_abundance(input_file):
    print(f"Load total tax id reads file: {input_file}")
    header = True
    reported_taxid_abundance = {}
    with open(input_file, 'r') as file:
        for line in file:
            if header:
                header = False
                continue
            line_splits = line.strip().split(',')
            #taxid = line_splits[2]
            name = line_splits[3]
            reads = int(line_splits[4])
            reported_taxid_abundance[name] = reads
    return reported_taxid_abundance


def load_accession_lineage_classified(input_file):
    print(f"Load accession level abundance file: {input_file}")
    header = True
    accession_lineage_taxnames = {}
    lineage_taxname_counts = [{} for _ in range(9)]
    lineage_taxname_counts[0] = {"total_reads": 0}
    with open(input_file, 'r') as file:
        for line in file:
            if header:
                header = False
                continue
            line_splits = line.strip().split(',')
            accession_id = line_splits[0]
            accession_total_reads = int(line_splits[1])
            accession_lineage_taxnames[accession_id] = []
            lineage_taxname_counts[0][accession_id] = accession_total_reads
            lineage_taxname_counts[0]["total_reads"] += accession_total_reads
            index = 1
            for i in range(2, 17, 2):
                taxname = line_splits[i]
                mapped_reads = int(line_splits[i+1])
                accession_lineage_taxnames[accession_id].append(taxname)
                if taxname not in lineage_taxname_counts[index]:
                    lineage_taxname_counts[index][taxname] = {"total_reads": 0, "correct_mapped": 0}
                lineage_taxname_counts[index][taxname]["total_reads"] += accession_total_reads
                lineage_taxname_counts[index][taxname]["correct_mapped"] += mapped_reads
                index += 1
    return (accession_lineage_taxnames, lineage_taxname_counts)


def get_confusion_matrix_values(sample_total_reads, total_tax_reads, total_mapped_to_tax, correct_tax_reads):
    # reads from tax_id mapped to correct tax_id
    true_positive = correct_tax_reads
    # reads from tax_id not mapped to this tax_id
    false_negative = total_tax_reads - correct_tax_reads
    # reads not from tax_id mapped to this tax_id
    false_positive = total_mapped_to_tax - correct_tax_reads
    # reads not from tax_id not mapped to this tax_id
    true_negative = sample_total_reads - total_tax_reads - false_positive

    # accuracy = (true_positive + true_negative) / float(true_positive + false_negative + false_positive + true_negative)
    # sensitivity = (true_positive) / float(true_positive + false_negative)
    # specificity = (true_negative) / float(false_positive + true_negative)
    # precision = (true_positive) / float(true_positive + false_positive)
    return (true_positive, true_negative, false_positive, false_negative)


def calculate_confusion_matrix(accession_lineage_taxnames, lineage_taxname_classified, reported_tax_abundance, accession_taxids, output_file):
    print(f"Calculating confusion matrix: {output_file}")
        
    output_content = "accession_id,total_reads,genus,genus_taxid,genus_true_positive,genus_true_negative,"
    output_content += "genus_false_positive,genus_false_negative,species,species_taxid,species_true_positive,"
    output_content += "species_true_negative,species_false_positive,species_false_negative\n"
    
    sample_total_reads = lineage_taxname_classified[0]["total_reads"]

    for accession_id, lineage_taxnames in accession_lineage_taxnames.items():
        accession_total_reads = lineage_taxname_classified[0][accession_id]

        species_name  = lineage_taxnames[-1]
        species_total_reads = lineage_taxname_classified[-1][species_name]["total_reads"]
        species_correct_reads = lineage_taxname_classified[-1][species_name]["correct_mapped"]
        species_total_classified = reported_tax_abundance.get(species_name, 0)
        
        genus_name  = lineage_taxnames[-2]
        genus_total_reads = lineage_taxname_classified[-2][genus_name]["total_reads"]
        genus_correct_reads = lineage_taxname_classified[-2][genus_name]["correct_mapped"]
        genus_total_classified = reported_tax_abundance.get(genus_name, 0)

        genus_metrics = get_confusion_matrix_values(sample_total_reads, genus_total_reads, genus_total_classified, genus_correct_reads)
        species_metrics = get_confusion_matrix_values(sample_total_reads, species_total_reads, species_total_classified, species_correct_reads)
        taxids = accession_taxids[accession_id]

        output_content += f"{accession_id},{accession_total_reads},{genus_name},{taxids[0]},{genus_metrics[0]},"
        output_content += f"{genus_metrics[1]},{genus_metrics[2]},{genus_metrics[3]},{species_name},{taxids[1]},"
        output_content += f"{species_metrics[0]},{species_metrics[1]},{species_metrics[2]},{species_metrics[3]}\n"
        
    with open(output_file, "w") as out_file:
        out_file.write(output_content)


def main():
    # #folder_path = sys.argv[1] if len(sys.argv) > 1 else ''
    # input_extension = '_level_abundance.csv'
    # # input_path = r"results/throat_mocks_reports"
    # input_path = "results/new_mocks/kraken_results"
    # output_path = "results/new_mocks/performance_metrics"
    # metadata_path = "results/new_mocks/metadata_complete"
    # # output_extension = "_75_reads_metrics.csv"
    # output_extension = "_metrics.csv"
    
    input_metadata_path = sys.argv[1]
    input_metrics_path = sys.argv[2]
    output_path = sys.argv[3]
    input_extension = '_level_abundance.csv'
    # output_extension = "_75_reads_metrics.csv"
    output_extension = "_metrics.csv"    

    if not os.path.exists(output_path):
        os.makedirs(output_path)

    print("Starting process...")
    all_files = get_files_in_folder(input_metrics_path, input_extension)
    print(all_files)

    for file in all_files:
        print("")
        print(f"Analyzing file: {file}")

        filename = os.path.basename(file).split(input_extension)[0]
       
        splits = filename.split("_")
        meta_filename = "_".join(splits[0:-2])

        metadata_file = os.path.join(input_metadata_path, meta_filename + "_metadata.csv")
        accession_taxids = load_accession_taxids(metadata_file)

        accession_lineage_classified_file = os.path.join(input_metrics_path, filename + "_level_abundance.csv")
        accession_lineage_taxnames, lineage_taxname_classified = load_accession_lineage_classified(accession_lineage_classified_file)
        
        reported_tax_abundance_file =  os.path.join(input_metrics_path, filename + "_species_abundance.csv")
        reported_tax_abundance = load_reported_tax_abundance(reported_tax_abundance_file)
        
        output_file = os.path.join(output_path, filename + output_extension)
        calculate_confusion_matrix(accession_lineage_taxnames, lineage_taxname_classified, reported_tax_abundance, accession_taxids, output_file)


if __name__ == '__main__':
    main()