#' Path to the bundled Shiny demo app
#'
#' @param package Package name; default `"replicateEverything"`.
#' @return Normalized path to `inst/shiny`, or `""` if missing.
#' @keywords internal
shiny_app_dir <- function(package = "replicateEverything") {
  normalizePath(
    system.file("shiny", package = package),
    winslash = "/",
    mustWork = FALSE
  )
}

#' Copy the bundled Shiny app into a deploy directory
#'
#' Materializes `inst/shiny` from an installed `replicateEverything` build into
#' `dest`, for Shiny Server and similar hosts that expect `app.R` (and `www/`)
#' in a fixed folder. Existing `local.R` in `dest` is never overwritten.
#'
#' @param dest Target directory. Defaults to the current working directory.
#' @param package Package that ships the app; default `"replicateEverything"`.
#' @param overwrite If `TRUE`, replace existing app files except `local.R`.
#' @return Invisibly, normalized `dest`.
#' @export
#' @examples
#' \dontrun{
#' # After install_github("replicate-anything/replicateEverything"):
#' save_local_shiny("/srv/shiny/replicate")
#' }
save_local_shiny <- function(
  dest = getwd(),
  package = "replicateEverything",
  overwrite = TRUE
) {
  src <- shiny_app_dir(package)
  if (!nzchar(src) || !dir.exists(src)) {
    stop(
      "No Shiny app found in ", package,
      ". Reinstall the package from GitHub?",
      call. = FALSE
    )
  }

  dest <- normalizePath(dest, winslash = "/", mustWork = FALSE)
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  copy_file <- function(from, to) {
    if (!file.exists(from)) {
      return(invisible(FALSE))
    }
    if (!overwrite && file.exists(to)) {
      return(invisible(FALSE))
    }
    parent <- dirname(to)
    if (!dir.exists(parent)) {
      dir.create(parent, recursive = TRUE, showWarnings = FALSE)
    }
    file.copy(from, to, overwrite = overwrite)
    invisible(TRUE)
  }

  app_r <- file.path(src, "app.R")
  if (!file.exists(app_r)) {
    stop("Missing app.R in package Shiny directory.", call. = FALSE)
  }
  copy_file(app_r, file.path(dest, "app.R"))

  www_src <- file.path(src, "www")
  if (dir.exists(www_src)) {
    www_files <- list.files(www_src, recursive = TRUE, full.names = TRUE, all.files = FALSE)
    www_root <- normalizePath(www_src, winslash = "/", mustWork = FALSE)
    for (f in www_files) {
      rel <- sub(paste0("^", gsub("\\\\", "/", www_root), "/?"), "", gsub("\\\\", "/", f))
      if (!nzchar(rel) || dir.exists(f)) {
        next
      }
      copy_file(f, file.path(dest, "www", rel))
    }
  }

  example <- file.path(src, "local.R.example")
  if (file.exists(example)) {
    copy_file(example, file.path(dest, "local.R.example"))
  }

  message("Shiny app written to ", dest)
  invisible(dest)
}

#' Run the bundled Shiny demo app
#'
#' Launches the demo from `inst/shiny` inside the installed package. Does not
#' auto-update `replicateEverything` from GitHub (the running session already
#' uses the installed package). A live instance is hosted at
#' \url{https://shiny2.wzb.eu/ipi/replicate/}.
#'
#' @param ... Passed to [shiny::runApp()].
#' @return The value returned by [shiny::runApp()].
#' @export
#' @examples
#' \dontrun{
#' run_shiny_app()
#' }
run_shiny_app <- function(...) {
  if (!requireNamespace("shiny", quietly = TRUE)) {
    stop("Install the suggested package 'shiny' to run the demo app.", call. = FALSE)
  }
  if (!requireNamespace("bslib", quietly = TRUE)) {
    stop("Install the suggested package 'bslib' to run the demo app.", call. = FALSE)
  }

  app_dir <- shiny_app_dir()
  if (!nzchar(app_dir) || !file.exists(file.path(app_dir, "app.R"))) {
    stop(
      "Shiny app not found. Reinstall replicateEverything from GitHub?",
      call. = FALSE
    )
  }

  options(replicate_shiny.auto_update_replicate_everything = FALSE)
  shiny::runApp(app_dir, ...)
}
