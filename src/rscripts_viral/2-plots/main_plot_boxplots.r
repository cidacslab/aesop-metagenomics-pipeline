
source("src/rscripts_viral/1-data_wrangling/data_wrangling_metrics.r")
source("src/rscripts_viral/2-plots/generate_boxplots.r")

results_folder <- paste0(results_folder_root, "fig1/")
# Create the folder structure
dir.create(results_folder, recursive = TRUE, showWarnings = FALSE)

################################ VIRUSES MEANS #################################

df_virus <- data_wrangling_metrics(df_metrics, FALSE, c("Viruses"))
output_file <- paste0(results_folder, "metrics_patho_viruses.csv")
write.csv(df_virus, file = output_file, row.names = TRUE)

################################## GRID PLOTS ##################################

figure1_file <- paste0(results_folder, "figure1.png")
suppl1_file <- paste0(results_folder, "suppl1.png")

virus_plots <- generate_boxplots(df_virus)

################################### FIGURE 1 ###################################

grid_plots <- wrap_plots(
  virus_plots[["species_sensitivity"]] +
    theme(
      axis.title.y = element_text(face = "bold", size = 18),
      axis.text = element_text(size = 14)
    ),
  virus_plots[["species_precision"]] +
    theme(
      axis.title.y = element_text(face = "bold", size = 18),
      axis.text = element_text(size = 14)
    ),
  ncol = 2,
  nrow = 1
  ) +
  plot_annotation(
    title = "          Viral Pathogens        ",
    caption = "Read Length (bp)",
    tag_levels = c("A"),
    theme = theme(
      plot.title = element_text(size = 20, face = "bold", hjust = 0.5),
      plot.caption = element_text(size = 18, face = "bold", hjust = 0.5),
      plot.tag = element_text(size = 10)
      )
    )

ggsave(figure1_file, plot = grid_plots, width = 12, height = 3, dpi = 300)


############################ SUPPLEMENTARY FIGURE 1 ############################

all_plots <- wrap_plots(
  wrap_plots(
    virus_plots[["species_accuracy"]] +
      labs(
        title = str_wrap("Viral Pathogens Species", 20)
      ) +
      theme(
        plot.title = element_text(face = "bold"),
        axis.title.y = element_text(face = "bold"),
        axis.text.y = element_text()
      ),
    virus_plots[["species_specificity"]] +
      theme(
        axis.title.y = element_text(face = "bold"),
        axis.text.y = element_text()
      ),
    virus_plots[["species_sensitivity"]] +
      theme(
        axis.title.y = element_text(face = "bold"),
        axis.text.y = element_text()
      ),
    virus_plots[["species_precision"]] +
      theme(
        axis.title.y = element_text(face = "bold"),
        axis.text = element_text()
      ),
    nrow = 4
    ),
  wrap_plots(
    virus_plots[["genus_accuracy"]] +
      labs(
        title = str_wrap("Viral Pathogens Genera", 20)
      ) +
      theme(
        plot.title = element_text(face = "bold")
      ),
    virus_plots[["genus_specificity"]],
    virus_plots[["genus_sensitivity"]],
    virus_plots[["genus_precision"]] +
      theme(
        axis.text.x = element_text()
      ),
    nrow = 4
    ),
  ncol = 2,
  nrow = 1
  ) +
  plot_annotation(
    caption = "Read Length (bp)",
    theme = theme(
      plot.caption = element_text(size = 22, face = "bold", hjust = 0.5)
      )
    )


ggsave(suppl1_file, plot = all_plots, width = 20, height = 14, dpi = 300)
