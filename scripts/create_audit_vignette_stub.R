# Minimal audit snapshot for vignette/pkgdown builds (no live registry run).
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
pkg_root <- normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
out_dir <- file.path(pkg_root, "inst", "vignette-data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

results <- data.frame(
  title = "Example study",
  doi = "10.1177/00491241211036161",
  object = "fig_1",
  object_label = "Figure 1",
  type = "figure",
  engine = "r",
  success = TRUE,
  seconds = 1.2,
  timed_out = FALSE,
  error_snippet = "",
  stringsAsFactors = FALSE
)

audit <- structure(
  list(
    patience = 20,
    started_at = as.POSIXct("2026-07-01 12:00:00", tz = "UTC"),
    finished_at = as.POSIXct("2026-07-01 12:05:00", tz = "UTC"),
    results = results,
    summary = list(
      studies = 1L,
      runs = 1L,
      success = 1L,
      failed = 0L,
      timed_out = 0L
    )
  ),
  class = "audit_everything"
)

saveRDS(audit, file.path(out_dir, "audit_latest.rds"))
message("Wrote ", file.path(out_dir, "audit_latest.rds"))
