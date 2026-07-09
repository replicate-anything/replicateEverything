#' Short git or GitHub SHA label
#'
#' @param sha Full or short commit SHA.
#' @return Seven-character SHA or \code{NA_character_}.
#' @keywords internal
short_build_sha <- function(sha) {
  sha <- as.character(sha[[1]] %||% sha)
  if (length(sha) != 1L || is.na(sha) || !nzchar(sha)) {
    return(NA_character_)
  }
  sha <- sub("^\\++", "", sha)
  substr(sha, 1L, 7L)
}

#' Read first line from a build stamp file
#'
#' @param path File path.
#' @keywords internal
read_build_sha_file <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(NA_character_)
  }
  line <- tryCatch(
    trimws(readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8")),
    error = function(e) ""
  )
  if (!length(line) || !nzchar(line)) {
    return(NA_character_)
  }
  short_build_sha(line)
}

#' Package version and build identity
#'
#' Uses \code{RemoteSha} from \code{packageDescription()} when installed via
#' \code{remotes::install_github()}, otherwise the bundled
#' \code{inst/shiny/BUNDLE_SHA} stamp.
#'
#' @param package Package name.
#' @return List with \code{version}, \code{sha}, and \code{source}.
#' @export
package_build_info <- function(package = "replicateEverything") {
  version <- tryCatch(
    as.character(utils::packageVersion(package)),
    error = function(e) "unknown"
  )
  sha <- NA_character_
  source <- character(0)

  desc <- tryCatch(
    utils::packageDescription(package),
    error = function(e) NULL
  )
  if (!is.null(desc) && nzchar(desc$RemoteSha %||% "")) {
    sha <- short_build_sha(desc$RemoteSha)
    source <- c(source, "RemoteSha")
  }

  if (is.na(sha) || !nzchar(sha)) {
    bundle <- read_build_sha_file(
      system.file("shiny", "BUNDLE_SHA", package = package)
    )
    if (nzchar(bundle)) {
      sha <- bundle
      source <- c(source, "BUNDLE_SHA")
    }
  }

  list(
    version = version,
    sha = sha,
    source = paste(unique(source), collapse = "+")
  )
}

#' Shiny deploy directory (app bundle root)
#'
#' @return Normalized path.
#' @keywords internal
shiny_deploy_dir <- function() {
  app_env <- Sys.getenv("SHINY_APP_DIR", unset = "")
  if (length(app_env) == 1L && nzchar(app_env) && dir.exists(app_env)) {
    return(normalizePath(app_env, winslash = "/", mustWork = FALSE))
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

#' SHA stamp for the running Shiny app bundle
#'
#' Prefers \code{BUNDLE_SHA} next to the deployed \code{app.R}, then the
#' bundled stamp shipped inside the installed package.
#'
#' @param package Package that ships the Shiny app.
#' @return Seven-character SHA or \code{NA_character_}.
#' @keywords internal
shiny_app_bundle_sha <- function(package = "replicateEverything") {
  for (path in c(
    file.path(shiny_deploy_dir(), "BUNDLE_SHA"),
    system.file("shiny", "BUNDLE_SHA", package = package)
  )) {
    sha <- read_build_sha_file(path)
    if (nzchar(sha)) {
      return(sha)
    }
  }
  NA_character_
}

#' Write \code{BUNDLE_SHA} for a Shiny deploy directory
#'
#' @param dest Deploy directory.
#' @param package Package name.
#' @return Invisibly, the SHA written.
#' @keywords internal
write_shiny_bundle_sha <- function(dest, package = "replicateEverything") {
  info <- package_build_info(package)
  sha <- info$sha
  if (is.na(sha) || !nzchar(sha)) {
    sha <- format(Sys.time(), "%Y%m%d")
  }
  dest <- resolve_shiny_deploy_dest(dest)
  writeLines(sha, file.path(dest, "BUNDLE_SHA"), useBytes = TRUE)
  invisible(sha)
}
