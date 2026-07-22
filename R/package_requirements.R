#' Optional legacy exports some older study packages still ship
#'
#' Study packages should **not** export these; they belong in
#' replicateEverything. Kept only so checks can report (and skip) legacy
#' wrappers without requiring them.
#' @keywords internal
PACKAGE_REPLICATION_LEGACY_API <- c(
  "list_replications",
  "run_replication",
  "load_artifact",
  "get_code"
)

#' Recommended study-package helpers (not the replicateEverything verbs)
#' @keywords internal
PACKAGE_REPLICATION_HELPERS <- c("build_report")

#' Display replication types validated for artifacts
#' @keywords internal
DISPLAY_REPLICATION_TYPES <- c("figure", "table")

#' Record a single checklist result
#' @keywords internal
check_result <- function(name, passed, message = "") {
  data.frame(
    check = name,
    passed = isTRUE(passed),
    message = as.character(message),
    stringsAsFactors = FALSE
  )
}

#' Combine checklist results
#' @keywords internal
bind_check_results <- function(...) {
  do.call(rbind, c(list(...), make.row.names = NULL))
}

#' Parse a GitHub repo slug from a URL or slug string
#'
#' @param location Character. Local path, HTTPS URL, git URL, or `org/repo`.
#' @return Character `org/repo` or `NULL`.
#' @keywords internal
parse_github_slug <- function(location) {
  if (length(location) != 1L || is.na(location) || !nzchar(trimws(location))) {
    return(NULL)
  }
  x <- trimws(location)
  m <- regexpr("^https?://github\\.com/([^/#?]+/[^/#?]+)", x, perl = TRUE)
  if (m > 0) {
    return(substr(x, attr(m, "capture.start"), attr(m, "capture.start") + attr(m, "capture.length") - 1))
  }
  m <- regexpr("^git@github\\.com:([^/]+/[^.]+)(?:\\.git)?$", x, perl = TRUE)
  if (m > 0) {
    return(substr(x, attr(m, "capture.start"), attr(m, "capture.start") + attr(m, "capture.length") - 1))
  }
  if (looks_like_doi_location(x)) {
    return(NULL)
  }
  if (grepl("^[^/\\s]+/[^/\\s]+$", x)) {
    return(x)
  }
  NULL
}

#' Resolve a study package root directory from a local path or GitHub address
#'
#' @param location Local package path or GitHub address.
#' @return Normalized path to package root.
#' @keywords internal
resolve_package_location <- function(location) {
  if (length(location) != 1L || is.na(location) || !nzchar(trimws(location))) {
    stop("location must be a non-empty path or GitHub address.", call. = FALSE)
  }
  loc <- trimws(location)
  if (dir.exists(loc) && file.exists(file.path(loc, "DESCRIPTION"))) {
    return(normalizePath(loc, winslash = "/", mustWork = FALSE))
  }
  slug <- parse_github_slug(loc)
  if (is.null(slug)) {
    stop(
      "Could not resolve package location: ", loc,
      ". Provide a directory containing DESCRIPTION or a GitHub URL/slug.",
      call. = FALSE
    )
  }
  tmp <- file.path(
    tempdir(),
    paste0("re_add_paper_", gsub("[^a-zA-Z0-9._-]", "_", slug))
  )
  if (dir.exists(tmp)) {
    unlink(tmp, recursive = TRUE, force = TRUE)
  }
  git <- Sys.which("git")
  if (!nzchar(git)) {
    stop(
      "Git is required to clone ", slug,
      ". Clone the repository locally and pass the package path to add_paper().",
      call. = FALSE
    )
  }
  status <- system2(
    git,
    c("clone", "--depth", "1", sprintf("https://github.com/%s.git", slug), tmp),
    stdout = FALSE,
    stderr = FALSE
  )
  if (!identical(status, 0L) || !file.exists(file.path(tmp, "DESCRIPTION"))) {
    stop("Failed to clone package repository: ", slug, call. = FALSE)
  }
  normalizePath(tmp, winslash = "/", mustWork = FALSE)
}

#' Read replication yaml from a package source tree
#' @keywords internal
read_package_replication_yaml <- function(pkg_root) {
  candidates <- c(
    file.path(pkg_root, "replication.yml"),
    file.path(pkg_root, "inst", "replication.yml")
  )
  for (path in candidates) {
    if (file.exists(path)) {
      return(yaml::read_yaml(path))
    }
  }
  NULL
}

#' Registry folder name from a DOI
#' @keywords internal
doi_to_registry_folder <- function(doi) {
  gsub("/", "_", normalize_doi(doi))
}

#' Build the lightweight registry stub yaml list from package metadata
#' @keywords internal
registry_stub_from_package_meta <- function(meta, package_folder = NULL) {
  paper <- meta$paper
  pkg_repo <- as.character((meta$repo %||% paper$package_repo)[[1]])
  stub_paper <- list(
    doi = paper$doi,
    title = paper$title,
    journal = paper$journal %||% NULL,
    year = paper$year %||% NULL,
    authors = paper$authors %||% NULL,
    package = paper$package,
    package_repo = pkg_repo,
    package_ref = as.character((paper$package_ref %||% "main")[[1]])
  )
  if (!is.null(package_folder) && nzchar(package_folder)) {
    stub_paper$package_folder <- package_folder
  }
  stub_paper <- stub_paper[!vapply(stub_paper, is.null, logical(1))]
  c(
    list(paper = stub_paper, repo = pkg_repo),
    registry_stub_summary_fields(meta)
  )
}
