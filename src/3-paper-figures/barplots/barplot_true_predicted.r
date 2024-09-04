

summary_df <- sample_data %>%
  filter(group_name == groupname) %>%
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
  filter(mean_true_reads > 0 | mean_predicted_reads > 0)

ordered_taxa <- summary_df %>%
  arrange(desc(mean_predicted_reads)) %>%
  arrange(desc(mean_true_reads)) %>%
  pull(tax_name)

sample_data_ord <- summary_df %>%
  mutate(tax_name = factor(tax_name, levels = ordered_taxa)) %>%
  arrange(tax_name)

num_taxa <- nrow(summary_df)
taxa_chunks <- split(ordered_taxa, ceiling(seq_along(ordered_taxa) / 100))
num_chunks <- length(taxa_chunks)

for (chunk_idx in seq_along(taxa_chunks)) {
  chunk_idx <- 1
  chunk <- taxa_chunks[[chunk_idx]]
  chunk_data <- sample_data_ord %>% filter(tax_name %in% chunk)

  if (chunk_idx > 2) {
    break
  }
  if (nrow(chunk_data) == 0) {
    next
  }

  chunk_df <- chunk_data %>%
    select(group_name, tax_name, tax_id, mean_true_reads, mean_predicted_reads,
    std_dev_true_reads, std_dev_predicted_reads)

  chunk_data_melted <- chunk_df %>%
    pivot_longer(
      cols =
        c(mean_true_reads, mean_predicted_reads),
        names_to = "Read_Type",
        values_to = "Reads"
    ) %>%
    pivot_longer(
      cols =
        c(std_dev_true_reads, std_dev_predicted_reads),
        names_to = "Error_Type",
        values_to = "Errors"
    ) %>%
    filter(
      (Read_Type == "mean_true_reads" & Error_Type == "std_dev_true_reads") |
      (Read_Type == "mean_predicted_reads" & Error_Type == "std_dev_predicted_reads")
    )

  # Reverse the levels of the tax_name factor to change the order
  chunk_data_melted <- chunk_data_melted %>%
    mutate(
      tax_name = factor(tax_name, levels = rev(levels(tax_name))),
      label_color = ifelse(tax_id %in% db_tax_ids, "black", "red")
    )

  base_width <- 5
  additional_width_per_taxon <- 0.5
  fig_width <- base_width + (additional_width_per_taxon * nrow(chunk_data_melted))

  # Create the main bar plot without y-axis text
main_plot <- ggplot(chunk_data_melted, aes(x = Reads, y = tax_name, fill = Read_Type)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
  geom_errorbar(
    aes(xmin = Reads - Errors, xmax = Reads + Errors),
    position = position_dodge(width = 0.9), width = 0.6
  ) +
  scale_fill_manual(
    values = c(
      "mean_true_reads" = "skyblue",
      "mean_predicted_reads" = "orange"
    )
  ) +
  labs(
    x = "Species Relative Abundance",
    y = NULL,  # Remove the default y-axis label
    title = paste("Relative Abundance of Species in Samples", groupname),
    fill = "Read Type"
  ) +
  # xlim(0, 0.32) +
  theme_minimal(base_size = 18) +
  theme(
    panel.border = element_blank(),  # Remove the outer rectangle border
    axis.ticks = element_line(),  # Show ticks for the x and y axis
    axis.line = element_line(color = "black"),  # Keep x-axis line
    plot.title = element_text(hjust = 0.5, face = "bold", size = 22),
    plot.margin = margin(20, 10, 20, 20, "pt"),  # Adjust margin for alignment
    axis.title = element_text(face = "bold", size = 18),
    axis.text.x = element_text(hjust = 0.5),
    axis.text.y = element_blank(),  # Remove default y-axis text
    # plot.margin = margin(20, 20, 20, 20, "pt"),  # Adjust margins as needed
    legend.title = element_text(face = "bold", size = 18),
    legend.text = element_text(size = 16),
    legend.position = c(1, 0.01),  # Place the legend inside the chart
    legend.justification = c("right", "bottom"),
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

  # Create the label plot
  label_plot <- ggplot(chunk_data_melted, aes(y = tax_name, x = 1, label = tax_name)) +
    geom_text(aes(color = label_color), hjust = 1, size = 6) +
    scale_color_identity() +  # Use the identity scale for color mapping
    theme_void() +  # Remove all default plotting elements
    theme(
      plot.margin = margin(20, -10, 20, 20, "pt")  # Adjust margin for alignment
    ) +
    xlim(c(0.95, 1))  # Provide some space between the labels and the main plot

  # Combine the plots using patchwork
  combined_plot <- label_plot + main_plot + plot_layout(widths = c(1, 3))

  ggsave(
    filename = ifelse(
      num_chunks > 1,
      paste0(output_preffix_multi_barplots, chunk_idx, ".jpg"),
      output_single_barplot
    ),
    plot = combined_plot,
    width = 15,
    height = 30,
    dpi = 300
  )
}
