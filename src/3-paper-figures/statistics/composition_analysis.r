

sample_data <- combined_df %>%
  filter(category == "viruses")


real_df <- sample_data %>%
  rename(relative_abundance = true_reads) %>%
  select(sample_name, tax_id, relative_abundance)

predicted_df <- sample_data %>%
  rename(relative_abundance = predicted_reads) %>%
  select(sample_name, tax_id, relative_abundance)

# Pivot the data to create a wide-format matrix
real_composition <- real_df %>%
  pivot_wider(names_from = tax_id, values_from = relative_abundance, values_fill = list(relative_abundance = 0))

# Convert sample_name to rownames
real_composition <- column_to_rownames(real_composition, var = "sample_name")

# # Create a new column 'total_sum' that is the sum of all other columns
# # Sum relative abundances across all taxa (columns)
# real_composition$total_sum <- rowSums(real_composition)
# # Filter out rows where the total sum is 0
# real_composition <- real_composition[real_composition$total_sum != 0, ]
# # Remove the 'total_sum' column if it was just for filtering
# real_composition$total_sum <- NULL
# # Sum relative abundances across all samples (rows)
# col_sums <- colSums(real_composition)
# # Filter out columns where the total sum is 0
# real_composition <- real_composition[, col_sums != 0]
# Convert to a matrix if needed
real_matrix <- as.matrix(real_composition)


# Pivot the data to create a wide-format matrix
predicted_composition <- real_df %>%
  pivot_wider(names_from = tax_id, values_from = relative_abundance, values_fill = list(relative_abundance = 0))
# Convert sample_name to rownames
predicted_composition <- column_to_rownames(predicted_composition, var = "sample_name")

# # Create a new column 'total_sum' that is the sum of all other columns
# # Sum relative abundances across all taxa (columns)
# predicted_composition$total_sum <- rowSums(predicted_composition)
# # Filter out rows where the total sum is 0
# predicted_composition <- predicted_composition[predicted_composition$total_sum != 0, ]
# # Remove the 'total_sum' column if it was just for filtering
# predicted_composition$total_sum <- NULL
# # Sum relative abundances across all samples (rows)
# col_sums <- colSums(predicted_composition)
# # Filter out columns where the total sum is 0
# predicted_composition <- predicted_composition[, col_sums != 0]
# Convert to a matrix if needed
predicted_matrix <- as.matrix(predicted_composition)



library(vegan)

# Perform PCA on the real and predicted compositions
pca_real <- prcomp(real_matrix, scale = TRUE)
pca_predicted <- prcomp(predicted_matrix, scale = TRUE)

# Procrustes analysis to compare the two configurations
procrustes_result <- procrustes(pca_real$x, pca_predicted$x)
procrustes_test <- protest(pca_real$x, pca_predicted$x)
summary(procrustes_test)
plot(procrustes_result)






# Binarize the composition matrices (presence/absence)
real_binary <- real_matrix > 0
predicted_binary <- predicted_matrix > 0

# Calculate Jaccard Index
jaccard_index <- vegdist(rbind(real_binary, predicted_binary), method = "jaccard")



# Calculate Bray-Curtis Dissimilarity
bray_curtis_dissimilarity <- vegdist(rbind(real_matrix, predicted_matrix), method = "bray")

# Heatmap visualization
heatmap(as.matrix(bray_curtis_dissimilarity), main = "Bray-Curtis Dissimilarity Heatmap", 
        xlab = "Samples", ylab = "Samples", col = heat.colors(256))

# Hierarchical clustering
hc <- hclust(as.dist(bray_curtis_dissimilarity))
plot(hc, main = "Hierarchical Clustering of Samples Based on Bray-Curtis Dissimilarity")

# PCoA (Principal Coordinates Analysis)
pcoa_result <- cmdscale(bray_curtis_dissimilarity, eig = TRUE, k = 2)  # k = 2 for 2D plot
plot(pcoa_result$points, main = "PCoA based on Bray-Curtis Dissimilarity",
     xlab = "PCoA1", ylab = "PCoA2")

# NMDS (Non-Metric Multidimensional Scaling)
nmds_result <- metaMDS(bray_curtis_dissimilarity, k = 2)
plot(nmds_result, main = "NMDS based on Bray-Curtis Dissimilarity")







# Assuming real_composition and predicted_composition are vectors with counts for each taxon
chi_square_test <- chisq.test(real_matrix, predicted_matrix)
print(chi_square_test)
