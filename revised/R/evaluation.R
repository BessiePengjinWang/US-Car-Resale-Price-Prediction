prepare_split_data <- function(vehicle_data, seed) {
  split <- make_train_test_split(nrow(vehicle_data), seed)
  imputer <- fit_imputer(vehicle_data[split$train_index, ])
  imputed_data <- apply_imputer(vehicle_data, imputer)
  list(
    train = imputed_data[split$train_index, ],
    test = imputed_data[split$test_index, ],
    factor_levels = collect_factor_levels(imputed_data)
  )
}

evaluate_one_seed <- function(vehicle_data, seed, target_scales = c("dollars", "log"), progress = FALSE) {
  prepared <- prepare_split_data(vehicle_data, seed)
  ranked_names <- rank_features_on_training_data(prepared$train, seed)
  selected_names <- select_top_features(ranked_names, prepared$train)
  feature_sets <- feature_set_definitions(selected_names)
  actual_prices <- prepared$test[[target_column]]
  result_rows <- list()

  baselines <- baseline_predictions(prepared$train[[target_column]], nrow(prepared$test))
  for (baseline_name in names(baselines)) {
    metrics <- evaluate_predictions(actual_prices, baselines[[baseline_name]])
    result_rows[[length(result_rows) + 1]] <- data.frame(
      seed = seed, model = baseline_name, feature_set = "none", target_scale = "dollars", t(metrics)
    )
  }

  for (feature_set_name in names(feature_sets)) {
    for (target_scale in target_scales) {
      for (model_name in supported_model_names) {
        fitted <- fit_vehicle_model(model_name, prepared$train, feature_sets[[feature_set_name]], prepared$factor_levels, seed, target_scale)
        metrics <- evaluate_predictions(actual_prices, predict_vehicle_model(fitted, prepared$test))
        result_rows[[length(result_rows) + 1]] <- data.frame(
          seed = seed, model = model_name, feature_set = feature_set_name, target_scale = target_scale, t(metrics)
        )
        if (progress) cat(sprintf("✓ seed %d %s %s %s\n", seed, feature_set_name, target_scale, model_name))
      }
    }
  }
  result_table <- do.call(rbind, result_rows)
  result_table$selected_features <- paste(selected_names, collapse = ";")
  result_table
}

evaluate_across_seeds <- function(vehicle_data, seeds, worker_count = 1, target_scales = c("dollars", "log")) {
  per_seed_tables <- parallel::mclapply(
    seeds, function(seed) evaluate_one_seed(vehicle_data, seed, target_scales),
    mc.cores = worker_count, mc.set.seed = FALSE
  )
  failed <- vapply(per_seed_tables, inherits, logical(1), what = "try-error")
  if (any(failed)) stop("Evaluation failed for seeds: ", paste(seeds[failed], collapse = ", "))
  do.call(rbind, per_seed_tables)
}

summarize_across_seeds <- function(result_table) {
  group_keys <- c("model", "feature_set", "target_scale")
  metric_names <- c("RMSE", "MAE", "MedianAE", "R2", "RMSLE")
  groups <- split(result_table, result_table[group_keys], drop = TRUE)
  summary_rows <- lapply(groups, function(group_table) {
    row <- group_table[1, group_keys]
    row$seed_count <- nrow(group_table)
    for (metric_name in metric_names) {
      row[[paste0(metric_name, "_mean")]] <- mean(group_table[[metric_name]])
      row[[paste0(metric_name, "_sd")]] <- sd(group_table[[metric_name]])
    }
    row
  })
  summary_table <- do.call(rbind, summary_rows)
  rownames(summary_table) <- NULL
  summary_table[order(-summary_table$R2_mean), ]
}
