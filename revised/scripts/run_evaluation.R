source("revised/R/load_all.R")

command_arguments <- commandArgs(trailingOnly = TRUE)
seed_count <- if (length(command_arguments) >= 1) as.integer(command_arguments[1]) else 10
worker_count <- if (length(command_arguments) >= 2) as.integer(command_arguments[2]) else 4
output_prefix <- if (length(command_arguments) >= 3) command_arguments[3] else "main"
exclude_placeholder_prices <- length(command_arguments) >= 4 && command_arguments[4] == "exclude_placeholder_prices"

vehicle_data <- remove_exact_duplicates(load_vehicle_data())
if (exclude_placeholder_prices) vehicle_data <- remove_placeholder_prices(vehicle_data)
cat(sprintf("✓ loaded %d unique rows\n", nrow(vehicle_data)))

started_at <- Sys.time()
result_table <- evaluate_across_seeds(vehicle_data, seq_len(seed_count), worker_count)
summary_table <- summarize_across_seeds(result_table)
elapsed_minutes <- as.numeric(difftime(Sys.time(), started_at, units = "mins"))

dir.create(file.path("revised", "results"), showWarnings = FALSE, recursive = TRUE)
write.csv(result_table, file.path("revised", "results", sprintf("%s_metrics_by_seed.csv", output_prefix)), row.names = FALSE)
write.csv(summary_table, file.path("revised", "results", sprintf("%s_metrics_summary.csv", output_prefix)), row.names = FALSE)
cat(sprintf("✓ wrote results for %d seeds in %.1f minutes\n", seed_count, elapsed_minutes))
