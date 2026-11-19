out_of_fold_predictions <- function(vehicle_data, model_name, feature_names, target_scale = "log", fold_count = 5, seed = 1) {
  set.seed(seed)
  fold_ids <- sample(rep(seq_len(fold_count), length.out = nrow(vehicle_data)))
  predictions <- numeric(nrow(vehicle_data))
  for (fold in seq_len(fold_count)) {
    training_rows <- fold_ids != fold
    imputed_data <- apply_imputer(vehicle_data, fit_imputer(vehicle_data[training_rows, ]))
    factor_levels <- collect_factor_levels(imputed_data[training_rows, ])
    fitted <- fit_vehicle_model(model_name, imputed_data[training_rows, ], feature_names, factor_levels, seed + fold, target_scale)
    predictions[!training_rows] <- predict_vehicle_model(fitted, imputed_data[!training_rows, ])
  }
  predictions
}

default_price_band_breaks <- c(0, 20000, 40000, Inf)

assign_price_band <- function(predicted_prices, band_breaks = default_price_band_breaks) {
  cut(predicted_prices, breaks = band_breaks, include.lowest = TRUE, dig.lab = 6)
}

fit_error_intervals <- function(actual_prices, predicted_prices, band_breaks = default_price_band_breaks, lower_probability = 0.1, upper_probability = 0.9) {
  log_ratio <- log(actual_prices / predicted_prices)
  bands <- assign_price_band(predicted_prices, band_breaks)
  interval_table <- do.call(rbind, lapply(levels(bands), function(band_name) {
    band_ratio <- log_ratio[bands == band_name]
    data.frame(
      price_band = band_name,
      vehicle_count = length(band_ratio),
      lower_ratio = exp(unname(quantile(band_ratio, lower_probability))),
      upper_ratio = exp(unname(quantile(band_ratio, upper_probability))),
      median_abs_percent_error = 100 * median(abs(exp(band_ratio) - 1))
    )
  }))
  attr(interval_table, "band_breaks") <- band_breaks
  interval_table
}

apply_error_intervals <- function(predicted_prices, interval_table) {
  bands <- assign_price_band(predicted_prices, attr(interval_table, "band_breaks"))
  matched <- interval_table[match(as.character(bands), interval_table$price_band), ]
  data.frame(
    predicted_price = predicted_prices,
    lower_price = predicted_prices * matched$lower_ratio,
    upper_price = predicted_prices * matched$upper_ratio
  )
}

measure_interval_coverage <- function(actual_prices, predicted_prices, seed = 1, band_breaks = default_price_band_breaks) {
  set.seed(seed)
  fit_rows <- sample(length(actual_prices), floor(length(actual_prices) / 2))
  interval_table <- fit_error_intervals(actual_prices[fit_rows], predicted_prices[fit_rows], band_breaks)
  held_out <- setdiff(seq_along(actual_prices), fit_rows)
  intervals <- apply_error_intervals(predicted_prices[held_out], interval_table)
  mean(actual_prices[held_out] >= intervals$lower_price & actual_prices[held_out] <= intervals$upper_price)
}

fit_log_price_regression <- function(vehicle_data, reference_brand = "Chevrolet", minimum_vehicle_count = 20) {
  brand_counts <- table(vehicle_data$Make)
  kept_brands <- names(brand_counts)[brand_counts >= minimum_vehicle_count]
  analysis_data <- vehicle_data[vehicle_data$Make %in% kept_brands, ]
  analysis_data$Make <- relevel(factor(analysis_data$Make), ref = reference_brand)
  analysis_data$log_price <- log(analysis_data$MSRP)
  analysis_data$log_horsepower <- log(analysis_data$Engine.HP)
  model <- lm(
    log_price ~ Make + Year + log_horsepower + Engine.Cylinders + Number.of.Doors + highway.MPG + city.mpg +
      Vehicle.Size + Vehicle.Style + Engine.Fuel.Type + Transmission.Type + Driven_Wheels,
    data = analysis_data
  )
  list(model = model, brand_counts = brand_counts)
}

