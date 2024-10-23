import os, sys, csv, gzip
import kraken_report_parser as KrakenParser
import get_fastq_read_info as FastqReads


def list_files(directory_path, extension):
  # Get all entries in the directory
  entries = os.listdir(directory_path)    
  # Filter out and list only the .fastq files
  fastq_files = [entry for entry in entries if entry.endswith(extension)]    
  return fastq_files


def list_folders(directory_path):
  # Get all entries in the directory
  entries = os.listdir(directory_path)  
  # Filter out and list only the directories
  folders = [entry for entry in entries if os.path.isdir(os.path.join(directory_path, entry))]  
  return folders


def write_fastq_summary(fastq_files, folder_path, output_file):
  # write header
  with open(output_file, "w") as file:
    file.write("file,sequence_id,read_count,read_mean_length,read_abundance\n")

  # For FASTQ files
  for fastq_file in fastq_files:
    file_path = os.path.join(folder_path, fastq_file)
    print(f"Loading reads from file: {file_path}")
    
    output_content = ""  
    reads = FastqReads.count_reads_by_sequence_id(file_path)
    for sequence_id in reads:        
      read = reads[sequence_id]
      output_content += f"{fastq_file},{sequence_id},{read.count},"
      output_content += f"{read.mean_length()},{read.abundance:.18f}\n"
    
    # write summary
    with open(output_file, "a") as file:
      file.write(output_content)



def write_kraken_report_summary(report_files, folder_path, output_file):
  # write header
  with open(output_file, "w") as file:
    file.write("file,kraken_unclass,kraken_class,kraken_human\n")

  output_content = ""
  for report_file in report_files:
    file_path = os.path.join(folder_path, report_file)
    print(f"Loading report file: {file_path}")

    _, report_by_taxid = KrakenParser.load_kraken_report_tree(file_path)
    k2_unclass = KrakenParser.get_abundance(report_by_taxid, "0")
    k2_class = KrakenParser.get_abundance(report_by_taxid, "1")
    k2_human = KrakenParser.get_abundance(report_by_taxid, "9606")
    output_content += f"{report_file},{k2_unclass},{k2_class},{k2_human}\n"

  # write summary
  if len(output_content) > 0:
    with open(output_file, "a") as file:
      file.write(output_content)


def get_reads_info_from_fastq_summary(summary_file):
  reads_by_file = {}

  with open(summary_file, "r") as file:
    dict_reader = csv.DictReader(file)

    for row in dict_reader:
      fastq_file = row["file"]
      if fastq_file not in reads_by_file:
        reads_by_file[fastq_file] = FastqReads.ReadInfo()

      file_reads = reads_by_file[fastq_file]
      read_count = int(row["read_count"])
      file_reads.count += read_count
      file_reads.lengths += float(row["read_mean_length"]) * read_count

  return reads_by_file


def write_complete_summary(input_path, summary_name):
  # summary_files = list_files(input_path, ".csv")
  header = "filename"
  output_content = {}
  fastq_folders = ["0-raw_samples", "1-bowtie_phix_output", \
                   "1-bowtie_ercc_output", "1-fastp_output", \
                   "2-hisat_human_output", "2-bowtie_human_output"]
  for folder in fastq_folders:
    summary_file = summary_name + "_" + folder + ".csv"
    summary_file = os.path.join(input_path, summary_file)
    if not os.path.isfile(summary_file):
      continue

    foldername = folder.split("-")[1].rsplit("_", 1)[0]
    if folder == "0-raw_samples" or folder == "1-fastp_output":
      header += f",{foldername}_read_count_1,{foldername}_read_count_2"
      header += f",{foldername}_mean_length_1,{foldername}_mean_length_2"
    else:
      header += f",{foldername}_read_count"
      
    reads = get_reads_info_from_fastq_summary(summary_file)
    
    for file in reads:
      if not file.endswith("1.fastq"):
        continue

      file2 = file.replace("_1.", "_2.").replace("_R1.", "_R2.")
      filename = file.rsplit("_", 1)[0]

      if filename not in output_content:
        output_content[filename] = f"{filename}"
      if folder == "0-raw_samples" or folder == "1-fastp_output":
        output_content[filename] += f",{reads[file].count},{reads[file2].count}"
        output_content[filename] += f",{reads[file].mean_length()}"
        output_content[filename] += f",{reads[file2].mean_length()}"
      else:
        output_content[filename] += f",{reads[file].count}"
    
  files = sorted(output_content.keys())
  output_file = "complete_" + summary_name + ".csv"
  output_path = os.path.join(input_path, output_file)
  with open(output_path, "w") as file:
    file.write(header + "\n")
    for filename in files:
      file.write(output_content[filename] + "\n")


def main():
  # input_path = "/home/work/aesop/github/aesop_metagenomics_read_length/results/pipeline_mock"
  input_path = "/home/work/aesop/results_pipeline_v8/dataset_mock01"
  summary_name = "summary_genomic_features"

  for folder in list_folders(input_path):
    continue
    folder_path = os.path.join(input_path, folder)
    
    fastq_files = list_files(folder_path, ".fastq")
    report_files = list_files(folder_path, ".kreport")

    # define summary output filename
    summary_file = summary_name + "_" + folder + ".csv"
    output_file = os.path.join(input_path, summary_file)

    if len(fastq_files) > 0:
      write_fastq_summary(fastq_files, folder_path, output_file)
    elif len(report_files) > 0:
      write_kraken_report_summary(report_files, folder_path, output_file)
  
  
  # define complete summary output filename
  write_complete_summary(input_path, summary_name)


if __name__ == '__main__':
    main()