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

#' Resolve Shiny deploy destination directory
#'
#' When \code{dest} is a relative path that already matches the tail of
#' \code{getwd()} (e.g. cwd is \code{.../shiny_apps/replicate} and
#' \code{dest} is \code{"shiny_apps/replicate"}), returns \code{getwd()} so
#' files are not written into a nested subfolder.
#'
#' @param dest Target directory; default current working directory.
#' @return Normalized absolute path.
#' @keywords internal
resolve_shiny_deploy_dest <- function(dest = getwd()) {
  cwd <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  if (missing(dest) || is.null(dest)) {
    return(cwd)
  }
  dest <- as.character(dest[[1]] %||% dest)
  if (!nzchar(dest) || dest %in% c(".", "./")) {
    return(cwd)
  }

  dest_norm <- gsub("\\\\", "/", dest, fixed = TRUE)

  if (grepl("^/", dest_norm) || grepl(":", dest_norm, fixed = TRUE)) {
    if (!dir.exists(dest_norm)) {
      dir.create(dest_norm, recursive = TRUE, showWarnings = FALSE)
    }
    return(normalizePath(dest_norm, winslash = "/", mustWork = TRUE))
  }

  if (shiny_path_has_suffix(cwd, dest_norm)) {
    return(cwd)
  }

  out <- file.path(cwd, dest_norm)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  normalizePath(out, winslash = "/", mustWork = TRUE)
}

#' @keywords internal
shiny_path_has_suffix <- function(path, suffix) {
  path <- gsub("\\\\", "/", path, fixed = TRUE)
  suffix <- gsub("\\\\", "/", suffix, fixed = TRUE)
  suffix <- sub("^/+", "", suffix)
  suffix <- sub("/+$", "", suffix)
  if (!nzchar(suffix)) {
    return(FALSE)
  }
  endsWith(path, suffix)
}

#' Whether the Shiny app allows live replication runs
#'
#' Reads \code{options(replicate_shiny.live_run)}; default \code{TRUE}.
#'
#' @return Logical scalar.
#' @keywords internal
shiny_live_run_enabled <- function() {
  isTRUE(getOption("replicate_shiny.live_run", TRUE))
}

#' Write deploy-options.R for a Shiny deploy directory
#'
#' Sets \code{options(replicate_shiny.live_run = ...)} when the deployed
#' \code{app.R} starts (always overwritten on deploy, like \code{BUNDLE_SHA}).
#'
#' @param dest Deploy directory.
#' @param live_run If \code{TRUE}, enable Live Run; if \code{FALSE}, display-only.
#' @return Invisibly, \code{live_run}.
#' @keywords internal
write_shiny_deploy_options <- function(dest, live_run = TRUE) {
  dest <- resolve_shiny_deploy_dest(dest)
  line <- sprintf(
    "options(replicate_shiny.live_run = %s)",
    if (isTRUE(live_run)) "TRUE" else "FALSE"
  )
  writeLines(line, file.path(dest, "deploy-options.R"), useBytes = TRUE)
  invisible(isTRUE(live_run))
}

#' Parse a Shiny URL query string
#'
#' Accepts values from \code{session$clientData$url_search} or
#' \code{window.location.search}. Leading \code{?} is optional.
#'
#' @param query_string Character scalar, e.g. \code{"?doi=10.1017/..."}.
#' @return Named character list suitable for deep-link handling; empty when absent.
#' @keywords internal
parse_shiny_query_string <- function(query_string) {
  if (is.null(query_string) || length(query_string) != 1L) {
    return(list())
  }
  query_string <- trimws(as.character(query_string))
  if (!nzchar(query_string)) {
    return(list())
  }
  qs <- sub("^\\?", "", query_string)
  if (!nzchar(trimws(qs))) {
    return(list())
  }
  if (!requireNamespace("shiny", quietly = TRUE)) {
    parts <- strsplit(qs, "&", fixed = TRUE)[[1]]
    out <- list()
    for (part in parts) {
      kv <- strsplit(part, "=", fixed = TRUE)[[1]]
      if (length(kv) >= 2L) {
        out[[URLdecode(kv[[1]])]] <- URLdecode(paste(kv[-1], collapse = "="))
      }
    }
    return(out)
  }
  shiny::parseQueryString(qs)
}

#' Extract DOI deep-link fields from a parsed query list
#'
#' @param query_list Named list from \code{parse_shiny_query_string()}.
#' @return List with \code{doi}, \code{what}, \code{language}, or \code{NULL}.
#' @keywords internal
extract_shiny_deep_link <- function(query_list) {
  if (is.null(query_list) || !length(query_list)) {
    return(NULL)
  }
  doi <- trimws(as.character(query_list$doi %||% ""))
  if (!nzchar(doi)) {
    return(NULL)
  }
  list(
    doi = doi,
    what = trimws(as.character(query_list$what %||% "")),
    language = trimws(as.character(query_list$language %||% ""))
  )
}

#' Parse DOI deep-link fields from a URL search string
#'
#' @param url_search Value of \code{session$clientData$url_search}.
#' @return List from \code{extract_shiny_deep_link()}, or \code{NULL}.
#' @keywords internal
parse_shiny_deep_link_from_search <- function(url_search) {
  extract_shiny_deep_link(parse_shiny_query_string(url_search))
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
#' @param live_run If `TRUE` (default), deployed app shows Live Run controls;
#'   if `FALSE`, writes `deploy-options.R` for a display-only deployment.
#' @return Invisibly, normalized `dest`.
#' @export
#' @examples
#' \dontrun{
#' # After install_github("replicate-anything/replicateEverything"):
#' save_local_shiny("/srv/shiny/replicate")
#' save_local_shiny("/srv/shiny/replicate", live_run = FALSE) # display-only
#' }
save_local_shiny <- function(
  dest = getwd(),
  package = "replicateEverything",
  overwrite = TRUE,
  live_run = TRUE
) {
  src <- shiny_app_dir(package)
  if (!nzchar(src) || !dir.exists(src)) {
    stop(
      "No Shiny app found in ", package,
      ". Reinstall the package from GitHub?",
      call. = FALSE
    )
  }

  dest <- resolve_shiny_deploy_dest(dest)

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

  bundle_sha <- write_shiny_bundle_sha(dest, package = package)
  write_shiny_deploy_options(dest, live_run = live_run)
  mode_label <- if (isTRUE(live_run)) "live run" else "display-only"
  message(
    "Shiny app written to ", dest,
    " (BUNDLE_SHA=", bundle_sha, ", ", mode_label, "). ",
    "Restart Shiny workers after deploy."
  )
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

  launch_wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  options(replicateEverything.shiny_launch_wd = launch_wd)
  monorepo <- monorepo_root_from_path(launch_wd)
  if (!is.null(monorepo)) {
    tryCatch(
      configure_local_monorepo(monorepo),
      error = function(e) {
        options(
          replicateEverything.study_folders_root = monorepo,
          replicateEverything.use_sibling_packages = TRUE
        )
      }
    )
  }

  options(replicate_shiny.auto_update_replicate_everything = FALSE)
  shiny::runApp(app_dir, ...)
}
