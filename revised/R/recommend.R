recommendation_feature_names <- c(clustering_feature_names, "MSRP")

recommendation_matrix <- function(vehicle_data) {
  feature_matrix <- as.matrix(vehicle_data[, recommendation_feature_names])
  feature_matrix[, "MSRP"] <- log(feature_matrix[, "MSRP"])
  feature_matrix
}

fit_recommender_reference <- function(vehicle_data) {
  feature_matrix <- recommendation_matrix(vehicle_data)
  list(
    center_values = colMeans(feature_matrix),
    scale_values = apply(feature_matrix, 2, sd)
  )
}

recommend_vehicles <- function(preferences, vehicle_data, brand_count = 3) {
  unknown_names <- setdiff(names(preferences), recommendation_feature_names)
  if (length(unknown_names) > 0) stop("Unknown preference names: ", paste(unknown_names, collapse = ", "))
  if (length(preferences) == 0) stop("Provide at least one preference.")
  reference <- fit_recommender_reference(vehicle_data)
  feature_matrix <- recommendation_matrix(vehicle_data)
  scaled_matrix <- scale_with_reference(feature_matrix, reference$center_values, reference$scale_values)
  preference_vector <- unlist(preferences)
  if ("MSRP" %in% names(preference_vector)) preference_vector["MSRP"] <- log(preference_vector["MSRP"])
  preference_scaled <- (preference_vector - reference$center_values[names(preference_vector)]) / reference$scale_values[names(preference_vector)]
  differences <- sweep(scaled_matrix[, names(preference_vector), drop = FALSE], 2, preference_scaled, "-")
  distances <- sqrt(rowSums(differences^2))
  ordered_index <- order(distances)
  best_per_brand <- ordered_index[!duplicated(vehicle_data$Make[ordered_index])]
  chosen_index <- head(best_per_brand, brand_count)
  result <- vehicle_data[chosen_index, c("Make", "Model", "Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg", "MSRP")]
  result$Distance <- distances[chosen_index]
  rownames(result) <- NULL
  result
}
