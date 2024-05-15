
if (length(category) == 1) {
  #  output name
  output_barplot <- paste0(
      output_folder,
      "barplot_", dataset_name,
      "_", category, "_pathogens.png")

  df_final <- df_means %>%
    filter(category %in% category_filter) %>%
    select(name, mean_rpm)

  ggplot(df_final, aes(y = name, x = mean_rpm, fill = mean_rpm)) +
    geom_bar(stat = "identity") +
    scale_x_continuous(position = "top") +
    scale_fill_viridis_c() +
    ylab("") +
    xlab("Pathogen abundance") +
    theme_bw() +
    theme(
      axis.text.x = element_text(angle = 0, vjust = 1, hjust = 0.5),
      axis.line = element_line(colour = "black"),
      axis.line.x.top = element_line(colour = "black"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_blank(),
      panel.background = element_blank()
    )

} else {
  output_barplot <- paste0(
    output_folder,
    "barplot_", dataset_name,
    "_complete_pathogens.png")

  category_colors <- c("viruses" = "#b7bf22", "bacteria" = "#e40909", "eukarya" = "#135813")

  ggplot(df_means, aes(y = name, x = mean_rpm, fill = category)) +
    geom_bar(stat = "identity") +
    scale_x_continuous(position = "top") +
    scale_fill_manual(name = "", values = category_colors) +
    ylab("") +
    xlab("Pathogen abundance") +
    theme_bw() +
    theme(
      axis.text.x = element_text(angle = 0, vjust = 1, hjust = 0.5),
      axis.line = element_line(colour = "black"),
      axis.line.x.top = element_line(colour = "black"),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border = element_blank(),
      panel.background = element_blank()
    )
}

ggsave(output_barplot, plot = last_plot(), width = 7, height = 15, dpi = 300)