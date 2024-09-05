


################################### BACTERIA ###################################

# Load critical bacteria
sample_data <- combined_df %>%
  filter(category %in% c("bacteria", "archaea")) %>%
  filter(tax_id %in% critical_species_pathogen_df$tax_id) %>%
  filter(true_reads > 0 & predicted_reads > 0)

source("src/3-paper-figures/plots/barplot_samples_side_by_side.r")
crit_bacteria_plot <- p  +
  xlim(0, 4) +
  labs(title = "Bacteria")

################################### VIRUSES ####################################

# Load critical viruses
sample_data <- combined_df %>%
  filter(category %in% c("viruses")) %>%
  filter(tax_id %in% critical_family_pathogen_df$tax_id) %>%
  filter(true_reads > 0 & predicted_reads > 0)

source("src/3-paper-figures/plots/barplot_samples_side_by_side.r")
crit_virus_plot <- p +
  xlim(0, 4) +
  labs(title = "Viruses") +
  theme(legend.position = "none")  # Remove the legend

################################### COMBINE ####################################

# Combine the plots using patchwork
combined_plot <- crit_bacteria_plot + crit_virus_plot +
  plot_layout(widths = c(4, 1))

# Save plot
ggsave(
  filename = output_file,
  plot = combined_plot,
  width = 20,
  height = 8,
  dpi = 300
)

################################################################################