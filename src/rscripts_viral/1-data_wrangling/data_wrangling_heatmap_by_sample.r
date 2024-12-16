require(readr)
require(dplyr)

############################### DATA WRANGLING ################################
data_wrangling_heatmap_by_sample <- function(
    df_metrics,
    metric_attribute,
    output_file = NULL,
    load_pathogens = FALSE,
    pathogens_realm = c("Bacteria", "Viruses")) {

    # output_file <- file
    # load_pathogens <- TRUE
    # pathogens_realm <- c("Bacteria")
    # metric_attribute <- "species_sensitivity"

    df_patho_taxon <- df_metrics
    if (load_pathogens) {
        df_pathogens <- read_csv("data/czid_rpip_vsp_pathogens.csv")

        df_patho_taxon <- df_patho_taxon %>%
            inner_join(df_pathogens, by = c("species_taxid" = "tax_id")) %>%
            filter(realm %in% pathogens_realm) %>%
            select(-realm)
    }

    df_unmelt <- df_patho_taxon %>%
        filter(read_length == "300") %>%
        group_by(
            species,
            sample_name
        ) %>%
        summarise(
            species_sensitivity = mean(species_sensitivity) * 100,
            species_specificity = mean(species_specificity) * 100,
            species_accuracy = mean(species_accuracy) * 100,
            species_precision = mean(species_precision) * 100,
        ) %>%
        ungroup() %>%
        select(
            species,
            sample_name,
            !!sym(metric_attribute)
        ) %>%
        arrange(desc(sample_name)) %>%
        pivot_wider(
            names_from = sample_name,
            values_from = !!sym(metric_attribute)
        )

    df_ordered <- df_unmelt %>%
        column_to_rownames(var = "species")  %>%
        mutate(
            average = rowMeans(., na.rm = TRUE)
        ) %>%
        rownames_to_column(var = "species") %>%
        arrange(-average, species) %>%
        select(-average)

    write.csv(df_ordered, file = output_file, row.names = TRUE)

    return(df_ordered)
}

