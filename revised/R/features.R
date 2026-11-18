target_column <- "MSRP"

numeric_predictor_names <- c("Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg", "Popularity")

categorical_predictor_names <- c("Make", "Vehicle.Size", "Engine.Fuel.Type", "Transmission.Type", "Driven_Wheels", "Vehicle.Style")

excluded_high_cardinality_names <- c("Model", "Market.Category")

feature_set_definitions <- function(selected_predictor_names = NULL) {
  definitions <- list(
    numeric_only = numeric_predictor_names,
    numeric_plus_make = c(numeric_predictor_names, "Make")
  )
  if (!is.null(selected_predictor_names)) definitions$selected_top5 <- selected_predictor_names
  definitions
}

assert_no_target_leakage <- function(feature_names) {
  if (target_column %in% feature_names) stop("Target column MSRP must never be used as a predictor.")
  invisible(TRUE)
}

prepare_feature_frame <- function(vehicle_data, feature_names, factor_levels) {
  assert_no_target_leakage(feature_names)
  feature_frame <- vehicle_data[, feature_names, drop = FALSE]
  for (column_name in intersect(names(factor_levels), feature_names)) {
    feature_frame[[column_name]] <- factor(feature_frame[[column_name]], levels = factor_levels[[column_name]])
  }
  feature_frame
}

collect_factor_levels <- function(vehicle_data) {
  lapply(vehicle_data[, categorical_predictor_names, drop = FALSE], function(column_values) sort(unique(column_values)))
}

build_design_matrix <- function(feature_frame) {
  model.matrix(~ . - 1, data = feature_frame)
}

rank_features_on_training_data <- function(training_data, seed, tree_count = 200) {
  candidate_names <- c(numeric_predictor_names, categorical_predictor_names)
  factor_levels <- collect_factor_levels(training_data)
  candidate_frame <- prepare_feature_frame(training_data, candidate_names, factor_levels)
  set.seed(seed)
  importance_model <- randomForest::randomForest(
    x = candidate_frame, y = training_data[[target_column]], ntree = tree_count, importance = TRUE
  )
  importance_scores <- randomForest::importance(importance_model)[, "%IncMSE"]
  names(sort(importance_scores, decreasing = TRUE))
}

select_top_features <- function(ranked_names, training_data, feature_count = 5, correlation_limit = 0.7) {
  selected_names <- character(0)
  for (candidate_name in ranked_names) {
    if (length(selected_names) == feature_count) break
    candidate_is_numeric <- candidate_name %in% numeric_predictor_names
    redundant <- FALSE
    if (candidate_is_numeric) {
      selected_numeric <- intersect(selected_names, numeric_predictor_names)
      for (selected_name in selected_numeric) {
        pair_correlation <- abs(cor(training_data[[candidate_name]], training_data[[selected_name]]))
        if (!is.na(pair_correlation) && pair_correlation > correlation_limit) redundant <- TRUE
      }
    }
    if (!redundant) selected_names <- c(selected_names, candidate_name)
  }
  selected_names
}
