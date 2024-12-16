
################################# COMMON SETUP #################################

source("src/rscripts_viral/0-setup/load_libraries.r")
source("src/rscripts_viral/0-setup/load_metrics_report_file.r")
source("src/rscripts_viral/0-setup//load_metrics_reports_all.r")

reports_folder_path <- "data/dataset_mock/performance_metrics"

# BLAST
# file_suffix <- "_blast_metrics.csv"
# df_metrics <- load_metrics_reports_all(reports_folder_path, file_suffix)
# results_folder_root <- "results/paper_viral/assembly/"

# KRAKEN
file_suffix <- "_kraken_metrics.csv"
df_metrics <- load_metrics_reports_all(reports_folder_path, file_suffix)
results_folder_root <- "results/paper_viral/kraken/"

results_folder <- results_folder_root

################################## STATISTICS ##################################

# source("src/rscripts_viral/statistic_analysis.r")


################################### FIGURE 1 ###################################

source("src/rscripts_viral/2-plots/main_plot_boxplots.r")


################################### FIGURE 2 ###################################

# source("src/rscripts_viral/2-plots/main_plot_scatterplot.r")


################################### FIGURE 3 ###################################

# source("src/rscripts_viral/2-plots/main_plot_heatmap.r")


################################################################################