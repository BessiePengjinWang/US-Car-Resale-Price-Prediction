root_mean_squared_error <- function(actual, predicted) sqrt(mean((actual - predicted)^2))

mean_absolute_error <- function(actual, predicted) mean(abs(actual - predicted))

median_absolute_error <- function(actual, predicted) median(abs(actual - predicted))

r_squared <- function(actual, predicted) {
  1 - sum((actual - predicted)^2) / sum((actual - mean(actual))^2)
}

root_mean_squared_log_error <- function(actual, predicted, price_floor = 1) {
  sqrt(mean((log(pmax(predicted, price_floor)) - log(actual))^2))
}

evaluate_predictions <- function(actual, predicted) {
  c(
    RMSE = root_mean_squared_error(actual, predicted),
    MAE = mean_absolute_error(actual, predicted),
    MedianAE = median_absolute_error(actual, predicted),
    R2 = r_squared(actual, predicted),
    RMSLE = root_mean_squared_log_error(actual, predicted)
  )
}

baseline_predictions <- function(training_prices, test_row_count) {
  list(
    mean_baseline = rep(mean(training_prices), test_row_count),
    median_baseline = rep(median(training_prices), test_row_count)
  )
}
