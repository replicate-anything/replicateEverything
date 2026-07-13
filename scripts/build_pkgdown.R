# Build the pkgdown site for GitHub Pages (docs/ on main).
#
# The live site is NOT built in CI. After editing vignettes, roxygen, or _pkgdown.yml:
#   Rscript scripts/build_pkgdown.R
#   git add docs/
#   git commit -m "Rebuild pkgdown site"
#   git push
#
# Requires a full docs/ tree (deps/, articles/, reference/, …). Pushing only index.html
# without deps/ will break styling on GitHub Pages.
#
# The audit vignette reads inst/vignette-data/audit_latest.rds unless
# REPLICATE_AUDIT_LIVE=true.
Sys.setenv(REPLICATE_AUDIT_LIVE = "false")

pkgdown::build_site_github_pages(
  new_process = FALSE,
  install = TRUE,
  clean = TRUE
)

message("Site written to docs/. Commit the whole docs/ directory and push to main.")
