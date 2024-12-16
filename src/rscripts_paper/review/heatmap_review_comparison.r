

# Use `complete` to fill in missing combinations
complete_binary_df <- review_df %>%
  filter(true_reads > 0) %>%
  complete(sample_name, name, fill = list(predicted_reads = 0, true_reads = 0))

# binarize and filter only taxa determined in existing_taxa
binary_df <- complete_binary_df %>%
  mutate(
    true_reads = ifelse(true_reads > 0, 1, 0),
    predicted_reads = ifelse(predicted_reads > 0, 1, 0),
    status = case_when(
      predicted_reads == 1 & true_reads == 1 ~ "Correctly Identified",
      predicted_reads == 0 & true_reads == 1 ~ "Not Identified",
      predicted_reads == 1 & true_reads == 0 ~ "Predicted",
      TRUE ~ "Neither"
    ),
    sample_name = factor(
      sample_name,
      levels = c(as.character(1:48), paste0("C", 1:8))
    )
  ) %>%
  filter(name %in% existing_taxa$name)

# print counting groups
count_df <- binary_df %>%
  group_by(status) %>%
  summarise(n = n())

count_eq <- sum(binary_df$predicted_reads == binary_df$true_reads)
print(paste0("Count identical values (both 0 or both 1): ", count_eq))

count <- sum(binary_df$predicted_reads != binary_df$true_reads)
print(paste0("Count differing values (one is 0 and the other is 1): ", count))

# Plot heatmap
p <- ggplot(binary_df, aes(x = sample_name, y = name, fill = status)) +
  geom_tile(color = "black") +
  scale_x_discrete(position = "top") +
  scale_fill_manual(
    values = c(
      "Correctly Identified" = "#49a149",
      "Not Identified" = "#c91e1e",
      "Predicted" = "#d1d12e",
      "Neither" = "white"
    ),
    # Exclude "Neither" from the legend
    breaks = c("Correctly Identified", "Not Identified")
  ) +
  labs(x = "Samples", y = "Taxon", fill = "Status") +
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
    legend.position = c(1, 0.9),  # Place the legend inside the chart
    legend.justification = c("right", "top"),
    legend.box.background = element_rect(color = "black")
  )

# Save plot
ggsave(
  filename = output_file,
  plot = p,
  width = 20,
  height = 8,
  dpi = 300
)
