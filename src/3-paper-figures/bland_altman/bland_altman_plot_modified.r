


# Calculate percentage of correct classification
sample_data <- modified_df %>%
  mutate(
    correct_percentage = (predicted_reads / true_reads) * 100
  )

# Determine the mean and standard deviation for correct percentage
mean_correct <- mean(sample_data$correct_percentage, na.rm = TRUE)
sd_correct <- sd(sample_data$correct_percentage, na.rm = TRUE)

# Calculate percentage of correct classification
sample_data <- sample_data %>%
  mutate(
    outlier = abs(mean_correct) > 1.96 * sd_correct
  )

# Identify the first occurrence of each taxa name among outliers
outlier_data <- sample_data %>% filter(outlier)
first_occurrences <- outlier_data %>%
  distinct(tax_name, .keep_all = TRUE)

# Merge the positions of first occurrences with the main data
sample_data <- sample_data %>%
  left_join(
    first_occurrences %>%
      select(
        tax_name,
        first_x = true_reads,
        first_y = correct_percentage
      ),
    by = "tax_name")

# Plotting
p <- ggplot(
  data = sample_data,
  aes(x = true_reads, y = correct_percentage)
) +
  geom_point(alpha = 0.5) +
  geom_hline(
    yintercept = mean_correct,
    color = "red",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = mean_correct + 1.96 * sd_correct,
    color = "blue",
    linetype = "dashed"
  ) +
  geom_hline(
    yintercept = mean_correct - 1.96 * sd_correct,
    color = "blue",
    linetype = "dashed"
  ) +
  labs(
    x = "Number of True Reads",
    y = "Percentage of Correct Classification",
    title = paste0("Bland-Altman Plot ", filter_name)
  ) +
  # ylim(-10500, 10500) + # Set y-axis limits
  xlim(0, 100000) + # Set y-axis limits
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
  geom_label_repel(
    data = first_occurrences,
    aes(label = tax_name),
    size = 3,
    color = "red"
  ) +
  # Draw arrows from subsequent points to the first occurrence
  geom_segment(
    data = sample_data %>%
      filter(outlier) %>%
      filter(!is.na(first_x) & !is.na(first_y)),
    aes(xend = first_x, yend = first_y),
    # arrow = arrow(length = unit(0.2, "cm")),
    color = "grey50"
  )
  # +
  # geom_text_repel(
  #   data = sample_data %>% filter(outlier),
  #   aes(label = tax_name),
  #   size = 3,
  #   color = "red"
  # ) # +
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