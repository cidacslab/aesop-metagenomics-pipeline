require(readr)
require(dplyr)

################################ DATA WRANGLING ################################
data_wrangling_metrics <- function(
    df_metrics,
    load_pathogens = FALSE,
    pathogens_realm = c("Viruses")) {

    df_patho_taxon <- df_metrics
    if (load_pathogens) {
        df_pathogens <- read_csv("data/czid_rpip_vsp_who_cdc_pathogens_20240814.csv")

        df_patho_taxon <- df_patho_taxon %>%
            inner_join(df_pathogens, by = c("species_taxid" = "tax_id")) %>%
            filter(realm %in% pathogens_realm)
    }

    df_metrics_means_taxons <- df_patho_taxon  %>%
        # filter(read_length %in% c("75", "150", "300")) %>%
        mutate(
            read_length = factor(read_length, levels = c("75", "150", "300")),
            species = as.factor(species)
        ) %>%
        group_by(
            read_length,
            species
        ) %>%
        summarise(
            species_sensitivity = mean(species_sensitivity) * 100,
            species_specificity = mean(species_specificity) * 100,
            species_accuracy = mean(species_accuracy) * 100,
            species_precision = mean(species_precision) * 100,
            genus_sensitivity = mean(genus_sensitivity) * 100,
            genus_specificity = mean(genus_specificity) * 100,
            genus_accuracy = mean(genus_accuracy) * 100,
            genus_precision = mean(genus_precision) * 100
        ) %>%
        ungroup()

    return(df_metrics_means_taxons)
}
