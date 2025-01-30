import os, csv


def get_files_in_folder(input_path, input_extension):
  files_fullpath = []
  for root, _, files in os.walk(input_path):
    for file_name in files:
      if file_name.endswith(input_extension):
        file_path = os.path.join(root, file_name)
        files_fullpath.append(file_path)
  return files_fullpath


def get_accessions(input_file, accession_column_index=0, remove_header=True):
  accession_list = set()
  with open(input_file, "r") as file:
    csv_reader = csv.reader(file)
    if remove_header:
      next(csv_reader)
    for row in csv_reader:
      accession_id = row[accession_column_index].strip()
      # don't add empty accession
      if len(accession_id) > 0:
        accession_list.add(accession_id)
  return accession_list


def get_all_accessions(input_path, input_extension, accession_column_index=0, remove_header=True):
  accession_list = set()
  for file in get_files_in_folder(input_path, input_extension):
    accession_list.update(get_accessions(file, accession_column_index, remove_header))
  return accession_list


def check_composition_abundance(tsv_file):
  count = 0
  abundance_sum = 0.0

  with open(tsv_file, "r") as file:
    csv_reader = csv.reader(file, delimiter="\t")
    for row in csv_reader:
      count += 1
      abundance_sum += round(float(row[1]), 18)

  print(f"Contents of file {tsv_file}:")
  print(f"{count},{abundance_sum:.18f}")


def main():
  # TESTS
  files_path = "results/mocks_sample_based/composition"

  for file in get_files_in_folder(files_path, ".tsv"):
    check_composition_abundance(file)

  files_path = "results/mocks_sample_based/metadata"
  accessions_list = get_all_accessions(files_path, ".csv", 0)
  print(f"{len(accessions_list)}")


if __name__ == '__main__':
  main()