# Refresh inst/vignette-data/audit_latest.rds for the audit vignette / pkgdown.
# Requires a local monorepo checkout (registry + study repos).
#
# Usage (from package root):
#   REPLICATE_MONOREPO=/path/to/replicate_everything Rscript scripts/refresh_audit_snapshot.R

find_pkg_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) {
    return(normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), "..")))
  }
  if (file.exists("DESCRIPTION")) {
    return(normalizePath("."))
  }
  stop("Run via Rscript scripts/refresh_audit_snapshot.R from the package root.")
}

monorepo <- Sys.getenv("REPLICATE_MONOREPO", unset = "")
if (!nzchar(monorepo)) {
  stop(
    "Set REPLICATE_MONOREPO to your replicate_everything monorepo root, ",
    "then re-run this script."
  )
}

pkg_root <- find_pkg_root()
devtools::load_all(pkg_root, quiet = TRUE)
configure_local_monorepo(monorepo)
audit <- audit_everything(patience = 20, verbose = TRUE)
out <- file.path(pkg_root, "inst", "vignette-data", "audit_latest.rds")
saveRDS(audit, out)
message("Wrote ", out)
