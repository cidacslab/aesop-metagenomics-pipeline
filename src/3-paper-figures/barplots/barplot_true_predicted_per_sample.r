
# name <- sample_names[[4]]
sample_data <- combined_df %>%
  filter(sample_name == name) %>%
  filter(category %in% category_filter)

ordered_taxa <- sample_data %>%
  arrange(desc(true_reads)) %>%
  pull(tax_name)

sample_data_ord <- sample_data %>%
  mutate(tax_name = factor(tax_name, levels = ordered_taxa)) %>%
  arrange(tax_name)

num_taxa <- nrow(sample_data)
taxa_chunks <- split(ordered_taxa, ceiling(seq_along(ordered_taxa) / 50))
num_chunks <- length(taxa_chunks)

for (chunk_idx in seq_along(taxa_chunks)) {
  chunk <- taxa_chunks[[chunk_idx]]
  chunk_data <- sample_data_ord %>% filter(tax_name %in% chunk)

  if (nrow(chunk_data) == 0) next

  chunk_df <- chunk_data %>%
    select(tax_name, tax_id, true_reads, predicted_reads, sample_name)

  chunk_data_melted <- chunk_df %>%
    pivot_longer(cols = c(true_reads, predicted_reads),
    names_to = "Read_Type", values_to = "Reads")

  base_width <- 10
  additional_width_per_taxon <- 0.5
  fig_width <- base_width + additional_width_per_taxon * nrow(chunk_df)

  p <- ggplot(
      chunk_data_melted, aes(x = tax_name, y = Reads, fill = Read_Type)
    ) +
    geom_bar(stat = "identity", position = "dodge") +
    scale_fill_manual(
      values = color_blind_palette,
      # labels = c("Expected Reads", "Classified Reads")  # Custom legend labels
    ) +
    labs(
      x = "Species",
      y = "Number of Reads",
      title = paste0(
        "Comparison of True and Predicted Reads for ", category_name,
        " taxa in sample ", name, "(Part ", chunk_idx, "/", num_chunks, ")"
      ),
      fill = "Read Type"
    ) +
    theme_minimal(base_size = 18) +
    theme(
      panel.grid = element_blank(),  # Remove grid lines
      panel.border = element_blank(),  # Remove the outer rectangle border
      axis.ticks = element_line(),  # Show ticks for the x and y axis
      axis.line = element_line(color = "black"),  # Show axis lines
      panel.background = element_rect(fill = "white", color = NA),
      plot.background = element_rect(fill = "white", color = NA),
      plot.title = element_text(hjust = 0.5, face = "bold", size = 22),
      axis.title = element_text(face = "bold", size = 18),
      axis.text = element_text(color = "black", size = 16),
      axis.text.x = element_text(angle = 60, hjust = 1),
      legend.title = element_text(face = "bold", size = 18),
      legend.text = element_text(size = 16),
      legend.position = c(1, 1),  # Place the legend inside the chart
      legend.justification = c("right", "top"),
      legend.box.background = element_rect(color = "black")
    ) +
    guides(
      fill = guide_legend(
        title = "Read Type",
        title.position = "top",
        title.hjust = 0.5
      )
    )

  ggsave(
    filename = ifelse(
      num_chunks > 1,
      paste0(output_preffix_multi_barplots, chunk_idx, ".png"),
      output_single_barplot
    ),
    plot = p,
    width = fig_width,
    height = 8,
    dpi = 300
  )
}