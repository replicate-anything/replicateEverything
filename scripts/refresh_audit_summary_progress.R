#!/usr/bin/env Rscript
# Rebuild registry/audit_summary.json progress categories from audit_latest.rds
# without re-running audit_everything().

root <- commandArgs(trailingOnly = TRUE)[[1]]
if (!nzchar(root %||% "")) {
  root <- getOption("replicateEverything.registry_root", "registry")
}
root <- normalizePath(root, winslash = "/", mustWork = TRUE)

devtools::load_all(
  file.path(dirname(root), "replicateEverything"),
  quiet = TRUE
)

rds <- file.path(root, "audit_latest.rds")
if (!file.exists(rds)) {
  stop("Missing ", rds, call. = FALSE)
}

audit <- readRDS(rds)
if (is.data.frame(audit$results) && nrow(audit$results) > 0) {
  pc <- audit_progress_counts(results = audit$results)
  audit$summary$missing_engine <- as.integer(pc[["missing_engine"]] %||% 0L)
  audit$summary$progress <- as.list(pc)
}

paths <- write_registry_audit_record(audit, registry_root = root)
message("Wrote ", paths$summary)
print(jsonlite::fromJSON(paths$summary)[c(
  "success", "failed", "timed_out", "skipped",
  "substantive_failed", "missing_engine", "progress"
)])
