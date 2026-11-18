source("revised/R/load_all.R")
library(ggplot2)

light_theme <- theme_minimal() + theme(plot.background = element_rect(fill = "white", colour = NA), panel.background = element_rect(fill = "white", colour = NA))

vehicle_data <- remove_exact_duplicates(load_vehicle_data())
vehicle_data <- apply_imputer(vehicle_data, fit_imputer(vehicle_data))
groups <- split_electric_vehicles(vehicle_data)
cat(sprintf("✓ %d electric vehicles set aside, %d implausible rows dropped, %d combustion and hybrid vehicles clustered\n", nrow(groups$electric), nrow(groups$implausible), nrow(groups$combustion)))

feature_frame <- groups$combustion[, clustering_feature_names]
scaled_for_selection <- scale_with_reference(feature_frame, colMeans(feature_frame), apply(feature_frame, 2, sd))
silhouette_table <- choose_cluster_count(scaled_for_selection)
chosen_cluster_count <- silhouette_table$cluster_count[which.max(silhouette_table$mean_silhouette)]
cat(sprintf("✓ silhouette selects k = %d\n", chosen_cluster_count))

clustering <- cluster_combustion_vehicles(groups$combustion, chosen_cluster_count)
combustion_labels <- paste0("segment_", clustering$fit$cluster)
clustered_data <- rbind(groups$electric, groups$combustion)
segment_labels <- c(rep("electric", nrow(groups$electric)), combustion_labels)
profile_table <- profile_segments(clustered_data, segment_labels)

dir.create(file.path("revised", "results"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path("revised", "figures"), showWarnings = FALSE, recursive = TRUE)
write.csv(silhouette_table, file.path("revised", "results", "cluster_silhouette.csv"), row.names = FALSE)
write.csv(profile_table, file.path("revised", "results", "cluster_profile.csv"), row.names = FALSE)

silhouette_plot <- ggplot(silhouette_table, aes(cluster_count, mean_silhouette)) + geom_line() + geom_point() +
  labs(title = "Silhouette by number of clusters", x = "Number of clusters", y = "Mean silhouette width") + light_theme
ggsave(file.path("revised", "figures", "cluster_silhouette.png"), silhouette_plot, width = 6, height = 4, dpi = 150, bg = "white")

principal_components <- prcomp(clustering$scaled_matrix)
pca_table <- data.frame(PC1 = principal_components$x[, 1], PC2 = principal_components$x[, 2], segment = combustion_labels)
pca_plot <- ggplot(pca_table, aes(PC1, PC2, colour = segment)) + geom_point(alpha = 0.5, size = 0.8) +
  labs(title = "Combustion and hybrid vehicle segments (PCA view)", x = "Principal component 1", y = "Principal component 2") + light_theme
ggsave(file.path("revised", "figures", "cluster_pca.png"), pca_plot, width = 7, height = 5, dpi = 150, bg = "white")

price_table <- data.frame(segment = segment_labels, MSRP = clustered_data$MSRP)
price_plot <- ggplot(price_table, aes(segment, MSRP)) + geom_boxplot() + coord_cartesian(ylim = c(0, 120000)) +
  labs(title = "MSRP by segment (axis clipped at 120000)", x = "Segment", y = "MSRP") + light_theme
ggsave(file.path("revised", "figures", "cluster_price.png"), price_plot, width = 7, height = 5, dpi = 150, bg = "white")
cat("✓ wrote cluster tables and figures\n")
