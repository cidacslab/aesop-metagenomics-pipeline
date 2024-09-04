# Load necessary libraries
require(readr)   # For read_csv and write_csv
require(dplyr)   # For data manipulation functions like mutate, bind_rows
require(stringr) # For string manipulation functions
require(purrr)   # For working with lists and applying functions
require(magrittr) # For the pipe operator %>%

data_wrangling_load_all_samples <- function() {

  # Define file paths
  # Assuming summary file contains total reads
  # summary_file <- "data/pipeline_mock/mock_read_count_report.csv"
  # summary_df <- read_csv(summary_file, show_col_types = FALSE)

  composition_path <- "data/pipeline_mock/composition/"

  metadata_path <- "data/pipeline_mock/metadata/"

  bracken_path <- "data/pipeline_mock/reports/"
  bracken_extension <- "_3-taxonomic_output_bracken_species_abundance.csv"

  # List of sample names
  # Add all your sample names here
  # sample_names <- c(
  #   "CSI004", "SI003", "SI007", "SI035", "SI041_1",
  #   "throat_with_pathogen_01", "throat_with_pathogen_02",
  #   "throat_with_pathogen_03", "throat_with_pathogen_04")
  # sample_names <- c("SI041_1", "throat_with_pathogen_01")
  sample_files <- list.files(bracken_path, pattern = "\\.csv$")

  all_data <- list()
  for (file in sample_files) {
    # file <- sample_files[[1]]
    sample_summary_df <- data_wrangling_load_sample(
      composition_path, metadata_path,
      bracken_path, bracken_extension, file)

    all_data[[file]] <- sample_summary_df
  }
  # Combine all samples in one dataframe
  combined_df <- bind_rows(all_data)

  # 1. Identify all unique taxa
  all_taxa <- unique(combined_df$tax_id)

  # 2. Identify all unique samples
  all_samples <- unique(combined_df$sample_name)

  # 2.1 Get all metadata information from the taxa
  unique_tax_df <- combined_df %>%
    distinct(tax_id, .keep_all = TRUE) %>%
    select(-sample_name, -true_reads, -predicted_reads)

  # 3. Create a complete dataframe with all combinations of samples and taxa
  complete_df <- expand.grid(sample_name = all_samples, tax_id = all_taxa) %>%
    left_join(unique_tax_df, by = c("tax_id")) %>%
    rename(taxname = tax_name, taxcategory = category)

  # 4. Merge the complete dataframe with the original data
  final_df <- complete_df %>%
    left_join(combined_df, by = c("sample_name", "tax_id")) %>%
    mutate(
      group_name = str_replace(sample_name, "_[^_]*$", ""),
      true_reads = ifelse(is.na(true_reads), 0, true_reads),
      predicted_reads = ifelse(is.na(predicted_reads), 0, predicted_reads),
      tax_name = ifelse(is.na(tax_name), taxname, tax_name),
      category = ifelse(is.na(category), taxcategory, category)
    ) %>%
    select(-taxname, -taxcategory)

  final_df <- final_df %>%
    mutate(
      true_reads = true_reads * 100,
      predicted_reads = predicted_reads * 100,
      group_name = case_when(
        group_name == "throat_with_pathogen_01" ~ "TWP01",
        group_name == "throat_with_pathogen_02" ~ "TWP02",
        group_name == "throat_with_pathogen_03" ~ "TWP03",
        group_name == "throat_with_pathogen_04" ~ "TWP04",
        TRUE ~ group_name
      ),
      tax_name = case_when(
        tax_name == "Severe acute respiratory syndrome-related coronavirus" ~ "SARS-related coronavirus",
        tax_name == "Middle East respiratory syndrome-related coronavirus" ~ "MERS-related coronavirus",
        TRUE ~ tax_name
      )
    )
  write_csv(final_df, "results/summary_reads_r.csv")
  print("Summary of reads has been saved to 'summary_reads.csv'")
  return(final_df)
}