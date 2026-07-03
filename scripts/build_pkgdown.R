# Build the pkgdown site without re-running audit_everything().
# The audit vignette reads inst/vignette-data/audit_latest.rds unless
# REPLICATE_AUDIT_LIVE=true.
Sys.setenv(REPLICATE_AUDIT_LIVE = "false")
pkgdown::build_site(new_process = FALSE, install = TRUE)
