
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


plot_data <- summary_df %>%
  mutate(
    diff_reads = case_when(
      # true_reads == predicted_reads ~ 0,
      mean_predicted_reads > 2 * mean_true_reads ~ -1,
      TRUE ~ (mean_true_reads - mean_predicted_reads) / mean_true_reads
    )
  )

mean_diff <- mean(plot_data$diff_reads)
sd_diff <- sd(plot_data$diff_reads)

# Identify points outside the ±1.96 SD range
plot_data$outlier <- abs(plot_data$diff_reads) > 1.96 * sd_diff


p <- ggplot(
  data = plot_data,
  aes(x = mean_true_reads, y = diff_reads)
  ) +
  geom_point(alpha = 0.5) +
  geom_hline(
    yintercept = mean_diff,
    color = "red",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = mean_diff + 1.96 * sd_diff,
    color = "blue",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = mean_diff - 1.96 * sd_diff,
    color = "blue",
    linetype = "dashed"
  ) +
  labs(
    x = "Number of True Reads",
    y = "Difference between True and Predicted Reads",
    title = paste0("Bland-Altman Plot ", filter_name)
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
    color = "red"
  ) # +
#   geom_label_repel(
#   data = sample_data %>% filter(outlier),
#   aes(label = tax_name),
#   size = 3,
#   color = "black",  # Text color
#   fill = "white",   # Label background color
#   box.padding = 0.3,
#   point.padding = 0.5,
#   segment.color = "grey50",  # Line color connecting label and point
#   label.size = 0.5           # Border size of the label box
# )

ggsave(bland_altman_output, plot = p, dpi = 300)
