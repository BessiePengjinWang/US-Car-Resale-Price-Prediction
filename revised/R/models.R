supported_model_names <- c("linear", "polynomial", "ridge", "lasso", "random_forest", "gradient_boosting")

polynomial_term_names <- function(feature_names) {
  intersect(feature_names, c("Year", "Engine.HP", "Engine.Cylinders", "highway.MPG", "city.mpg", "Popularity"))
}

build_formula <- function(feature_names, use_polynomial) {
  polynomial_names <- if (use_polynomial) polynomial_term_names(feature_names) else character(0)
  plain_names <- setdiff(feature_names, polynomial_names)
  polynomial_terms <- if (length(polynomial_names) > 0) sprintf("poly(%s, 2)", polynomial_names) else character(0)
  plain_terms <- if (length(plain_names) > 0) sprintf("`%s`", plain_names) else character(0)
  as.formula(paste("target_value ~", paste(c(plain_terms, polynomial_terms), collapse = " + ")))
}

transform_target <- function(prices, target_scale) {
  if (target_scale == "log") log(prices) else prices
}

restore_target <- function(values, target_scale) {
  if (target_scale == "log") exp(values) else values
}

fit_vehicle_model <- function(model_name, training_data, feature_names, factor_levels, seed, target_scale = "dollars") {
  stopifnot(model_name %in% supported_model_names)
  assert_no_target_leakage(feature_names)
  feature_frame <- prepare_feature_frame(training_data, feature_names, factor_levels)
  target_value <- transform_target(training_data[[target_column]], target_scale)
  set.seed(seed)
  fitted <- list(model_name = model_name, feature_names = feature_names, factor_levels = factor_levels, target_scale = target_scale)

  if (model_name %in% c("linear", "polynomial")) {
    training_frame <- cbind(feature_frame, target_value = target_value)
    fitted$model <- lm(build_formula(feature_names, model_name == "polynomial"), data = training_frame)
  } else if (model_name %in% c("ridge", "lasso")) {
    alpha_value <- if (model_name == "ridge") 0 else 1
    design_matrix <- build_design_matrix(feature_frame)
    fitted$design_columns <- colnames(design_matrix)
    fitted$model <- glmnet::cv.glmnet(design_matrix, target_value, alpha = alpha_value, standardize = TRUE)
  } else if (model_name == "random_forest") {
    fitted$model <- randomForest::randomForest(x = feature_frame, y = target_value, ntree = 500)
  } else {
    training_frame <- cbind(feature_frame, target_value = target_value)
    utils::capture.output(boosted <- gbm::gbm(
      target_value ~ ., data = training_frame, distribution = "gaussian", n.trees = 500,
      interaction.depth = 3, shrinkage = 0.1, cv.folds = 5, n.cores = 1, verbose = FALSE
    ))
    fitted$model <- boosted
    fitted$best_tree_count <- gbm::gbm.perf(boosted, method = "cv", plot.it = FALSE)
  }
  fitted
}

predict_vehicle_model <- function(fitted, new_data) {
  feature_frame <- prepare_feature_frame(new_data, fitted$feature_names, fitted$factor_levels)
  raw_prediction <- switch(
    fitted$model_name,
    linear = predict(fitted$model, newdata = feature_frame),
    polynomial = predict(fitted$model, newdata = feature_frame),
    ridge = as.vector(predict(fitted$model, newx = build_design_matrix(feature_frame), s = "lambda.min")),
    lasso = as.vector(predict(fitted$model, newx = build_design_matrix(feature_frame), s = "lambda.min")),
    random_forest = predict(fitted$model, newdata = feature_frame),
    gradient_boosting = predict(fitted$model, newdata = feature_frame, n.trees = fitted$best_tree_count)
  )
  restore_target(as.numeric(raw_prediction), fitted$target_scale)
}
