
summary_df <- sample_data %>%
  group_by(group_name, tax_name, tax_id) %>%
  summarise(
    n = n(), # Count the number of observations
    mean_true_reads = mean(true_reads),
    std_dev_true_reads = sd(true_reads),
    standard_error_true = std_dev_true_reads / sqrt(n),
    mean_predicted_reads = mean(predicted_reads),
    std_dev_predicted_reads = sd(predicted_reads),
    standard_error_predicted = std_dev_predicted_reads / sqrt(n),
    .groups = "drop"
  ) %>%
  mutate_at(vars(-group_cols()), ~ ifelse(is.na(.), 0, .)) %>%
  filter(mean_true_reads > 0 & mean_predicted_reads > 0)


# 1. Calculate the sum of true reads for each taxon across all samples
taxa_order <- summary_df %>%
  group_by(tax_name) %>%
  summarise(
    total_true_reads = sum(mean_true_reads),
    total_predicted_reads = sum(mean_predicted_reads)
  ) %>%
  arrange(desc(total_predicted_reads)) %>%
  arrange(desc(total_true_reads)) %>%
  pull(tax_name)

# 2. Order the original dataframe by the sum of true reads
sample_data_ord <- summary_df %>%
  mutate(tax_name = factor(tax_name, levels = taxa_order)) %>%
  arrange(tax_name)

num_taxa <- nrow(sample_data_ord)
taxa_chunks <- split(taxa_order, ceiling(seq_along(taxa_order) / 100))
num_chunks <- length(taxa_chunks)

for (chunk_idx in seq_along(taxa_chunks)) {
  # chunk_idx <- 1
  chunk <- taxa_chunks[[chunk_idx]]
  chunk_data <- sample_data_ord %>% filter(tax_name %in% chunk)

  if (nrow(chunk_data) == 0) {
    next
  }

  chunk_df <- chunk_data %>%
    select(tax_name, tax_id, mean_true_reads, mean_predicted_reads, group_name)

  chunk_data_melted <- chunk_df %>%
    pivot_longer(cols = c(mean_true_reads, mean_predicted_reads),
    names_to = "Read_Type", values_to = "Reads") %>%
    arrange(desc(tax_name))

  # Reverse the levels of the tax_name factor to change the order
  chunk_data_melted <- chunk_data_melted %>%
    mutate(tax_name = factor(tax_name, levels = rev(levels(tax_name))))

  base_height <- 10
  additional_height_per_taxon <- 0.5
  fig_height <- base_height + additional_height_per_taxon * nrow(chunk_df)

  # 4. Create the bar plot
  p <- ggplot(chunk_data_melted, aes(x = Reads, y = tax_name, fill = Read_Type)) +
    geom_bar(stat = "identity", position = position_dodge()) +
    facet_wrap(~ group_name, nrow = 1) +  # Use facet_wrap to display samples side by side
    scale_fill_manual(values = c("mean_true_reads" = "skyblue", "mean_predicted_reads" = "orange")) +
    # scale_y_discrete(limits = rev(levels(chunk_data_melted$tax_name))) +
    # scale_y_reverse() +  # Reverse the y-axis
    # xlim(0, 0.04) +
    labs(
      y = "Species",
      x = "Number of Reads",
      title = paste0(
        "Comparison of True and Predicted Reads per sample (Part ", chunk_idx, "/", num_chunks, ")"
      ),
      fill = "Read Type"
    ) +
    theme_minimal(base_size = 18) +
    theme(
      # panel.grid = element_blank(),  # Remove grid lines
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
      legend.position = c(1, 0.1),  # Place the legend inside the chart
      legend.justification = c("right", "bottom"),
      # legend.box.background = element_rect(color = "black"),
      legend.box.background = element_blank(),  # Remove the box around the legend
      legend.background = element_rect(fill = "transparent", color = NA)  # Set legend background to transparent
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
    width = 20,
    height = 25,
    dpi = 300
  )
}
