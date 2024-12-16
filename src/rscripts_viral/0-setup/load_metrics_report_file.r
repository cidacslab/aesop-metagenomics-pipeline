require(readr)
require(dplyr)

load_metrics_report_file <- function(reports_folder_path, file_suffix) {

  # get a list of all files in the folder
  reports_folder <- list.files(
    path = reports_folder_path,
    pattern = file_suffix,
    recursive = TRUE)

  # initialize an empty list to store the data frames
  df_list <- list()

  sample_groups <- list(
    "SI" = "WPWCS",
    "CSI" = "WPWCS",
    "throat_non_pathogen" = "NPWCS",
    "throat_with_pathogen" = "WPWCS",
    "unique_family_non_pathogen" = "NPNCS",
    "unique_family_with_pathogen" = "WPNCS",
    "unique_genus_non_pathogen" = "NPNCS",
    "unique_genus_with_pathogen" = "WPNCS"
    )

  sample_group_class <- list(
    "SI" = "WCS",
    "CSI" = "WCS",
    "throat_non_pathogen" = "WCS",
    "throat_with_pathogen" = "WCS",
    "unique_family_non_pathogen" = "NCS",
    "unique_family_with_pathogen" = "NCS",
    "unique_genus_non_pathogen" = "NCS",
    "unique_genus_with_pathogen" = "NCS"
    )

  # iterate over the files and load each one into a data frame
  for (file in reports_folder) {
    # file <- reports_folder[[1]]
    sample_filename <- strsplit(file, file_suffix)[[1]][1]
    name_split <- strsplit(sample_filename, "_")[[1]]
    split_len <- length(name_split)
    base_filename <- paste0(name_split[1:(split_len - 1)], collapse = "_")
    base_filename2 <- paste0(name_split[1:(split_len - 2)], collapse = "_")
    base_filename2 <- strsplit(base_filename2, "0")[[1]][1]
    # reads_counter <- name_split[split_len]

    # load the file into a data frame
    file_path <- file.path(reports_folder_path, file)
    df <- read_csv(file_path)

    # include sample name and remove unnecessary columns
    df_clean <- df %>%
      mutate(
        sample_name = base_filename,
        sample_category = base_filename2,
        sample_group = sample_groups[[base_filename2]],
        sample_group_class = sample_group_class[[base_filename2]],
        read_length = "150",
        # read_length = reads_counter,
        genus_accuracy = case_when(
          genus_true_positive + genus_true_negative + genus_false_positive + genus_false_negative == 0 ~ -1,
          TRUE ~ (genus_true_positive + genus_true_negative)  /
            (genus_true_positive + genus_true_negative + genus_false_positive + genus_false_negative)
        ),
        species_accuracy = case_when(
          species_true_positive + species_true_negative + species_false_positive + species_false_negative == 0 ~ -1,
          TRUE ~ (species_true_positive + species_true_negative) /
            (species_true_positive + species_true_negative + species_false_positive + species_false_negative)
        ),
        genus_sensitivity = case_when(
          genus_true_positive + genus_false_negative == 0 ~ -1,
          TRUE ~ (genus_true_positive) /
            (genus_true_positive + genus_false_negative)
        ),
        species_sensitivity = case_when(
          species_true_positive + species_false_negative == 0 ~ -1,
          TRUE ~ (species_true_positive) /
            (species_true_positive + species_false_negative)
        ),
        genus_specificity = case_when(
          genus_false_positive + genus_true_negative == 0 ~ -1,
          TRUE ~ (genus_true_negative) /
            (genus_false_positive + genus_true_negative)
        ),
        species_specificity = case_when(
          species_false_positive + species_true_negative == 0 ~ -1,
          TRUE ~ (species_true_negative) /
            (species_false_positive + species_true_negative)
        ),
        genus_precision = case_when(
          genus_true_positive + genus_false_positive == 0 ~ -1,
          TRUE ~ (genus_true_positive) /
            (genus_true_positive + genus_false_positive)
        ),
        species_precision = case_when(
          species_true_positive + species_false_positive == 0 ~ -1,
          TRUE ~ (species_true_positive) /
            (species_true_positive + species_false_positive)
        ),
        species_prevalence = (total_reads) / sum(total_reads),
        # species_fp_perc = (species_false_positive) / total_reads,
        # species_fn_perc = (species_false_negative) / (sum(total_reads) - total_reads)
        species_fp_perc = (species_false_positive) / (species_false_positive + species_true_negative),
        species_fn_perc = (species_false_negative) / (species_true_positive + species_false_negative)
      ) %>%
      filter(
        read_length %in% c("75", "125", "150", "300")
      ) %>%
      mutate(
        read_length = factor(read_length, levels = c("75", "125", "150", "300")),
        genus_f_score = case_when(
          genus_precision + genus_sensitivity == 0 ~ -1,
          TRUE ~ (2 * genus_precision * genus_sensitivity) /
            (genus_precision + genus_sensitivity)
        ),
        species_f_score = case_when(
          species_precision + species_sensitivity == 0 ~ -1,
          TRUE ~ (2 * species_precision * species_sensitivity) /
            (species_precision + species_sensitivity)
        ),
        species_accuracy_by_prevalence = (species_sensitivity * species_prevalence) +
            (species_specificity * (1 - species_prevalence))
    )

    # add the data frame to the list
    df_list[[file]] <- df_clean
  }

  # bind the data frames together into a single data frame
  df_metrics <- bind_rows(df_list)

  return(df_metrics)
}
