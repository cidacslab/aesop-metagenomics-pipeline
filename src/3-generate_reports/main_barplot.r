

if (length(category_type) == 1) {
  ggplot(df_means, aes(y = name, x = mean_rpm, fill = mean_rpm)) +
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
  category_colors <- c("viruses" = "#b7bf22", "bacteria" = "#e40909")

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

ggsave(out_file, plot = last_plot(), width = 7, height = 15, dpi = 300)