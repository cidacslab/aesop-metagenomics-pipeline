################################ LOAD REPORTS ##################################
parameters_to_fit_page <- function(n_rows, output_file, rows_per_page = 100) {

    ini_row <- 1
    end_row <- rows_per_page
    total_rows <- n_rows

    plots_attributes <- list()

    counter <- 1
    while (end_row < total_rows) {
        filename <- paste0(output_file, "_", counter, ".png")
        plots_attributes[[counter]] <- list(ini_row, end_row, 17, filename)

        ini_row <- end_row + 1
        end_row <- end_row + rows_per_page
        counter <- counter + 1
    }
    remaining <- total_rows - ini_row
    if (counter > 1) {
        filename <- paste0(output_file, "_", counter, ".png")
        if (remaining < 5) {
            plots_attributes[[counter-1]][2] <- total_rows
            return(plots_attributes)
        }
    } else {
        filename <- paste0(output_file, ".png")
    }

    height <- round((remaining/rows_per_page) * 15 + 2)
    plots_attributes[[counter]] <- list(ini_row, total_rows, height, filename)

    return(plots_attributes)
}
