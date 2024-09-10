

################################### BACTERIA ###################################

# Load all viruses
sample_data <- combined_df %>%
  filter(category %in% c("bacteria", "archaea")) %>%
  filter(true_reads > 0 | predicted_reads > 0)

# Plot
source("src/3-paper-figures/plots/barplot_samples_side_by_side.r")
bacteria_plot <- p  +
  xlim(0, 32) +
  labs(title = "Bacteria")

ggsave(
  filename = output_bacteria,
  plot = bacteria_plot,
  width = 20,
  height = 25,
  dpi = 300
)

################################### VIRUSES ####################################

# Load all viruses
sample_data <- combined_df %>%
  filter(category %in% c("viruses"))  %>%
  filter(true_reads > 0 | predicted_reads > 0)

# Plot
source("src/3-paper-figures/plots/barplot_samples_side_by_side.r")
virus_plot <- p +
  xlim(0, 4) +
  labs(title = "Viruses")

ggsave(
  filename = output_viruses,
  plot = virus_plot,
  width = 20,
  height = 25,
  dpi = 300
)

################################################################################