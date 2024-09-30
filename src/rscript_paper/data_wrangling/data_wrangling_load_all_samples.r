# Load necessary libraries
require(readr)   # For read_csv and write_csv
require(dplyr)   # For data manipulation functions like mutate, bind_rows
require(stringr) # For string manipulation functions
require(purrr)   # For working with lists and applying functions
require(magrittr) # For the pipe operator %>%

data_wrangling_load_all_samples <- function(
  composition_path,
  metadata_path,
  bracken_path,
  bracken_files,
  bracken_extension) {

  # Load all samples
  all_data <- list()
  all_groups <- list()
  for (filename in bracken_files) {
    # filename <- bracken_files[[1]]
    samplename <- str_replace(filename, bracken_extension, "")
    groupname <- str_replace(samplename, "_[^_]*$", "")

    metadata_file <- paste0(metadata_path, groupname, ".csv")
    composition_file <- paste0(composition_path, groupname, ".tsv")
    bracken_file <- paste0(bracken_path, samplename, bracken_extension)

    sample_summary_df <- data_wrangling_load_sample(
        metadata_file, composition_file, bracken_file)

    sample_summary_df$sample_name <- samplename
    all_data[[samplename]] <- sample_summary_df
    all_groups[[samplename]] <- groupname
  }
  # Combine all samples in one dataframe
  combined_df <- bind_rows(all_data)

  # 1. Identify all unique taxa
  all_taxa <- unique(combined_df$tax_id)

  # 2. Identify all unique samples
  all_samples <- unique(combined_df$sample_name)

  # 2.1 Get all metadata information from the taxa
  unique_tax_info_df <- combined_df %>%
    distinct(tax_id, .keep_all = TRUE) %>%
    select(tax_id, tax_name, category)

  # 3. Create a complete dataframe with all combinations of samples and taxa
  complete_df <- expand.grid(sample_name = all_samples, tax_id = all_taxa) %>%
    left_join(unique_tax_info_df, by = c("tax_id")) %>%
    rename(taxname = tax_name, taxcategory = category)

  # 4. Merge the complete dataframe with the original data
  final_df <- complete_df %>%
    left_join(combined_df, by = c("sample_name", "tax_id")) %>%
    mutate(
      group_name = as.character(all_groups[sample_name]),
      true_reads = ifelse(is.na(true_reads), 0, true_reads),
      predicted_reads = ifelse(is.na(predicted_reads), 0, predicted_reads),
      tax_name = ifelse(is.na(tax_name), taxname, tax_name),
      category = ifelse(is.na(category), taxcategory, category)
    ) %>%
    select(-taxname, -taxcategory) %>%
    mutate(
      group_name = case_when(
        group_name == "throat_with_pathogen_01" ~ "TWP01",
        group_name == "throat_with_pathogen_02" ~ "TWP02",
        group_name == "throat_with_pathogen_03" ~ "TWP03",
        group_name == "throat_with_pathogen_04" ~ "TWP04",
        TRUE ~ group_name
      ),
      tax_name = case_when(
        tax_name == "Severe acute respiratory syndrome-related coronavirus" ~
          "SARS-related coronavirus",
        tax_name == "Middle East respiratory syndrome-related coronavirus" ~
          "MERS-related coronavirus",
        TRUE ~ tax_name
      )
    )

  write_csv(final_df, "results/summary_read_results.csv")
  print("Summary of reads has been saved to 'summary_read_results.csv'")
  return(final_df)
}
