
sample_data <- combined_df %>%
  filter(true_reads > 0 & predicted_reads > 0)

# print(paste0("Statistics ", filter_name))

# Statistics analysis
pearson_corr <- cor(
  sample_data$true_reads,
  sample_data$predicted_reads,
  method = "pearson")

spearman_corr <- cor(
  sample_data$true_reads,
  sample_data$predicted_reads,
  method = "spearman")

print(paste("Pearson Correlation:", pearson_corr))
print(paste("Spearman Correlation:", spearman_corr))

mae <- mean(abs(sample_data$true_reads - sample_data$predicted_reads))
rmse <- sqrt(mean((sample_data$true_reads - sample_data$predicted_reads)^2))

print(paste("Mean Absolute Error (MAE):", mae))
print(paste("Root Mean Squared Error (RMSE):", rmse))


df <- sample_data
# Calculate the relative error
df$relative_error <- (df$predicted_reads - df$true_reads) / df$true_reads

# Summary statistics for relative error
summary(df$relative_error)

# Plotting the distribution of relative errors
ggplot(df, aes(x = relative_error)) +
  geom_histogram(binwidth = 0.05, fill = "skyblue", color = "black") +
  labs(x = "Relative Error", y = "Frequency", title = "Distribution of Relative Errors") +
  theme_minimal()


############################ T-TEST and WILCOX TEST #####################################

# Paired t-test
t_test_result <- t.test(df$true_reads, df$predicted_reads, paired = TRUE)
print(t_test_result)

# Wilcoxon Signed-Rank Test
wilcox_test_result <- wilcox.test(df$true_reads, df$predicted_reads, paired = TRUE)
print(wilcox_test_result)


############################ ANOVA #############################################

# ANOVA (if data is normally distributed)
anova_result <- aov(predicted_reads ~ factor(group_name), data = df)
summary(anova_result)

# Kruskal-Wallis Test (non-parametric alternative)
kruskal_result <- kruskal.test(predicted_reads ~ factor(group_name), data = df)
print(kruskal_result)
