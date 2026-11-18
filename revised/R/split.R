make_train_test_split <- function(row_count, seed, train_fraction = 0.8) {
  set.seed(seed)
  train_index <- sort(sample(seq_len(row_count), size = floor(train_fraction * row_count)))
  list(train_index = train_index, test_index = setdiff(seq_len(row_count), train_index))
}

count_test_rows_duplicated_in_train <- function(vehicle_data, split) {
  row_keys <- do.call(paste, c(vehicle_data, sep = "|"))
  sum(row_keys[split$test_index] %in% row_keys[split$train_index])
}
