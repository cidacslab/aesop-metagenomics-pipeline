require(readr)
require(dplyr)

library(PMCMR)
library(ggpubr)

df_virus <- data_wrangling_metrics(df_metrics, TRUE, c("Viruses"))
df_bacteria <- data_wrangling_metrics(df_metrics, TRUE, c("Bacteria"))
df_taxons <- data_wrangling_metrics(df_metrics)

############################## SUMMARY STATISTIC ###############################

df_virus %>%
    select(
        read_length,
        species_accuracy,
        species_specificity,
        species_sensitivity,
        species_precision
    ) %>%
    group_by(read_length) %>%
    get_summary_stats()

df_bacteria %>%
    select(
        read_length,
        species_accuracy,
        species_specificity,
        species_sensitivity,
        species_precision
    ) %>%
    group_by(read_length) %>%
    get_summary_stats()

df_taxons %>%
    select(
        read_length,
        species_accuracy,
        species_specificity,
        species_sensitivity,
        species_precision
    ) %>%
    group_by(read_length) %>%
    get_summary_stats()

############################ STATISTIC SIGNIFICANCE ############################
?rstatix::friedman_test

rstatix::friedman_test(data = df_virus, species_accuracy ~ read_length | species)
rstatix::friedman_test(data = df_virus, species_specificity ~ read_length | species)
rstatix::friedman_test(data = df_virus, species_sensitivity ~ read_length | species)
rstatix::friedman_test(data = df_virus, species_precision ~ read_length | species)


rstatix::friedman_test(data = df_bacteria, species_accuracy ~ read_length | species)
rstatix::friedman_test(data = df_bacteria, species_specificity ~ read_length | species)
rstatix::friedman_test(data = df_bacteria, species_sensitivity ~ read_length | species)
rstatix::friedman_test(data = df_bacteria, species_precision ~ read_length | species)


rstatix::friedman_test(data = df_taxons, species_accuracy ~ read_length | species)
rstatix::friedman_test(data = df_taxons, species_specificity ~ read_length | species)
rstatix::friedman_test(data = df_taxons, species_sensitivity ~ read_length | species)
rstatix::friedman_test(data = df_taxons, species_precision ~ read_length | species)


############################### PAIRWISE COMPARISON ###############################
?PMCMRplus::frdAllPairsNemenyiTest

# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_virus$species_accuracy,
    df_virus$read_length,
    df_virus$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_virus$species_specificity,
    df_virus$read_length,
    df_virus$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_virus$species_sensitivity,
    df_virus$read_length,
    df_virus$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_virus$species_precision,
    df_virus$read_length,
    df_virus$species)


# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_bacteria$species_accuracy,
    df_bacteria$read_length,
    df_bacteria$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_bacteria$species_specificity,
    df_bacteria$read_length,
    df_bacteria$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_bacteria$species_sensitivity,
    df_bacteria$read_length,
    df_bacteria$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_bacteria$species_precision,
    df_bacteria$read_length,
    df_bacteria$species)


# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_taxons$species_accuracy,
    df_taxons$read_length,
    df_taxons$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_taxons$species_specificity,
    df_taxons$read_length,
    df_taxons$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_taxons$species_sensitivity,
    df_taxons$read_length,
    df_taxons$species)
# Perform the Nemenyi post-hoc test
PMCMRplus::frdAllPairsNemenyiTest(
    df_taxons$species_precision,
    df_taxons$read_length,
    df_taxons$species)
