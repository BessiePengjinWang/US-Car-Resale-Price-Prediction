expected_columns <- c(
  "Make", "Model", "Year", "Engine.Fuel.Type", "Engine.HP", "Engine.Cylinders",
  "Transmission.Type", "Driven_Wheels", "Number.of.Doors", "Market.Category",
  "Vehicle.Size", "Vehicle.Style", "highway.MPG", "city.mpg", "Popularity", "MSRP"
)

resolve_data_path <- function() {
  environment_path <- Sys.getenv("VEHICLE_DATA_PATH", unset = "")
  if (nzchar(environment_path)) return(environment_path)
  file.path("revised", "data", "data.csv")
}

load_vehicle_data <- function(data_path = resolve_data_path()) {
  if (!file.exists(data_path)) {
    stop(sprintf(
      "Data file not found at '%s'. Download data.csv from https://www.kaggle.com/datasets/CooperUnion/cardataset and place it there, or set VEHICLE_DATA_PATH.",
      data_path
    ))
  }
  vehicle_data <- read.csv(data_path, stringsAsFactors = FALSE, check.names = TRUE)
  missing_columns <- setdiff(expected_columns, names(vehicle_data))
  if (length(missing_columns) > 0) {
    stop(sprintf("Data file is missing columns: %s", paste(missing_columns, collapse = ", ")))
  }
  vehicle_data[, expected_columns]
}

statistical_mode <- function(values) {
  value_counts <- table(values[!is.na(values)])
  as.numeric(names(value_counts)[which.max(value_counts)])
}

fit_imputer <- function(training_data) {
  list(
    median_horsepower = median(training_data$Engine.HP, na.rm = TRUE),
    median_cylinders = median(training_data$Engine.Cylinders, na.rm = TRUE),
    mode_doors = statistical_mode(training_data$Number.of.Doors)
  )
}

apply_imputer <- function(vehicle_data, imputer) {
  vehicle_data$Engine.HP[is.na(vehicle_data$Engine.HP)] <- imputer$median_horsepower
  vehicle_data$Engine.Cylinders[is.na(vehicle_data$Engine.Cylinders)] <- imputer$median_cylinders
  vehicle_data$Number.of.Doors[is.na(vehicle_data$Number.of.Doors)] <- imputer$mode_doors
  vehicle_data$Engine.Fuel.Type[vehicle_data$Engine.Fuel.Type == ""] <- "unknown"
  vehicle_data
}
