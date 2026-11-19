module_files <- c("data.R", "split.R", "features.R", "metrics.R", "models.R", "evaluation.R", "clustering.R", "recommend.R", "predict_price.R", "pricing.R")
module_directory <- file.path("revised", "R")
for (module_file in module_files) {
  module_path <- file.path(module_directory, module_file)
  if (file.exists(module_path)) source(module_path)
}
