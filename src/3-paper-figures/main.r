
################################# COMMON SETUP #################################

# Load libraries
source("src/3-paper-figures/setup/load_libraries.r")

# Load data wrangling functions
source("src/3-paper-figures/data_wrangling/data_wrangling_load_sample.r")
source("src/3-paper-figures/data_wrangling/data_wrangling_load_all_samples.r")

# Load kraken inspect
kraken_df <- read_tsv(
  "data/k2_pfp_inspect_db.kreport",
  col_names = c("read_percentage", "read_acumulated_abundance",
    "read_abundance", "tax_level", "tax_id", "tax_name"),
  show_col_types = FALSE
  )
db_tax_ids <- unique(kraken_df$tax_id)

# Define file paths
composition_path <- "data/pipeline_mock/composition/"
metadata_path <- "data/pipeline_mock/metadata/"
bracken_path <- "data/pipeline_mock/reports/"
bracken_extension <- "_3-taxonomic_output_bracken_species_abundance.csv"

# List of bracken files
bracken_files <- list.files(bracken_path, pattern = "\\.csv$")

# Loading all samples
combined_df <- data_wrangling_load_all_samples(composition_path,
  metadata_path, bracken_path, bracken_files, bracken_extension)

# Load the list of important human pathogens
pathogen_file_path <- "results/pathogen_prioritization_20240814.csv"
pathogen_df <- read.csv(pathogen_file_path)

# List critical priority species
critical_species_pathogen_df <- pathogen_df %>%
  filter(high_priority_species == "1")

# List critical priority families
critical_family_pathogen_df <- pathogen_df %>%
  filter(family_priority == "1")

# Define output folder
results_folder_root <- "results/paper_figures/"
results_folder <- results_folder_root
dir.create(results_folder, recursive = TRUE)

print("SETUP COMPLETE!")


################################### FIGURE 1 ###################################
# Flowchart pipeline

################################### FIGURE 2 ###################################

output_file <- paste0(results_folder, "Figure2.jpg")
source("src/3-paper-figures/main_critical_pathogens_barplot.r")

################################# FIGURE S1/S2 #################################

output_bacteria <- paste0(results_folder, "FigureS1.jpg")
output_viruses <- paste0(results_folder, "FigureS2.jpg")
source("src/3-paper-figures/main_all_taxa_barplot.r")

################################## FIGURE S3 ###################################

bland_altman_output <- paste0(results_folder, "FigureS3.jpg")
source("src/3-paper-figures/plots/plot_bland_altman.r")

################################## FIGURE S4 ###################################

linear_regression_output <- paste0(results_folder, "FigureS4.jpg")
source("src/3-paper-figures/plots/plot_linear_regression.r")

################################################################################

print("FINISHED!")
