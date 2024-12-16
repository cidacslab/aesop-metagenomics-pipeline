

csv_file <- paste0(results_folder, "taxon_abundance.csv")
plot_file <- paste0(results_folder, "read_abundance_percentage_plot.png")

################################ DATA WRANGLING ################################

df_reads_by_sample <- df_metrics %>%
  group_by(
    sample_name,
    read_length
  ) %>%
  summarise(
    sum_reads = sum(total_reads)
  )

df_taxon_reads <- df_metrics %>%
  left_join(
    df_reads_by_sample,
    by = c("sample_name" = "sample_name", "read_length" = "read_length")
  ) %>%
  select(
    species,
    species_sensitivity,
    accession_id,
    sample_name,
    read_length,
    total_reads,
    sum_reads
  ) %>%
  mutate(
    species_sensitivity = species_sensitivity * 100,
    taxon_abundance = round(total_reads / sum_reads, 10) * 100
  )

# Save the dataframe as a CSV file
write.csv(df_taxon_reads, file = csv_file, row.names = TRUE)

# ################################### SCATTERPLOT ###################################

cor(df_taxon_reads$taxon_abundance, df_taxon_reads$species_sensitivity, method = "spearman")

ggplot(
  df_taxon_reads,
  aes(x = taxon_abundance, y = species_sensitivity)
  ) +
  geom_point() +
  coord_cartesian(
    ylim = c(0, 100)
    ) +
  labs(
    x = "Abundance of reads (%)",
    y = "Sensitivity (%)"
    ) +
  theme_bw() +
  theme(
    text = element_text(family = "Arial", size = 22),
    plot.title = element_text(face = "bold", hjust = 0.5),
    axis.title = element_text(face = "bold"),
    axis.line = element_line(colour = "black"),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    panel.border = element_blank(),
    panel.background = element_blank(),
  )


ggsave(plot_file, plot = last_plot(), width = 6, height = 6, dpi = 300)
