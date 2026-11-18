clustering_feature_names <- c("Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg", "Popularity")

split_electric_vehicles <- function(vehicle_data, implausible_mpg_limit = 100) {
  is_electric <- vehicle_data$Engine.Fuel.Type == "electric"
  is_implausible <- !is_electric & vehicle_data$highway.MPG > implausible_mpg_limit
  list(
    electric = vehicle_data[is_electric, , drop = FALSE],
    combustion = vehicle_data[!is_electric & !is_implausible, , drop = FALSE],
    implausible = vehicle_data[is_implausible, , drop = FALSE]
  )
}

scale_with_reference <- function(feature_frame, center_values, scale_values) {
  scaled <- sweep(as.matrix(feature_frame), 2, center_values, "-")
  sweep(scaled, 2, scale_values, "/")
}

unscale_with_reference <- function(scaled_matrix, center_values, scale_values) {
  sweep(sweep(scaled_matrix, 2, scale_values, "*"), 2, center_values, "+")
}

choose_cluster_count <- function(scaled_matrix, candidate_counts = 2:8, seed = 1, silhouette_sample_size = 3000) {
  set.seed(seed)
  sample_index <- sample(nrow(scaled_matrix), min(silhouette_sample_size, nrow(scaled_matrix)))
  sample_distances <- dist(scaled_matrix[sample_index, ])
  scores <- vapply(candidate_counts, function(cluster_count) {
    fit <- kmeans(scaled_matrix, centers = cluster_count, nstart = 25, iter.max = 100)
    mean(cluster::silhouette(fit$cluster[sample_index], sample_distances)[, "sil_width"])
  }, numeric(1))
  data.frame(cluster_count = candidate_counts, mean_silhouette = scores)
}

cluster_combustion_vehicles <- function(combustion_data, cluster_count, seed = 1) {
  feature_frame <- combustion_data[, clustering_feature_names]
  center_values <- colMeans(feature_frame)
  scale_values <- apply(feature_frame, 2, sd)
  scaled_matrix <- scale_with_reference(feature_frame, center_values, scale_values)
  set.seed(seed)
  fit <- kmeans(scaled_matrix, centers = cluster_count, nstart = 25, iter.max = 100)
  list(fit = fit, scaled_matrix = scaled_matrix, center_values = center_values, scale_values = scale_values)
}

profile_segments <- function(vehicle_data, segment_labels) {
  profile_columns <- c(clustering_feature_names, target_column)
  profile_rows <- lapply(split(vehicle_data, segment_labels), function(segment_data) {
    medians <- vapply(segment_data[, profile_columns], median, numeric(1))
    c(vehicle_count = nrow(segment_data), medians)
  })
  profile_table <- as.data.frame(do.call(rbind, profile_rows))
  cbind(segment = rownames(profile_table), profile_table, row.names = NULL)
}
