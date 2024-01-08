

################################################################################

# standard taxon annotation
reports_std_folder <- paste0("data/dataset_", dataset_name, "_std_reports")

df_pathogens_std <- data_wrangling_aesop(reports_std_folder) %>%
  filter(category %in% c("bacteria", "viruses"))


################################################################################

# eukaryota taxon annotation
reports_euk_folder <- paste0("data/dataset_", dataset_name, "_euk_reports")
df_pathogens_euk <- data_wrangling_aesop(reports_euk_folder) %>%
  filter(category %in% c("eukaryota"))


################################################################################

# bind standard and eukaria tables
df_patho_taxons <- bind_rows(df_pathogens_std, df_pathogens_euk) %>%
  filter(category %in% category_type) %>%
  arrange(sample_name)

if (dataset_name == "rio02") {
  df_patho_taxons <- df_patho_taxons %>%
    mutate(
      sample_name = case_when(
        sample_name == "107171_S10" ~ "AP21-1",
        sample_name == "107036_S4" ~ "AP31-1",
        sample_name == "107035_S5" ~ "AP32-2",
        sample_name == "107034_S8" ~ "AP53-1",
        sample_name == "107033_S9" ~ "AP53-2",
        sample_name == "MOCK01_S3" ~ "MOCK01",
        sample_name == "MOCK02_S6" ~ "MOCK02",
        sample_name == "MOCK03_S12" ~ "MOCK03",
        TRUE ~ "none",
      )
    ) %>%
    filter(sample_name != "none") %>%
    arrange(sample_name)
}

################################################################################

# melt table to show samples as columns
df_unmelt <- df_patho_taxons %>%
  mutate(name = organism) %>%
  select(
    sample_name, name, category, nt_rpm
  ) %>%
  pivot_wider(
    names_from = sample_name,
    values_from = nt_rpm
  )

################################################################################

df_ordered <- df_unmelt %>%
  mutate(
    mean_rpm = rowMeans(select(., -one_of(c("category", "name"))), na.rm = TRUE)
  ) %>%
  arrange(-mean_rpm, name) %>%
#   select(-mean_rpm) %>%
  replace(is.na(.), 0)  %>%
  column_to_rownames(var = "name")


################################################################################
##################################  HEATMAP  ###################################
################################################################################

for (category in category_type) {
  #  output name
  output_heatmap <- paste0(
    output_folder,
    "heatmap_", dataset_name,
      "_", category, "_pathogens")

  category_filter <- c(category)
  source("src/aesop/main_heatmap.r")
}


################################################################################
##################################  BARPLOT  ###################################
################################################################################

# # arrange data and plot
# df_means <- df_final %>%
#   mutate(
#     mean_rpm = rowMeans(
#       across(-one_of(c("category", "name")))
#     )
#   ) %>%
#   select(
#     name,
#     category,
#     mean_rpm
#   ) %>%
#   arrange(mean_rpm)

# df_means <- df_means %>%
#   mutate(
#     name = factor(name, levels = df_means$name)
#   )

# sum(df_means["mean_rpm"])


# for (category in category_type) {
#   #  output name
#   output_heatmap <- paste0(
#       output_folder,
#       "barplot_", dataset_name,
#       "_", category, "_pathogens")

#   category_filter <- c(category)
#   source("src/aesop/main_barplot.r")
# }