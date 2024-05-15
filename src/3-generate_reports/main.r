library(readr)
library(ggplot2)
library(dplyr)
library(tibble)
library(tidyr)
library(pheatmap)
library(reshape2)
library(stringr)
library(grid)

################################################################################

df_pathogens <- read_csv("data/czid_rpip_vsp_pathogens.csv")

source("src/3-generate_reports/data_wrangling_aesop_no_z_score.r")
source("src/3-generate_reports/data_wrangling_aesop.r")

source("src/3-generate_reports/heatmap_parameters_to_fit_page.r")
source("src/3-generate_reports/heatmap_plot.r")

datasets <- c("rs01", "rs02")
# datasets <-  c("mao01", "ssa01", "rio01", "aju02", "rio02", "wgs_ssa01")

category_types <- c("bacteria", "viruses", "eukaryota")
# category_types <- c("viruses")
all_categories <- category_types

################################################################################
for (dataset_name in datasets) {
  # dataset_name <- datasets[6]


  output_folder <- paste0("results/dataset_", dataset_name, "/")
  # output_folder <- paste0("results/results_filtered_with_z_score/")

  dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

  category_types <- all_categories
  source("src/3-generate_reports/main_pathogens_no_z_score.r")
  for (category in all_categories) {
    category_types <- c(category)
    source("src/3-generate_reports/main_pathogens_no_z_score.r")
  }

  # source("src/3-generate_reports/main_plots_pathogens.r")

  # source("src/3-generate_reports/main_barplot.r")

}
################################################################################
