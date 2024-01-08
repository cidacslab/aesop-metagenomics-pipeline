# Loads the required packages
require(pheatmap)

plot_heatmap_function <- function(df, plot_width, plot_heigth, output_filename,
  color_breaks = NULL, heat_colors = NULL, show_colnames = TRUE) {

    # define the heatmap color breaks values
    if (is.null(color_breaks)) {
        color_breaks <- c(
            0, 1, 5, 25, 100, 500, 1000,
            5000, 10000, 50000, 220000, 450000
        )
    }

    # define the pheatmap colors
    if (is.null(heat_colors)) {
        heat_colors <- c(
            "grey80", "#FFFFCC", "#FFEFA5", "#FEDC7F",
            "#FEBF5B", "#FD9D43", "#FC7034", "#F23D26",
            "#D91620", "#B40325", "#800026"
        )
    }

    # arrange data and plot
    p <- pheatmap(
        df,
        cluster_rows = FALSE,
        cluster_cols = FALSE,
        treeheight_row = 0,
        show_rownames = TRUE,
        show_colnames = show_colnames,
        color = heat_colors,
        breaks = color_breaks,
        legend = TRUE,
        dendogram = "none",
        width = plot_width,
        height = plot_heigth,
        fontsize = 12,
        # angle_col = 270,
        labels_row = NULL,  # Remove y-axis labels
        filename = output_filename
    )

    return(p)
}
