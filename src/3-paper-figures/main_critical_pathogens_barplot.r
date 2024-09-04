
# Plot critical bacterias of high priority species
critical_species_pathogen_df <- pathogen_df %>%
  filter(high_priority_species == "1")

sample_data <- combined_df %>%
  filter(category %in% c("bacteria", "archaea")) %>%
  filter(tax_id %in% critical_species_pathogen_df$tax_id) %>%
  filter(true_reads > 0 & predicted_reads > 0)

source("src/3-paper-figures/barplots/barplot_samples_side_by_side.r")
crit_bacteria_plot <- p  +
  # scale_x_continuous(breaks = seq(0, 4, by = 2)) +
  xlim(0, 4) +
  labs(title = "Bacteria")

ggsave(
  filename = "results/critical_bacteria.jpg",
  plot = crit_bacteria_plot,
  width = 12,
  height = 6,
  dpi = 300
)

# Plot critical viruses in high priority families
critical_family_pathogen_df <- pathogen_df %>%
  filter(family_priority == "1")

sample_data <- combined_df %>%
  filter(category %in% c("viruses")) %>%
  filter(tax_id %in% critical_family_pathogen_df$tax_id) %>%
  filter(true_reads > 0 & predicted_reads > 0)

source("src/3-paper-figures/barplots/barplot_samples_side_by_side.r")
crit_virus_plot <- p +
  # scale_x_continuous(breaks = seq(0, 4, by = 2)) +
  xlim(0, 4) +
  labs(
    title = "Viruses"
  )


ggsave(
  filename = "results/critical_viruses.jpg",
  plot = crit_virus_plot,
  width = 6,
  height = 6,
  dpi = 300
)

# Combine the plots using patchwork
combined_plot <- crit_bacteria_plot + crit_virus_plot + plot_layout(widths = c(4, 1))
ggsave(
  filename = "results/Figure1.jpg",
  plot = combined_plot,
  width = 20,
  height = 8,
  dpi = 300
)
