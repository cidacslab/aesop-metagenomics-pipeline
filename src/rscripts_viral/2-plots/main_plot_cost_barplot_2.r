
df_time_cost <- data.frame(
    read_length = c("150", "300"),
    time = c(1.7, 3.1),
    cost = c(2, 4)
)

grid_plots <- wrap_plots(
    ggplot(
        df_time_cost,
        aes(x = read_length, y = time)
        ) +
        geom_bar(stat = "identity", fill = NA, colour = "black") +
        coord_cartesian(ylim = c(0, 4)) +
        labs(y = "X times more than 75bp") +
        theme_bw() +
        theme(
            text = element_text(family = "Arial", face = "bold"),
            plot.title = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_text(
                face = "bold",
                size = 18,
                hjust = 0.5,
                margin = margin(r = 10)
                ),
            axis.text = element_text(size = 14, face = "plain"),
            axis.line = element_line(colour = "black"),
            panel.grid = element_blank(),
            panel.background = element_blank(),
            panel.border = element_blank()
        ),
    ggplot(
        df_time_cost,
        aes(x = read_length, y = cost)
        ) +
        geom_bar(stat = "identity", fill = NA, colour = "black") +
        coord_cartesian(ylim = c(0, 4)) +
        theme_bw() +
        theme(
            text = element_text(family = "Arial", face = "bold"),
            plot.title = element_blank(),
            axis.title = element_blank(),
            axis.text.x = element_text(size = 14, face = "plain"),
            axis.line.x = element_line(colour = "black"),
            axis.ticks.y = element_blank(),
            axis.text.y = element_blank(),
            axis.line.y = element_blank(),
            panel.grid = element_blank(),
            panel.background = element_blank(),
            panel.border = element_blank()
        ),
  ncol = 2,
  nrow = 1
  ) +
  plot_annotation(
    title = "         Time                                                          Cost",
    caption = "Read Length (bp)",
    tag_levels = c("A"),
    theme = theme(
    plot.title = element_text(size = 20, hjust = 0.5),
    plot.caption = element_text(size = 18, hjust = 0.5),
    plot.tag = element_text(size = 10)
    )
)

grid_plots

output_file <- paste0(results_folder_root, "fig4/time_cost_efficiency.png")

ggsave(output_file, plot = grid_plots, width = 11, height = 8, dpi = 300)
