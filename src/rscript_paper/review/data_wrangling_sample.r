# Load necessary libraries
require(readr)   # For read_csv and write_csv
require(dplyr)   # For data manipulation functions like mutate, bind_rows
require(stringr) # For string manipulation functions
require(purrr)   # For working with lists and applying functions
require(magrittr) # For the pipe operator %>%

data_wrangling_load_review_sample <- function(bracken_file) {
  # bracken_file <- paste0("data/review_reports/",
  #   "SRR9637840_3-taxonomic_output_bracken_species_abundance.csv")

  bracken_df <- read_csv(bracken_file, show_col_types = FALSE) %>%
    filter(tax_id != 9606) %>%
    filter(tax_id %in% pathogen_df$tax_id) %>%
    filter(
      (category == "eukaryota" & nt_rpm >= 200) |
      (category == "bacteria" & nt_rpm >= 10) |
      (category == "archaea" & nt_rpm >= 10) |
      (category == "viruses" & nt_rpm >= 1)
    )

  # Create viruses summary dataframe
  viruses_summary_df <- bracken_df %>%
    filter(category %in% c("viruses")) %>%
    rename(predicted_reads = nt_rpm) %>%
    select(name, category, predicted_reads)

  # Create bacteria summary dataframe
  bacteria_summary_df <- bracken_df %>%
    filter(category %in% c("eukaryota", "bacteria", "archaea")) %>%
    rename(predicted_reads = nt_rpm) %>%
    mutate(
      genera = sapply(name, function(x) {
        words <- strsplit(x, " ")[[1]]
        case_when(
          # If the first word is "uncultured", take the second word
          words[1] == "uncultured" ~ words[2],
          # If the first word contains brackets, remove the brackets
          grepl("\\[.*\\]", words[1]) ~ gsub("\\[|\\]", "", words[1]),
          # Default case: use the first word
          TRUE ~ words[1]
        )
      })
    ) %>%
    group_by(genera, category) %>%
    summarize(
      predicted_reads = sum(predicted_reads),
      .groups = "drop"
    ) %>%
    rename(name = genera)

  # Combine viruses_summary_df and bacteria_summary_df
  summary_df <- bind_rows(viruses_summary_df, bacteria_summary_df) #%>%
    # mutate(predicted_reads = log10(predicted_reads)) %>%
    # mutate(
    #   predicted_reads = ifelse(predicted_reads > 100000, 100000, predicted_reads)
    # )
    # filter(predicted_reads > 0)

  # Construct ground truth df with true values
  # total_reads <- sum(summary_df$predicted_reads)

  # summary_df <- summary_df %>%
  #   mutate(predicted_reads = (predicted_reads / total_reads) * 100)

  return(summary_df)
}
