require(readr)
require(dplyr)

############################### DATA WRANGLING ################################


data_wrangling_aesop_no_z_score <- function(reports_folder_path) {

  ################################ LOAD REPORTS ##################################

  # get a list of all files in the folder
  reports_folder <- list.files(path = reports_folder_path, pattern="*.csv", recursive = TRUE)

  # initialize an empty list to store the data frames
  df_list <- list()

  # iterate over the files and load each one into a data frame
  for (file in reports_folder) {
    #file <- reports_folder[[5]]
    # build the full file path
    file_path <- file.path(reports_folder_path, file)
    file <- basename(file_path)

    # load the file into a data frame
    df <- read_csv(file_path)

    # include sample name and remove unnecessary columns
    df_clean <- df %>%
      mutate(
        sample_name = strsplit(file, split = "_species")[[1]][1],
      ) %>%
      select(
        sample_name,
        category,
        tax_level,
        tax_id,
        name,
        nt_rpm
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
    tax_level == 1
  )

  return(df_patho_taxon)
}
