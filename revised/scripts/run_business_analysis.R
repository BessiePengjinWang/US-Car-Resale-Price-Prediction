source("revised/R/load_all.R")
library(ggplot2)

light_theme <- theme_minimal() + theme(plot.background = element_rect(fill = "white", colour = NA), panel.background = element_rect(fill = "white", colour = NA))

started_at <- Sys.time()
vehicle_data <- remove_placeholder_prices(remove_exact_duplicates(load_vehicle_data()))
cat(sprintf("✓ loaded %d unique rows without placeholder prices\n", nrow(vehicle_data)))
imputed_data <- apply_imputer(vehicle_data, fit_imputer(vehicle_data))

feature_sets_to_compare <- list(numeric_plus_make = feature_set_definitions()$numeric_plus_make, full_specification = pricing_feature_names)
validation_rows <- list()
out_of_fold_by_set <- list()
for (feature_set_name in names(feature_sets_to_compare)) {
  predictions <- out_of_fold_predictions(vehicle_data, "random_forest", feature_sets_to_compare[[feature_set_name]], "log")
  out_of_fold_by_set[[feature_set_name]] <- predictions
  validation_rows[[feature_set_name]] <- data.frame(
    feature_set = feature_set_name,
    R2 = r_squared(vehicle_data$MSRP, predictions),
    MAE = mean_absolute_error(vehicle_data$MSRP, predictions),
    MedianAE = median_absolute_error(vehicle_data$MSRP, predictions),
    RMSLE = root_mean_squared_log_error(vehicle_data$MSRP, predictions),
    median_abs_percent_error = 100 * median(abs(vehicle_data$MSRP / predictions - 1)),
    interval_coverage_80_percent = measure_interval_coverage(vehicle_data$MSRP, predictions)
  )
  cat(sprintf("✓ out-of-fold predictions for %s\n", feature_set_name))
}
validation_table <- do.call(rbind, validation_rows)
rownames(validation_table) <- NULL
full_predictions <- out_of_fold_by_set$full_specification
interval_table <- fit_error_intervals(vehicle_data$MSRP, full_predictions)

premium_table <- estimate_brand_premium_with_sensitivity(imputed_data)
recent_data <- imputed_data[imputed_data$Year >= 2012, ]
effects_table <- estimate_specification_effects(recent_data)

silhouette_table <- read.csv(file.path("revised", "results", "cluster_silhouette.csv"))
chosen_cluster_count <- silhouette_table$cluster_count[which.max(silhouette_table$mean_silhouette)]
vehicle_groups <- split_electric_vehicles(imputed_data)
clustering <- cluster_combustion_vehicles(vehicle_groups$combustion, chosen_cluster_count)
combustion_ids <- paste0("segment_", clustering$fit$cluster)
segment_names <- name_segments(vehicle_groups$combustion, combustion_ids)
segment_by_row <- rep(NA_character_, nrow(imputed_data))
names(segment_by_row) <- rownames(imputed_data)
segment_by_row[rownames(vehicle_groups$electric)] <- "electric"
segment_by_row[rownames(vehicle_groups$combustion)] <- unname(segment_names[combustion_ids])
relative_error <- abs(vehicle_data$MSRP / full_predictions - 1)
error_by_segment <- do.call(rbind, lapply(sort(unique(na.omit(segment_by_row))), function(segment_name) {
  in_segment <- !is.na(segment_by_row) & segment_by_row == segment_name
  data.frame(
    segment = segment_name,
    vehicle_count = sum(in_segment),
    median_list_price = median(vehicle_data$MSRP[in_segment]),
    median_abs_percent_error = 100 * median(relative_error[in_segment]),
    share_within_10_percent = mean(relative_error[in_segment] <= 0.10),
    share_within_20_percent = mean(relative_error[in_segment] <= 0.20)
  )
}))
flags <- flag_priced_versus_spec(vehicle_data, full_predictions)
flag_table <- rbind(cbind(direction = "list price above specification", flags$above_spec), cbind(direction = "list price below specification", flags$below_spec))

dir.create(file.path("revised", "results"), showWarnings = FALSE, recursive = TRUE)
dir.create(file.path("revised", "figures"), showWarnings = FALSE, recursive = TRUE)
write.csv(validation_table, file.path("revised", "results", "price_model_validation.csv"), row.names = FALSE)
write.csv(interval_table, file.path("revised", "results", "price_error_intervals.csv"), row.names = FALSE)
write.csv(premium_table, file.path("revised", "results", "brand_premium.csv"), row.names = FALSE)
write.csv(effects_table, file.path("revised", "results", "specification_price_effects.csv"), row.names = FALSE)
write.csv(error_by_segment, file.path("revised", "results", "price_error_by_segment.csv"), row.names = FALSE)
write.csv(flag_table, file.path("revised", "results", "priced_versus_specification.csv"), row.names = FALSE)

premium_plot_table <- premium_table
premium_plot_table$brand <- factor(premium_plot_table$brand, levels = premium_plot_table$brand[order(premium_plot_table$premium_percent)])
premium_plot_table$sign_label <- ifelse(premium_plot_table$sign_is_stable, "same direction in all estimates", "direction changes between estimates")
premium_plot <- ggplot(premium_plot_table, aes(premium_percent, brand, colour = sign_label)) +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_errorbar(aes(xmin = lower_percent, xmax = upper_percent), orientation = "y", width = 0.3) +
  geom_point(size = 2) +
  scale_x_continuous(trans = scales::pseudo_log_trans(base = 10), breaks = c(-10, 0, 10, 30, 100, 300)) +
  scale_colour_manual(values = c("same direction in all estimates" = "#4C78A8", "direction changes between estimates" = "#F58518"), name = NULL) +
  labs(title = "Brand price premium compared with Chevrolet, same specification (model years 2012 to 2017)",
       subtitle = "Percent difference in list price with 95 percent interval. Orange: the sign is not robust to sample choice.",
       x = "Premium over Chevrolet (percent, pseudo-logarithmic axis)", y = NULL) +
  light_theme + theme(legend.position = "bottom")
ggsave(file.path("revised", "figures", "business_brand_premium.png"), premium_plot, width = 9, height = 8, dpi = 150, bg = "white")

fit_table <- data.frame(actual = vehicle_data$MSRP, predicted = full_predictions)
fit_plot <- ggplot(fit_table, aes(predicted, actual)) +
  geom_point(alpha = 0.2, size = 0.7, colour = "#4C78A8") +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_log10(labels = function(value) format(value, big.mark = ",", scientific = FALSE)) +
  scale_y_log10(labels = function(value) format(value, big.mark = ",", scientific = FALSE)) +
  labs(title = "Out-of-fold predicted against actual list price", subtitle = "Each car is predicted by a model that never saw it. Both axes logarithmic.", x = "Predicted MSRP", y = "Actual MSRP") +
  light_theme
ggsave(file.path("revised", "figures", "business_predicted_vs_actual.png"), fit_plot, width = 7, height = 6, dpi = 150, bg = "white")
cat(sprintf("✓ wrote business analysis tables and figures in %.1f minutes\n", as.numeric(difftime(Sys.time(), started_at, units = "mins"))))
