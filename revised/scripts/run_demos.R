source("revised/R/load_all.R")

vehicle_data <- remove_exact_duplicates(load_vehicle_data())
imputed_data <- apply_imputer(vehicle_data, fit_imputer(vehicle_data))

preferences <- list(Year = 2015, Engine.HP = 250, Engine.Cylinders = 6, Number.of.Doors = 4, highway.MPG = 28, city.mpg = 20, MSRP = 40000)
cat("Recommended vehicles (nearest vehicle for three different brands):\n")
print(recommend_vehicles(preferences, imputed_data))

price_tools <- train_price_tools(vehicle_data)
cat("\nPrice range estimate for a 2013 Volvo, 300 HP, 4 cylinders, 4 doors, 30 highway MPG, 20 city MPG:\n")
print(predict_price_range(price_tools, "Volvo", 2013, 300, 4, 4, 30, 20))
