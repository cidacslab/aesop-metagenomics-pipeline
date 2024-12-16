# Load necessary libraries
require(readr)   # For read_csv and write_csv
require(dplyr)   # For data manipulation functions like mutate, bind_rows
require(stringr) # For string manipulation functions
require(purrr)   # For working with lists and applying functions
require(magrittr) # For the pipe operator %>%

data_wrangling_load_all_review_samples <- function(
  samples_name_file,
  bracken_path,
  bracken_files,
  bracken_extension,
  virus_fullnames_file,
  expected_viruses_file,
  expected_bacteria_file) {

  # Load review's sample name list
  samples_df <- read_csv(samples_name_file, show_col_types = FALSE)

  # Load all samples
  all_data <- list()
  for (filename in bracken_files) {
    # filename <- bracken_files[[1]]
    bracken_file <- paste0(bracken_path, filename)

    sample_summary_df <- data_wrangling_load_review_sample(bracken_file)

    srafile <- str_replace(filename, bracken_extension, "")
    samplename <- samples_df$sample_name[samples_df$sra_name == srafile]
    sample_summary_df$sample_name <- samplename
    all_data[[samplename]] <- sample_summary_df
  }
  # Combine all samples in one dataframe
  predicted_reads_df <- bind_rows(all_data)

  # Load the viral name correlation from its abbreviation
  virus_names_df <- read_csv(virus_fullnames_file, show_col_types = FALSE)

  # Load viral review results
  viruses_df <- read_csv(expected_viruses_file, show_col_types = FALSE)

  # Unmelt the table
  viruses_true_reads_df <- viruses_df %>%
    pivot_longer(
      cols = -sample_name,
      names_to = "name",
      values_to = "true_reads"
    ) %>%
    filter(true_reads > 0) %>%
    left_join(virus_names_df, by = c("name" = "virus")) %>%
    mutate(
      name = ifelse(!is.na(fullname), fullname, name),
      true_reads = 10^(true_reads),
      category = "viruses"
    ) %>%
    select(-fullname)

  # Load bacterial review results
  bacteria_df <- read_csv(expected_bacteria_file, show_col_types = FALSE)

  # Unmelt the table
  bacteria_true_reads_df <- bacteria_df %>%
    pivot_longer(
      cols = -sample_name,
      names_to = "name",
      values_to = "true_reads"
    ) %>%
    filter(true_reads > 0) %>%
    mutate(
      category = ifelse(name == "Candida", "eukaryota", "bacteria"),
      true_reads = 10^(true_reads)
    )

  # Combine the review results in a single dataframe
  true_reads_df <- bind_rows(viruses_true_reads_df, bacteria_true_reads_df)

  # sample_total_reads <- true_reads_df %>%
  #   group_by(sample_name) %>%
  #   summarise(
  #     total_reads = sum(true_reads)
  #   )

  # true_reads_df <- true_reads_df %>%
  #   left_join(sample_total_reads, by = "sample_name") %>%
  #   mutate(true_reads = (true_reads / total_reads) * 100) %>%
  #   select(-total_reads)

  # Combine the predicted values with the expected results
  combined_df <- true_reads_df %>%
    full_join(predicted_reads_df, by = c("name", "sample_name", "category")) %>%
    select(sample_name, category, name, true_reads, predicted_reads)


  # Replace NA values with 0
  combined_df[is.na(combined_df)] <- 0

  return(combined_df)
}
