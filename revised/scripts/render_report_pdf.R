if (!requireNamespace("pagedown", quietly = TRUE)) stop("Install pagedown first: install.packages(\"pagedown\")")

Sys.setenv(REPORT_HIDE_CODE = "true")
report_source <- file.path("revised", "Project-code-revised.Rmd")
intermediate_directory <- tempfile("report_pdf_")
dir.create(intermediate_directory)

html_path <- rmarkdown::render(
  report_source,
  output_format = rmarkdown::html_document(
    toc = TRUE, toc_float = FALSE, theme = "default", code_folding = "none",
    md_extensions = "-tex_math_dollars", css = normalizePath(file.path("revised", "report_print.css"))
  ),
  output_dir = intermediate_directory,
  quiet = TRUE
)
pdf_path <- pagedown::chrome_print(html_path, output = file.path("revised", "Project-code-revised.pdf"), verbose = 0)
cat(sprintf("✓ wrote %s\n", pdf_path))
