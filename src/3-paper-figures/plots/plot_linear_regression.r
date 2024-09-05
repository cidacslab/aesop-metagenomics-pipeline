

# Load all taxa data
data <- combined_df %>%
  filter(true_reads > 0 | predicted_reads > 0)

# Perform linear regression
lm_model <- lm(true_reads ~ predicted_reads, data = data)

# Display the summary of the linear regression model
summary(lm_model)

# Perform Pearson correlation
cor_model <- cor.test(data$true_reads, data$predicted_reads, method = "pearson")
cor_model

# Plot the true reads vs predicted reads with the regression line
p <- ggplot(data, aes(x = predicted_reads, y = true_reads)) +
  geom_point() +
  stat_cor(method = "pearson", label.x = 0.05, label.y = max(data$true_reads)) +
  # geom_text(paste0("p<0.001"), position = c(0, 0.9)) +
  geom_smooth(method = "lm", color = "red") +
  labs(
    title = "",
    x = "Predicted Species Relative Abundance (%)",
    y = "Species Relative Abundance in Samples (%)"
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
    axis.text.x = element_text(angle = 0, hjust = 0.5),
    legend.position = "none"  # Remove the legend
  )

ggsave(
  linear_regression_output,
  plot = p,
  width = 6,
  height = 6,
  dpi = 300
)
