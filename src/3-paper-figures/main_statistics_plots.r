

print("Number of existing taxa in mocks:")

sample_data <- combined_df %>%
  filter(true_reads > 0)

length(unique(sample_data$tax_id))


print("Number of correctly predicted pathogen taxa:")
sample_data <- combined_df %>%
  filter(true_reads > 0 & predicted_reads > 0) %>%
  filter(tax_id %in% pathogen_df$tax_id)

length(unique(sample_data$tax_id))


# source("src/3-paper-figures/statistics/correlation.r")


# mean_reads <- rowMeans(cbind(sample_data$true_reads,
#                              sample_data$predicted_reads))


plot_data <- combined_df %>%
  # filter(true_reads > 0) %>%
  filter(true_reads > 0 & predicted_reads > 0) %>%
  filter(tax_id %in% pathogen_df$tax_id) %>%
  mutate(
    # diff_reads = predicted_reads - true_reads
    diff_reads = case_when(
      true_reads == predicted_reads ~ 0,
      predicted_reads > 2 * true_reads ~ 1,
      TRUE ~ (predicted_reads - true_reads) / true_reads
    )
  )
length(unique(plot_data$tax_id))


# Plot critical bacterias of high priority species
critical_species_pathogen_df <- pathogen_df %>%
  filter(high_priority_species == "1")
# Plot critical viruses in high priority families
critical_family_pathogen_df <- pathogen_df %>%
  filter(family_priority == "1")

plot_means <- plot_data %>%
  # filter(category %in% c("viruses")) %>%
  # filter(tax_id %in% critical_family_pathogen_df$tax_id) %>%
  filter(category %in% c("bacteria", "archaea")) %>%
  filter(tax_id %in% critical_species_pathogen_df$tax_id) %>%
  group_by(group_name, tax_id, tax_name, category) %>%
  summarise(
    mean_diff_reads = mean(diff_reads),
    mean_true_reads = mean(true_reads),
    mean_predicted_reads = mean(predicted_reads),
    .groups = "drop"
  )


length(unique(plot_means$tax_id))

mean_diff <- mean(plot_means$mean_diff_reads)
sd_diff <- sd(plot_means$mean_diff_reads)





plot_means <- plot_data %>%
  group_by(group_name, tax_id, tax_name, category) %>%
  summarise(
    mean_diff_reads = mean(diff_reads),
    mean_true_reads = mean(true_reads),
    mean_predicted_reads = mean(predicted_reads),
    .groups = "drop"
  )


length(unique(plot_means$tax_id))

mean_diff <- mean(plot_means$mean_diff_reads)
sd_diff <- sd(plot_means$mean_diff_reads)

mean_diff <- 0
sd_diff <- 0.05

source("src/3-paper-figures/bland_altman/bland_altman_plot.r")
