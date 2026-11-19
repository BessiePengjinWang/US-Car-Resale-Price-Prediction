clustering_feature_names <- c("Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg")

split_electric_vehicles <- function(vehicle_data, implausible_mpg_limit = 100, placeholder_price = 2000) {
  is_electric <- vehicle_data$Engine.Fuel.Type == "electric"
  is_implausible <- !is_electric & vehicle_data$highway.MPG > implausible_mpg_limit
  is_placeholder <- !is_electric & !is_implausible & vehicle_data$MSRP == placeholder_price
  list(
    electric = vehicle_data[is_electric, , drop = FALSE],
    combustion = vehicle_data[!is_electric & !is_implausible & !is_placeholder, , drop = FALSE],
    implausible = vehicle_data[is_implausible, , drop = FALSE],
    placeholder_price = vehicle_data[is_placeholder, , drop = FALSE]
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

name_segments <- function(segment_data, segment_ids) {
  segment_names <- vapply(sort(unique(segment_ids)), function(segment_id) {
    members <- segment_data[segment_ids == segment_id, ]
    two_door_share <- mean(members$Number.of.Doors == 2)
    body_phrase <- if (two_door_share >= 0.9) "Two-door" else if (two_door_share <= 0.1) "Four-door" else "Mixed doors"
    median_horsepower <- round(median(members$Engine.HP))
    power_phrase <- if (median_horsepower >= 400) "high-output" else sprintf("%d-cyl", round(median(members$Engine.Cylinders)))
    era_phrase <- if (median(members$Year) < 2008) sprintf(", years ~%d", round(median(members$Year))) else ""
    sprintf("%s, %s, ~%d HP%s", body_phrase, power_phrase, median_horsepower, era_phrase)
  }, character(1))
  names(segment_names) <- sort(unique(segment_ids))
  segment_names
}
