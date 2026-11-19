library(ggplot2)

light_theme <- theme_minimal() + theme(
  plot.background = element_rect(fill = "white", colour = NA),
  panel.background = element_rect(fill = "white", colour = NA),
  legend.position = "bottom"
)

feature_set_colours <- c(numeric_only = "#4C78A8", numeric_plus_make = "#F58518", selected_top5 = "#54A24B")
model_order <- c("linear", "polynomial", "ridge", "lasso", "random_forest", "gradient_boosting")

summary_table <- read.csv(file.path("revised", "results", "main_metrics_summary.csv"))
by_seed_table <- read.csv(file.path("revised", "results", "main_metrics_by_seed.csv"))

baseline_table <- summary_table[summary_table$feature_set == "none", ]
model_table <- summary_table[summary_table$feature_set != "none", ]
model_table$model <- factor(model_table$model, levels = model_order)
unstable_row <- model_table$model == "polynomial" & model_table$feature_set == "numeric_only" & model_table$target_scale == "log"
model_table <- model_table[!unstable_row, ]
model_table$target_scale <- factor(model_table$target_scale, levels = c("dollars", "log"), labels = c("Price predicted directly", "Log price predicted"))

mean_baseline <- baseline_table[baseline_table$model == "mean_baseline", ]

r_squared_plot <- ggplot(model_table, aes(model, R2_mean, fill = feature_set)) +
  geom_col(position = position_dodge(width = 0.85), width = 0.8) +
  geom_errorbar(aes(ymin = R2_mean - R2_sd, ymax = pmin(R2_mean + R2_sd, 1)), position = position_dodge(width = 0.85), width = 0.25) +
  geom_hline(yintercept = mean_baseline$R2_mean, linetype = "dashed") +
  facet_wrap(~ target_scale, ncol = 1) +
  scale_fill_manual(values = feature_set_colours, name = "Feature set") +
  coord_cartesian(ylim = c(0, 1)) +
  labs(title = "R-squared on unseen cars (mean and standard deviation over seeds 1 to 10)",
       subtitle = "Dashed line: always predicting the training mean. Polynomial numeric_only with log target omitted (unstable).",
       x = NULL, y = "R-squared") +
  light_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path("revised", "figures", "metrics_r_squared.png"), r_squared_plot, width = 9, height = 8, dpi = 150, bg = "white")

mae_plot <- ggplot(model_table, aes(model, MAE_mean, fill = feature_set)) +
  geom_col(position = position_dodge(width = 0.85), width = 0.8) +
  geom_errorbar(aes(ymin = pmax(MAE_mean - MAE_sd, 0), ymax = MAE_mean + MAE_sd), position = position_dodge(width = 0.85), width = 0.25) +
  geom_hline(yintercept = mean_baseline$MAE_mean, linetype = "dashed") +
  facet_wrap(~ target_scale, ncol = 1) +
  scale_fill_manual(values = feature_set_colours, name = "Feature set") +
  scale_y_continuous(labels = function(value) format(value, big.mark = ",")) +
  labs(title = "Mean absolute error in dollars (mean and standard deviation over seeds 1 to 10)",
       subtitle = "Dashed line: always predicting the training mean. Lower is better.",
       x = NULL, y = "MAE (US dollars)") +
  light_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path("revised", "figures", "metrics_mae.png"), mae_plot, width = 9, height = 8, dpi = 150, bg = "white")

seed_table <- by_seed_table[by_seed_table$target_scale == "dollars" & by_seed_table$feature_set == "numeric_plus_make", ]
seed_table$model <- factor(seed_table$model, levels = model_order)
seed_plot <- ggplot(seed_table, aes(model, R2)) +
  geom_boxplot(outlier.shape = NA, fill = "#DDDDDD") +
  geom_point(position = position_jitter(width = 0.12, height = 0, seed = 1), size = 1.6, colour = "#F58518") +
  labs(title = "R-squared for each of the 10 splits (numeric_plus_make, price predicted directly)",
       subtitle = "Each dot is one seed. The spread shows how much a single split can mislead.",
       x = NULL, y = "R-squared") +
  light_theme + theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave(file.path("revised", "figures", "metrics_r_squared_by_seed.png"), seed_plot, width = 9, height = 5, dpi = 150, bg = "white")
cat("✓ wrote metric comparison figures\n")
