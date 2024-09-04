

pathogen_options <- list(FALSE, TRUE)

# category_options <- list(c("bacteria", "archaea", "viruses"), c("bacteria", "archaea"), c("viruses"))
category_options <- list(c("bacteria"))

for (category_filter in category_options) {
  # category_filter <- category_options[[1]]
  category_name <- ifelse(
    length(category_filter) > 2,
    "all", category_filter[[1]]
    )

  for (pathogen_filter in pathogen_options) {
    # pathogen_filter <- pathogen_options[[1]]
    sample_data <- combined_df %>%
      filter(category %in% category_filter)

    if (pathogen_filter)
      sample_data <- sample_data %>%
        filter(tax_id %in% pathogen_df$tax_id)


    filter_name <- paste0("for ",
      ifelse(pathogen_filter, "pathogen ", ""),
      category_name, " taxa")

    bland_altman_output <- paste0(
      "results/modified_bland_altman/",
      ifelse(pathogen_filter, "pathogen_", ""),
      category_name, "_taxa_bland_altman_plot.png")

    # source("src/3-paper-figures/barplot_true_predicted.r")



    color_blind_palette <- c("#E69F00", "#56B4E9")  # Adjust as needed
    # source("src/3-paper-figures/barplot_true_predicted_samples_by_side.r")
    output_preffix_multi_barplots <- paste0(
      "results/", category_name, "/side_by_side_",
      ifelse(pathogen_filter, "pathogen_", ""),
      category_name, "_reads_comparison_part_")

    output_single_barplot <- paste0(
      "results/", category_name, "/side_by_side_",
      ifelse(pathogen_filter, "pathogen_", ""),
      category_name, "_reads_comparison.png")
    source("src/3-paper-figures/barplot_true_predicted_samples_by_side.r")
    # Statistics
    # source("src/3-paper-figures/statistics.r")
    # Bland Altman plot
    # source("src/3-paper-figures/bland_altman_plot.r")
    group_names <- unique(sample_data$group_name)
    for (groupname in group_names) {
    #   color_blind_palette <- c("#E69F00", "#56B4E9")  # Adjust as needed

      output_preffix_multi_barplots <- paste0(
        "results/", category_name, "/", ifelse(pathogen_filter, "pathogen_", ""),
        groupname, "_reads_comparison_part_")

      output_single_barplot <- paste0(
        "results/", category_name, "/", ifelse(pathogen_filter, "pathogen_", ""),
        groupname, "_reads_comparison.png")

      # groupname <- "CSI004"
      # source("src/3-paper-figures/barplot_true_predicted.r")

    #   output_preffix_multi_barplots <- paste0(
    #     "results/", category_name, "/", name, "_", category_name,
    #     "_reads_comparison_part_")

    #   output_single_barplot <- paste0(
    #     "results/", category_name, "/", name, "_", category_name,
    #     "_reads_comparison.png")

    #   # Taxon Barplot per sample
    #   # source("src/3-paper-figures/barplot_true_predicted_per_sample.r")
    }
  }
}