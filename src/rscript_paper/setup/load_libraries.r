# Define a vector of the packages needed
packages <- c("tidyverse", "scales", "ggpubr", "ggrepel", "patchwork")

#  Function to check if a package is installed
# install it if missing, and then load it
install_and_load <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
  }
  library(pkg, character.only = TRUE)
  print(paste("Package version:", pkg, "", packageVersion(pkg)))
}

# Print package version
print("Loading packages")
print(paste0(R.version.string))

# Install and load the packages
invisible(lapply(packages, install_and_load))