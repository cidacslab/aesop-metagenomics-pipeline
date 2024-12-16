
source("src/aesop/plot_heatmap.r")
source("src/aesop/parameters_to_fit_page.r")
source("src/paper/data_wrangling_heatmap.r")
source("src/paper/data_wrangling_heatmap_by_sample.r")

############################ GET HEATMAP PARAMETERS ############################
breaks <- c(
  0, 0.01, 20, 40, 60, 70,
  80, 85, 90, 93, 96, 100
)
colors <- c(
  "grey80", "#FFFFCC", "#FFEFA5", "#FEDC7F",
  "#FEBF5B", "#FD9D43", "#FC7034", "#F23D26",
  "#D91620", "#B40325", "#800026"
)

metric <- "species_sensitivity"
df_sens <- data_wrangling_heatmap(df_metrics, metric, NULL, TRUE, c("Viruses"))

n_rows <- nrow(df_sens)
plot_parameters <- parameters_to_fit_page(n_rows, "")
parameters <- plot_parameters[[1]]
heigth <- parameters[[3]]
width <- 6

############################### HEATMAP METRICS ################################

plots <- list()
metrics <- c("sensitivity", "specificity", "accuracy", "precision")

for (metric in metrics) {
  metric_col <- paste0("species_", metric)
  file <- paste0(results_folder, "heatmap_", metric, "_patho_virus.csv")
  df <- data_wrangling_heatmap(df_metrics, metric_col, file, TRUE, c("Viruses"))

  order_in_sens <- match(df_sens$species, df$species)
  df <- as.data.frame(df[order_in_sens, ]) %>%
    column_to_rownames(var = "species")

  file <- paste0(results_folder, "heatmap_", metric, "_patho_virus.png")
  plot <- plot_heatmap_function(df, width, heigth, file, breaks, colors)
  plots[[metric]] <- plot
}

for (metric in metrics) {
  metric_col <- paste0("species_", metric)
  file <- paste0(results_folder, "heatmap_", metric, "_patho_bacteria.csv")
  df <- data_wrangling_heatmap(df_metrics, metric_col, file, TRUE, c("Bacteria"))

  df <- as.data.frame(df[order_in_sens, ]) %>%
    column_to_rownames(var = "species")

  file <- paste0(results_folder, "heatmap_", metric, "_patho_bacteria")

  n_rows <- nrow(df_bacteria)
  file <- paste0(results_folder, "heatmap_", metric, "_patho_bacteria_sample")
  plot_parameters <- parameters_to_fit_page(n_rows, file, 85)

  for (parameters in plot_parameters) {
    df <- df_bacteria[parameters[[1]]:parameters[[2]], ]
    file <- parameters[[4]]
    heigth <- parameters[[3]]
    width <- 14
    plot <- plot_heatmap_function(df, width, heigth, file, breaks, colors)
    plots[[metric]] <- plot
  }
}


############################### HEATMAP METRICS ################################
## VIRUS BY SAMPLE
metric <- metrics[[1]]
metric_col <- paste0("species_", metric)
file <- paste0(results_folder, "heatmap_", metric, "_patho_virus_sample.csv")
df <- data_wrangling_heatmap_by_sample(df_metrics, metric_col, file, TRUE, c("Viruses"))

df <- df %>%
  column_to_rownames(var = "species")

width <- 10
file <- paste0(results_folder, "heatmap_", metric, "_patho_virus_sample.png")

pheatmap(
  df,
  cluster_rows = FALSE,
  cluster_cols = FALSE,
  dendogram = "none",
  treeheight_row = 0,
  show_rownames = TRUE,
  show_colnames = FALSE,
  gaps_col = c(3),
  color = colors,
  breaks = breaks,
  legend = TRUE,
  width = width,
  height = heigth,
  fontsize = 12,
  filename = file
)


############################### HEATMAP METRICS ################################
## BACTERIA BY SAMPLE
file <- paste0(results_folder, "heatmap_", metric, "_patho_bacteria_sample.csv")
df <- data_wrangling_heatmap_by_sample(df_metrics, metric_col, file, TRUE, c("Bacteria"))

df_bacteria <- df %>%
  column_to_rownames(var = "species")

n_rows <- nrow(df_bacteria)
file <- paste0(results_folder, "heatmap_", metric, "_patho_bacteria_sample")
plot_parameters <- parameters_to_fit_page(n_rows, file, 85)

for (parameters in plot_parameters) {
  df <- df_bacteria[parameters[[1]]:parameters[[2]], ]
  file <- parameters[[4]]
  heigth <- parameters[[3]]
  width <- 14

  pheatmap(
    df,
    cluster_rows = FALSE,
    cluster_cols = FALSE,
    dendogram = "none",
    treeheight_row = 0,
    show_rownames = TRUE,
    show_colnames = FALSE,
    gaps_col = c(13),
    color = colors,
    breaks = breaks,
    legend = TRUE,
    width = width,
    height = heigth,
    fontsize = 12,
    filename = file
  )
}
