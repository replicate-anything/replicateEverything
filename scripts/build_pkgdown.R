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

# Dropbox (and similar sync) on Windows can lock docs/articles/*.html while
# pkgdown overwrites them, causing:
#   Warning: Invalid argument [1515]
#   Error: Error closing file
# Best fix: exclude docs/ from selective sync, or clone/build outside Dropbox.
# Workaround below removes cached article HTML before the build starts.
if (grepl("dropbox", normalizePath(getwd(), winslash = "/"), ignore.case = TRUE)) {
  message(
    "Note: building inside Dropbox can fail with 'Error closing file'. ",
    "Pause sync, exclude docs/ from selective sync, or build outside Dropbox."
  )
  articles_dir <- file.path("docs", "articles")
  if (dir.exists(articles_dir)) {
    html <- list.files(articles_dir, pattern = "\\.html$", full.names = TRUE)
    if (length(html)) {
      message("Removing ", length(html), " cached article HTML file(s) before rebuild.")
      unlink(html, force = TRUE)
    }
  }
}

if (requireNamespace("devtools", quietly = TRUE)) {
  devtools::document(quiet = TRUE)
}

# install = TRUE avoids "no package.rds" / missing S3 method warnings from
# loadNamespace() on a half-installed package.
pkgdown::build_site_github_pages(
  new_process = FALSE,
  install = TRUE,
  clean = TRUE
)

message("Site written to docs/. Commit the whole docs/ directory and push to main.")
