# Copy pre-built vignette HTML into inst/doc/ for installs that skip vignette builds.
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
pkg_root <- normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
vign_dir <- file.path(pkg_root, "vignettes")
out_dir <- file.path(pkg_root, "inst", "doc")

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
html <- list.files(vign_dir, pattern = "\\.html$", full.names = TRUE)
if (!length(html)) {
  stop("No vignette HTML in vignettes/; run tools::buildVignettes() first.", call. = FALSE)
}
copied <- file.copy(html, out_dir, overwrite = TRUE)
if (!all(copied)) {
  stop("Failed to copy some vignette HTML files to inst/doc/.", call. = FALSE)
}

vigs <- tools::pkgVignettes(dir = pkg_root)
idx_path <- file.path(out_dir, "index.html")
if (!is.null(vigs$index) && file.exists(vigs$index)) {
  file.copy(vigs$index, idx_path, overwrite = TRUE)
} else if (!file.exists(idx_path)) {
  entries <- vapply(vigs$entries, function(x) x[[1]], character(1))
  links <- paste0(
    "<li><a href=\"", names(entries), ".html\">", entries, "</a></li>",
    collapse = "\n"
  )
  idx <- paste0(
    "<!DOCTYPE html>\n<html>\n<head><title>Vignettes</title></head>\n<body>\n",
    "<h2>Vignettes</h2>\n<ul>\n", links, "\n</ul>\n</body>\n</html>\n"
  )
  writeLines(idx, idx_path, useBytes = TRUE)
}

message("Vignettes in inst/doc/: ", paste(list.files(out_dir), collapse = ", "))
