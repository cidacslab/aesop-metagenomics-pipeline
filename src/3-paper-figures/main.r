
# Load libraries
source("src/3-paper-figures/setup/load_libraries.r")

# Load samples
source("src/3-paper-figures/data_wrangling/data_wrangling_load_sample.r")
source("src/3-paper-figures/data_wrangling/data_wrangling_load_all_samples.r")
combined_df <- data_wrangling_load_all_samples()

kraken_df <- read_tsv(
  "data/k2_pfp_inspect_db.kreport",
  col_names = c(
    "read_percentage", "read_acumulated_abundance",
    "read_abundance", "tax_level", "tax_id", "tax_name"
  ),
  show_col_types = FALSE
)
db_tax_ids <- unique(kraken_df$tax_id)

# Load the list of important human pathogens
pathogen_file_path <- "data/pathogen_prioritization_20240814.csv"
pathogen_df <- read.csv(pathogen_file_path)

print("Ready")

# source("src/3-paper-figures/main_critical_pathogens_barplot.r")
# source("src/3-paper-figures/main_all_taxa_barplot.r")
# source("src/3-paper-figures/main_statistics_plots.r")


# source("src/3-paper-figures/statistics/correlation.r")