
bland_altman_output <- "results/FigureS4.jpg"

data_filtered <- combined_df %>%
  filter(true_reads > 0 & predicted_reads > 0) %>%
  mutate(
    # diff_reads = predicted_reads - true_reads
    diff_reads = case_when(
      true_reads == predicted_reads ~ 0,
      predicted_reads > 2 * true_reads ~ 1,
      TRUE ~ (predicted_reads - true_reads) / true_reads
    )
  )

data_means <- data_filtered %>%
  group_by(group_name, tax_id, tax_name, category) %>%
  summarise(
    mean_diff_reads = mean(diff_reads),
    mean_true_reads = mean(true_reads),
    mean_predicted_reads = mean(predicted_reads),
    .groups = "drop"
  )

# mean_diff <- mean(data_means$mean_diff_reads)
# sd_diff <- sd(data_means$mean_diff_reads)
mean_diff <- 0
sd_diff <- 0.08
max_sd_diff <- mean_diff + (1.96 * sd_diff)
min_sd_diff <- mean_diff - (1.96 * sd_diff)

critical_taxa <- combined_df %>%
  filter(
    (
      category %in% c("viruses") &
      tax_id %in% critical_family_pathogen_df$tax_id
    ) |
    (
      category %in% c("bacteria", "archaea") &
      tax_id %in% critical_species_pathogen_df$tax_id
    )
  )

plot_data <- data_means %>%
  mutate(outlier = mean_diff_reads < min_sd_diff | mean_diff_reads > max_sd_diff) %>%
  mutate(critical_outlier = outlier & tax_id %in% critical_taxa$tax_id) %>%
  mutate(outlier = ifelse(critical_outlier, FALSE, outlier)) #%>%
  # filter(tax_id %in% critical_taxa$tax_id)

length(unique(plot_data$tax_id))

outlier_data <- plot_data %>%
  filter(outlier | critical_outlier)

length(unique(outlier_data$tax_id))

critical_outlier_data <- plot_data %>%
  filter(critical_outlier)

length(unique(critical_outlier_data$tax_id))



p <- ggplot(
  data = plot_data,
  aes(x = mean_true_reads, y = mean_diff_reads)
  ) +
  geom_point(alpha = 0.5) +
  geom_hline(
    yintercept = mean_diff,
    color = "red",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = max_sd_diff,
    color = "blue",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = min_sd_diff,
    color = "blue",
    linetype = "dashed"
  ) +
  labs(
    x = "Actual Relative Abundance (%)",
    y = "Difference of Predicted and Actual Relative Abundance (%)",
    title = ""
  ) +
  # ylim(-10500, 10500) + # Set y-axis limits
  # xlim(0, 100000) + # Set y-axis limits
  theme_minimal(base_size = 18) +
  theme(
    panel.grid = element_blank(),  # Remove grid lines
    panel.border = element_blank(),  # Remove the outer rectangle border
    axis.ticks = element_line(),  # Show ticks for the x and y axis
    axis.line = element_line(color = "black"),  # Show axis lines
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 18),
    axis.title = element_text(face = "bold", size = 16),
    axis.text = element_text(color = "black", size = 16),
    axis.text.x = element_text(angle = 0),
    legend.title = element_text(face = "bold", size = 16),
    legend.text = element_text(size = 16),
    legend.position = c(1, 1),  # Place the legend inside the chart
    legend.justification = c("right", "top"),
    legend.box.background = element_rect(color = "black")
  ) +
  geom_text_repel(
    data = plot_data %>% filter(outlier),
    aes(label = tax_name),
    size = 3,
    max.overlaps = 20,
    color = "blue"
  ) +
  geom_text_repel(
    data = plot_data %>% filter(critical_outlier),
    aes(label = tax_name),
    size = 3,
    max.overlaps = 20,
    color = "red"
  )

ggsave(
  bland_altman_output,
  plot = p,
  width = 8,
  height = 13,
  dpi = 300)
