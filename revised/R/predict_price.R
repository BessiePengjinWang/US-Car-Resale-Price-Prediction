price_tool_inputs <- c("Make", "Year", "Engine.HP", "Engine.Cylinders", "Number.of.Doors", "highway.MPG", "city.mpg")

train_price_tools <- function(vehicle_data, seed = 1) {
  imputer <- fit_imputer(vehicle_data)
  prepared_data <- apply_imputer(vehicle_data, imputer)
  factor_levels <- collect_factor_levels(prepared_data)
  feature_names <- feature_set_definitions()$numeric_plus_make
  brand_popularity <- tapply(prepared_data$Popularity, prepared_data$Make, median)
  list(
    lasso = fit_vehicle_model("lasso", prepared_data, feature_names, factor_levels, seed),
    gradient_boosting = fit_vehicle_model("gradient_boosting", prepared_data, feature_names, factor_levels, seed),
    brand_popularity = brand_popularity,
    value_ranges = lapply(prepared_data[, c("Year", "Engine.HP", "Engine.Cylinders", "highway.MPG", "city.mpg")], range)
  )
}

predict_price_range <- function(price_tools, make, year, engine_hp, engine_cylinders, number_of_doors, highway_mpg, city_mpg) {
  if (!(make %in% names(price_tools$brand_popularity))) {
    stop("Unknown make '", make, "'. Known makes: ", paste(names(price_tools$brand_popularity), collapse = ", "))
  }
  new_vehicle <- data.frame(
    Make = make, Year = year, Engine.HP = engine_hp, Engine.Cylinders = engine_cylinders,
    Number.of.Doors = number_of_doors, highway.MPG = highway_mpg, city.mpg = city_mpg,
    Popularity = unname(price_tools$brand_popularity[make]), stringsAsFactors = FALSE
  )
  supplied <- c(Year = year, Engine.HP = engine_hp, Engine.Cylinders = engine_cylinders, highway.MPG = highway_mpg, city.mpg = city_mpg)
  for (input_name in names(supplied)) {
    allowed_range <- price_tools$value_ranges[[input_name]]
    if (supplied[[input_name]] < allowed_range[1] || supplied[[input_name]] > allowed_range[2]) {
      stop(sprintf("%s = %s is outside the training range [%s, %s].", input_name, supplied[[input_name]], allowed_range[1], allowed_range[2]))
    }
  }
  lasso_price <- predict_vehicle_model(price_tools$lasso, new_vehicle)
  boosting_price <- predict_vehicle_model(price_tools$gradient_boosting, new_vehicle)
  data.frame(
    lasso_price = lasso_price, gradient_boosting_price = boosting_price,
    lower = min(lasso_price, boosting_price), upper = max(lasso_price, boosting_price)
  )
}
