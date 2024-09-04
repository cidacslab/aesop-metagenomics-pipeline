# Load necessary libraries
require(readr)   # For read_csv and write_csv
require(dplyr)   # For data manipulation functions like mutate, bind_rows
require(stringr) # For string manipulation functions
require(purrr)   # For working with lists and applying functions
require(magrittr) # For the pipe operator %>%

data_wrangling_load_sample <- function(
  # read_summary_df,
  composition_path,
  metadata_path,
  bracken_path,
  bracken_extension,
  filename) {

  samplename <- str_replace(filename, bracken_extension, "")
  groupname <- str_replace(samplename, "_[^_]*$", "")

  composition_file <- paste0(composition_path, groupname, ".tsv")
  metadata_file <- paste0(metadata_path, groupname, ".csv")
  bracken_output_file <- paste0(bracken_path, samplename, bracken_extension)

  composition_df <- read_tsv(
    composition_file,
    col_names = c("accession_id", "abundance_percentage"),
    show_col_types = FALSE,
    col_types = cols(
      accession_id = col_character(),
      abundance_percentage = col_character()
      )
    )

  bracken_df <- read_csv(bracken_output_file, show_col_types = FALSE) %>%
    filter(tax_id != 9606) %>%
    filter(
      (category == "eukaryota" & nt_rpm >= 200) |
      (category == "bacteria" & nt_rpm >= 10) |
      (category == "archaea" & nt_rpm >= 10) |
      (category == "viruses" & nt_rpm >= 1)
    )

  metadata_df <- read_csv(metadata_file, show_col_types = FALSE)

  composition_metadata_df <- composition_df %>%
    left_join(metadata_df, by = c("accession_id")) %>%
    rename(tax_id = species_taxid) %>%
    mutate(
      true_reads = as.numeric(abundance_percentage)
    ) %>%
    filter(tax_id != 9606)

  total_reads_composition <- sum(composition_metadata_df$true_reads)

  true_reads_summary <- composition_metadata_df %>%
    group_by(tax_id) %>%
    summarize(
      true_reads = sum(true_reads) / total_reads_composition,
      .groups = "drop"
    )

  total_reads_bracken <- sum(bracken_df$bracken_classified_reads)

  predicted_reads_summary <- bracken_df %>%
    rename(predicted_reads = bracken_classified_reads) %>%
    group_by(tax_id) %>%
    summarize(
      predicted_reads = sum(predicted_reads) / total_reads_bracken,
      .groups = "drop"
    )

  summary_df <- true_reads_summary %>%
    full_join(predicted_reads_summary, by = c("tax_id"))

  unique_composition_df <- composition_metadata_df %>%
    distinct(tax_id, .keep_all = TRUE) %>%
    select(-true_reads)

  sample_summary_df <- summary_df %>%
    left_join(unique_composition_df, by = c("tax_id")) %>%
    left_join(bracken_df, by = c("tax_id")) %>%
    mutate(
      sample_name = samplename,
      true_reads = ifelse(is.na(true_reads), 0, true_reads),
      predicted_reads = ifelse(is.na(predicted_reads), 0, predicted_reads),
      tax_name = ifelse(is.na(name), species, name),
      category = ifelse(is.na(category), tolower(superkingdom), category)
    ) %>%
    select(sample_name, tax_id, tax_name, category, true_reads, predicted_reads)

  # any_duplicated_id <- any(duplicated(sample_summary_df$tax_id))
  # print(paste0("In sample [", samplename, "] there is [",
  #   any_duplicated_id, "] duplicate tax_id in summary reads")
  # )

  return(sample_summary_df)
}