estimate_brand_premium <- function(vehicle_data, reference_brand = "Chevrolet", minimum_vehicle_count = 20) {
  regression <- fit_log_price_regression(vehicle_data, reference_brand, minimum_vehicle_count)
  coefficients_table <- summary(regression$model)$coefficients
  brand_rows <- grep("^Make", rownames(coefficients_table))
  estimates <- coefficients_table[brand_rows, "Estimate"]
  standard_errors <- coefficients_table[brand_rows, "Std. Error"]
  brand_names <- sub("^Make", "", rownames(coefficients_table)[brand_rows])
  premium_table <- data.frame(
    brand = brand_names,
    vehicle_count = as.integer(regression$brand_counts[brand_names]),
    premium_percent = 100 * (exp(estimates) - 1),
    lower_percent = 100 * (exp(estimates - 1.96 * standard_errors) - 1),
    upper_percent = 100 * (exp(estimates + 1.96 * standard_errors) - 1)
  )
  premium_table <- premium_table[order(-premium_table$premium_percent), ]
  rownames(premium_table) <- NULL
  attr(premium_table, "reference_brand") <- reference_brand
  attr(premium_table, "adjusted_r_squared_log_price") <- summary(regression$model)$adj.r.squared
  premium_table
}

estimate_specification_effects <- function(vehicle_data, reference_brand = "Chevrolet", minimum_vehicle_count = 20) {
  regression <- fit_log_price_regression(vehicle_data, reference_brand, minimum_vehicle_count)
  coefficients_table <- summary(regression$model)$coefficients
  effect_definitions <- data.frame(
    term = c("log_horsepower", "Year", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg"),
    description = c("10 percent more horsepower", "one model year later", "one more cylinder", "one more door", "one more highway MPG", "one more city MPG"),
    multiplier = c(log(1.1), 1, 1, 1, 1, 1)
  )
  rows <- lapply(seq_len(nrow(effect_definitions)), function(row_index) {
    term_name <- effect_definitions$term[row_index]
    multiplier <- effect_definitions$multiplier[row_index]
    estimate <- coefficients_table[term_name, "Estimate"] * multiplier
    margin <- 1.96 * coefficients_table[term_name, "Std. Error"] * multiplier
    data.frame(
      change = effect_definitions$description[row_index],
      price_change_percent = 100 * (exp(estimate) - 1),
      lower_percent = 100 * (exp(estimate - margin) - 1),
      upper_percent = 100 * (exp(estimate + margin) - 1)
    )
  })
  do.call(rbind, rows)
}

estimate_brand_premium_with_sensitivity <- function(vehicle_data, main_minimum_year = 2012, reference_brand = "Chevrolet", minimum_vehicle_count = 20) {
  main_table <- estimate_brand_premium(vehicle_data[vehicle_data$Year >= main_minimum_year, ], reference_brand, minimum_vehicle_count)
  all_years_table <- estimate_brand_premium(vehicle_data, reference_brand, minimum_vehicle_count)
  moderate_power_table <- estimate_brand_premium(vehicle_data[vehicle_data$Engine.HP <= 400, ], reference_brand, minimum_vehicle_count)
  main_table$premium_all_years_percent <- all_years_table$premium_percent[match(main_table$brand, all_years_table$brand)]
  main_table$premium_up_to_400_hp_percent <- moderate_power_table$premium_percent[match(main_table$brand, moderate_power_table$brand)]
  estimates_matrix <- as.matrix(main_table[, c("premium_percent", "premium_all_years_percent", "premium_up_to_400_hp_percent")])
  main_table$sign_is_stable <- apply(estimates_matrix, 1, function(values) {
    available_values <- values[!is.na(values)]
    length(available_values) >= 2 && (all(available_values > 0) || all(available_values < 0))
  })
  attr(main_table, "reference_brand") <- reference_brand
  main_table
}

flag_priced_versus_spec <- function(vehicle_data, predicted_prices, minimum_year = 2014, flag_count = 10) {
  review_data <- vehicle_data[, c("Make", "Model", "Year", "Engine.HP", "Engine.Cylinders", "Vehicle.Style", "MSRP")]
  review_data$predicted_price <- predicted_prices
  review_data$list_to_predicted_ratio <- review_data$MSRP / predicted_prices
  has_original_values <- complete.cases(vehicle_data[, c("Engine.HP", "Engine.Cylinders", "Number.of.Doors")])
  review_data <- review_data[vehicle_data$Year >= minimum_year & has_original_values, ]
  review_data <- review_data[order(review_data$list_to_predicted_ratio), ]
  rownames(review_data) <- NULL
  list(below_spec = head(review_data, flag_count), above_spec = tail(review_data, flag_count)[flag_count:1, ])
}

pricing_feature_names <- c(numeric_predictor_names, categorical_predictor_names)

specification_field_names <- c(
  "Make", "Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg",
  "Vehicle.Size", "Vehicle.Style", "Engine.Fuel.Type", "Transmission.Type", "Driven_Wheels"
)

build_listing_price_checker <- function(vehicle_data, seed = 1) {
  imputed_data <- apply_imputer(vehicle_data, fit_imputer(vehicle_data))
  factor_levels <- collect_factor_levels(imputed_data)
  out_of_fold <- out_of_fold_predictions(vehicle_data, "random_forest", pricing_feature_names, "log", seed = seed)
  list(
    model = fit_vehicle_model("random_forest", imputed_data, pricing_feature_names, factor_levels, seed, "log"),
    interval_table = fit_error_intervals(vehicle_data$MSRP, out_of_fold),
    out_of_fold_predictions = out_of_fold,
    reference_data = imputed_data,
    brand_popularity = tapply(imputed_data$Popularity, imputed_data$Make, median),
    value_ranges = lapply(imputed_data[, c("Year", "Engine.HP", "Engine.Cylinders", "highway.MPG", "city.mpg")], range),
    allowed_values = lapply(imputed_data[, c("Make", "Vehicle.Size", "Vehicle.Style", "Engine.Fuel.Type", "Transmission.Type", "Driven_Wheels")], function(values) sort(unique(values)))
  )
}

validate_specification <- function(checker, specification) {
  missing_fields <- setdiff(specification_field_names, names(specification))
  if (length(missing_fields) > 0) stop("Missing specification fields: ", paste(missing_fields, collapse = ", "))
  for (field_name in names(checker$allowed_values)) {
    if (!(specification[[field_name]] %in% checker$allowed_values[[field_name]])) {
      stop(sprintf("%s = '%s' is not a known value. Known values: %s", field_name, specification[[field_name]], paste(checker$allowed_values[[field_name]], collapse = ", ")))
    }
  }
  for (field_name in names(checker$value_ranges)) {
    allowed_range <- checker$value_ranges[[field_name]]
    if (specification[[field_name]] < allowed_range[1] || specification[[field_name]] > allowed_range[2]) {
      stop(sprintf("%s = %s is outside the training range [%s, %s].", field_name, specification[[field_name]], allowed_range[1], allowed_range[2]))
    }
  }
  invisible(TRUE)
}

check_listing_price <- function(checker, specification, listed_price = NULL, comparable_count = 5) {
  validate_specification(checker, specification)
  new_vehicle <- as.data.frame(specification[specification_field_names], stringsAsFactors = FALSE)
  new_vehicle$Popularity <- unname(checker$brand_popularity[new_vehicle$Make])
  predicted_price <- predict_vehicle_model(checker$model, new_vehicle)
  interval <- apply_error_intervals(predicted_price, checker$interval_table)
  verdict <- NA_character_
  if (!is.null(listed_price)) {
    verdict <- if (listed_price < interval$lower_price) "below the typical range for this specification"
    else if (listed_price > interval$upper_price) "above the typical range for this specification"
    else "within the typical range for this specification"
  }
  comparison_data <- checker$reference_data[checker$reference_data$Make != specification$Make & checker$reference_data$MSRP != 2000, ]
  comparable_vehicles <- recommend_vehicles(
    specification[c("Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg")],
    comparison_data, brand_count = comparable_count
  )
  list(estimate = interval, verdict = verdict, comparable_vehicles_from_other_brands = comparable_vehicles)
}
