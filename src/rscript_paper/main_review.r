
################################## LOAD DATA ###################################
output_file <- paste0(results_folder, "FigureS6.jpg")
# Load review's sample list
samples_name_file <- "data/review/sra_to_sample_name.csv"

# Define file paths
bracken_path <- "data/review/reports/"
bracken_extension <- "_3-taxonomic_output_bracken_species_abundance.csv"

virus_fullnames_file <- "data/review/virus_fullnames.csv"
expected_viruses_file <- "data/review/original_results_viruses.csv"
expected_bacteria_file <- "data/review/original_results_bacteria.csv"

# List of bracken files
bracken_files <- list.files(bracken_path, pattern = "\\.csv$")

# Load data wrangling functions
source("src/rscript_paper/review/data_wrangling_sample.r")
source("src/rscript_paper/review/data_wrangling_load_all.r")

# Loading all samples
review_df <- data_wrangling_load_all_review_samples(
  samples_name_file, bracken_path, bracken_files, bracken_extension,
  virus_fullnames_file, expected_viruses_file, expected_bacteria_file)

################################ PLOT HEATMAPS #################################

# Filter review viruses
existing_taxa <- review_df %>%
  filter(true_reads > 0) %>%
  filter(category %in% c("viruses")) # %>%
  # filter(!(name %in% c("Papillomaviridae", "Picobirnaviridae")))

output_file <- output_viruses
source("src/rscript_paper/review/heatmap_review_comparison.r")


# Filter review bacteria
existing_taxa <- review_df %>%
  filter(true_reads > 0) %>%
  filter(!(category %in% c("viruses")))

output_file <- output_bacteria
source("src/rscript_paper/review/heatmap_review_comparison.r")

################################################################################
