

sample_data <- combined_df %>%
  filter(category %in% c("bacteria", "archaea")) %>%
  filter(true_reads > 0 | predicted_reads > 0)
  # filter(tax_id %in% pathogen_df$tax_id)

source("src/3-paper-figures/barplots/barplot_samples_side_by_side.r")
bacteria_plot <- p  +
  xlim(0, 32) +
  # scale_x_log10() +
  # scale_x_continuous(trans = "log10") +
  labs(title = "Bacteria")

ggsave(
  filename = "results/FigureS1.jpg",
  plot = bacteria_plot,
  width = 20,
  height = 25,
  dpi = 300
)

# Plot critical viruses in high priority families
sample_data <- combined_df %>%
  filter(category %in% c("viruses"))  %>%
  filter(true_reads > 0 | predicted_reads > 0)#%>%
  # filter(tax_id %in% critical_family_pathogen_df$tax_id)

source("src/3-paper-figures/barplots/barplot_samples_side_by_side.r")
virus_plot <- p +
  xlim(0, 4) +
  labs(title = "Viruses")

ggsave(
  filename = "results/FigureS2.jpg",
  plot = virus_plot,
  width = 20,
  height = 25,
  dpi = 300
)

# Combine the plots using patchwork
# combined_plot <- bacteria_plot / virus_plot
# ggsave(
#   filename = "results/all_taxa.jpg",
#   plot = combined_plot,
#   width = 25,
#   height = 49,
#   dpi = 300
# )
