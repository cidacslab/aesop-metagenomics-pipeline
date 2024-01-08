require(readr)
require(dplyr)

############################### DATA WRANGLING ################################


data_wrangling_aesop <- function(reports_folder_path) {

  ################################# LOAD BACKGROUND ##############################
  # background folder
  background_file_path <- paste0(reports_folder_path, "/background_mock")

  # get a list of all files in the folder
  background_folder <- list.files(path = background_file_path, pattern="*.csv", recursive = FALSE)

  # initialize an empty list to store the data frames
  df_list <- list()

  # iterate over the files and load each one into a data frame
  for (file in background_folder) {
    # build the full file path
    file_path <- file.path(background_file_path, file)

    # load the file into a data frame
    df <- read_csv(file_path)

    if (nrow(df) > 0) {
      # add the data frame to the list
      df_list[[file]] <- df
    }
  }

  df_background <- bind_rows(df_list)

  df_background_grouped <- df_background %>%
    filter(nt_rpm > 0) %>%
    group_by(tax_id) %>%
    summarise(
      bg_mean_nt = mean(nt_rpm),
      bg_sd_nt = sd(nt_rpm)
    )

  df_background_grouped$bg_sd_nt[!is.finite(df_background_grouped$bg_sd_nt)] <- 0

  ################################ LOAD REPORTS ##################################

  # get a list of all files in the folder
  reports_folder <- list.files(path = reports_folder_path, pattern="*.csv", recursive = FALSE)

  # initialize an empty list to store the data frames
  df_list <- list()

  # iterate over the files and load each one into a data frame
  for (file in reports_folder) {
    #file <- reports_folder[[5]]
    # build the full file path
    file_path <- file.path(reports_folder_path, file)

    # load the file into a data frame
    df <- read_csv(file_path)

    # include sample name and remove unnecessary columns
    df_clean <- df %>%
      left_join(df_background_grouped, by = "tax_id") %>%
      mutate(
        sample_name = strsplit(file, split = "_species")[[1]][1],
        bg_mean_nt = coalesce(bg_mean_nt, 0),
        bg_sd_nt = coalesce(bg_sd_nt, 0)
      ) %>%
      mutate(
        nt_z_score = case_when(
          nt_rpm == 0 ~ -100,
          bg_mean_nt == 0 ~ 100,
          bg_sd_nt == 0 & nt_rpm > bg_mean_nt ~ 100,
          bg_sd_nt == 0 ~ -100,
          (nt_rpm - bg_mean_nt) > (bg_sd_nt * 100) ~ 100,
          (nt_rpm - bg_mean_nt) < (bg_sd_nt * -100) ~ -100,
          TRUE ~ (nt_rpm - bg_mean_nt) / bg_sd_nt
        )
      ) %>%
      select(
        sample_name,
        category,
        tax_level,
        tax_id,
        name,
        nt_rpm,
        nt_z_score
      )

    if (nrow(df_clean) > 0) {
      # add the data frame to the list
      df_list[[file]] <- df_clean
    }
  }

  # bind the data frames together into a single data frame
  df_taxons <- bind_rows(df_list)

  df_patho_taxon <- df_taxons %>%
  inner_join(df_pathogens, by = "tax_id") %>%
  filter(
    (category == "eukaryota" & nt_rpm >= 10) |
    (category == "bacteria" & nt_rpm >= 10) |
    (category == "viruses" & nt_rpm >= 1)
  ) %>%
  filter(
    tax_level == 1,
    nt_z_score > 1
  )

  return(df_patho_taxon)
}
