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


datasets <-  c("mao01", "ssa01", "rio01", "aju02", "rio02")

################################################################################
for (dataset_name in datasets) {
  # dataset_name <- datasets[4]

  category_types <- c("bacteria", "viruses", "eukaryota")

  output_folder <- paste0("results/dataset_", dataset_name, "/")

  dir.create(output_folder, recursive = TRUE, showWarnings = FALSE)

  source("src/3-generate_reports/main_pathogens_no_z_score.r")

  source("src/3-generate_reports/main_plots_pathogens.r")

  # source("src/3-generate_reports/main_barplot_pathogens.r")

}
################################################################################

