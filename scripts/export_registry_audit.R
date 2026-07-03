pkg_root <- normalizePath(file.path(dirname(sub("--file=", "", commandArgs(trailingOnly = FALSE)[grep("--file=", commandArgs(trailingOnly = FALSE))])), ".."))
mono <- normalizePath(file.path(pkg_root, ".."))
audit <- readRDS(file.path(pkg_root, "inst", "vignette-data", "audit_latest.rds"))
sm <- audit$summary
payload <- list(
  patience = audit$patience,
  started_at = format(audit$started_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  finished_at = format(audit$finished_at, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  studies = sm$studies,
  runs = sm$runs,
  success = sm$success,
  failed = sm$failed,
  timed_out = sm$timed_out
)
registry <- file.path(mono, "registry")
jsonlite::write_json(
  payload,
  file.path(registry, "audit_summary.json"),
  pretty = TRUE,
  auto_unbox = TRUE
)
saveRDS(audit, file.path(registry, "audit_latest.rds"))
message("Wrote registry audit_summary.json and audit_latest.rds")
