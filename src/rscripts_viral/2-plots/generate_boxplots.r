require(ggplot2)
require(stringr)

#################################### BOXPLOT ###################################
generate_boxplots <- function(df) {

    plots <- list()

    levels <- c("genus", "species")
    metrics <- c("sensitivity", "specificity", "accuracy", "precision")

    for (level_attribute in levels) {
        for (metric in metrics) {

            mean_attribute <- paste0(level_attribute, "_", metric)
            title_label <- str_to_title(gsub("_", " ", metric))
            y_label <- paste0(title_label, " (%)")

            y_min <- 94
            if (metric == "sensitivity") {
                y_min <- 94
            }

            p <- ggplot(
                df,
                aes(x = read_length, y = !!sym(mean_attribute))
                ) +
                scale_y_continuous(n.breaks = 3) +
                geom_boxplot(outlier.shape = NA) +
                coord_cartesian(ylim = c(y_min, 100)) +
                labs(
                    title = title_label,
                    x = "Read Length (bp)",
                    y = y_label
                    ) +
                theme_bw() +
                theme(
                    text = element_text(family = "Arial", size = 14),
                    plot.title = element_blank(),
                    axis.title = element_blank(),
                    axis.text = element_blank(),
                    axis.line = element_line(colour = "black"),
                    panel.grid.major = element_blank(),
                    panel.grid.minor = element_blank(),
                    panel.border = element_blank(),
                    panel.background = element_blank(),
                )

            plots[[mean_attribute]] <- p
        }
    }

    return(plots)
}
