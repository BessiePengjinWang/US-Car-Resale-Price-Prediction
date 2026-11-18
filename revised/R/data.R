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
