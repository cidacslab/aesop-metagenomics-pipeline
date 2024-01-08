

################################################################################
########################### HEATMAP ############################################

df_final <- df_ordered %>%
  filter(category %in% category_filter) %>%
  select(-mean_rpm, -category)


plots <- list()
count_plots <- 0
n_rows <- nrow(df_final)
plot_parameters <- parameters_to_fit_page(n_rows, output_heatmap, 80)

for (parameters in plot_parameters) {
  df <- df_final[parameters[[1]]:parameters[[2]], ]
  file <- parameters[[4]]
  heigth <- parameters[[3]]
  width <- 6
  plot <- plot_heatmap_function(df, width, heigth, file)

  count_plots <- count_plots + 1
  plots[[count_plots]] <- plot
}
