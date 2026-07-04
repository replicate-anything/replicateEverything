# Build the pkgdown site without re-running audit_everything().
# The audit vignette reads inst/vignette-data/audit_latest.rds unless
# REPLICATE_AUDIT_LIVE=true.
Sys.setenv(REPLICATE_AUDIT_LIVE = "false")

# pkgdown does not remove orphaned reference pages from prior builds.
ref_dir <- file.path("docs", "reference")
if (dir.exists(ref_dir)) {
  old_pages <- list.files(ref_dir, pattern = "\\.html$", full.names = TRUE)
  if (length(old_pages) > 0L) {
    unlink(old_pages)
  }
}

pkgdown::build_site(new_process = FALSE, install = TRUE)
