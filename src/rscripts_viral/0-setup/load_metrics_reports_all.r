
################################## LOAD DATA ###################################
load_metrics_reports_all <- function(reports_folder_path, file_suffix) {

  df_metrics <- load_metrics_report_file(reports_folder_path, file_suffix)

  df_groups <- df_metrics %>%
    group_by(sample_group, sample_name) %>%
    summarise(n = n())

  df_group_cat <- df_groups %>%
    group_by(sample_group) %>%
    summarise(n_samples = n())
    View(df_group_cat)

  return(df_metrics)
}
