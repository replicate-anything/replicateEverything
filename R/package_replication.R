#' Package-backed replication helpers
#'
#' @keywords internal
NULL

#' Whether replication metadata refers to an installed R package
#'
#' @param meta Parsed replication.yml contents.
#' @return Logical.
#' @keywords internal
is_package_replication <- function(meta) {
  pkg <- meta$paper$package %||% NULL
  !is.null(pkg) && nzchar(as.character(pkg[[1]]))
}

#' Resolve GitHub repo slug for a package-backed replication
#'
#' Used when no local sibling package is found. Set \code{paper.package_repo}
#' or top-level \code{repo} in \code{replication.yml} (GitHub slug, e.g.
#' \code{replicate-anything/rep_10.1371_journal.pone.0278337}).
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character repo slug.
#' @keywords internal
package_repo_slug <- function(meta, ctx) {
  from_meta <- meta$repo %||% meta$paper$package_repo %||% NULL
  if (!is.null(from_meta) && nzchar(as.character(from_meta[[1]]))) {
    return(as.character(from_meta[[1]]))
  }
  ctx$repo
}

#' Git ref for \code{remotes::install_github()}
#'
#' @param meta Parsed replication.yml contents.
#' @return Character branch, tag, or commit.
#' @keywords internal
package_repo_ref <- function(meta) {
  ref <- meta$paper$package_ref %||% meta$package_ref %||% "main"
  as.character(ref[[1]])
}

#' Folder names to check when locating a sibling replication package
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character vector of folder names (no duplicates).
#' @keywords internal
package_folder_candidates <- function(package, meta, ctx) {
  explicit <- c(
    meta$paper$package_folder %||% NULL,
    meta$paper$package_path %||% NULL,
    meta$package_folder %||% NULL
  )
  explicit <- vapply(explicit, function(x) {
    if (is.null(x)) return("")
    as.character(x[[1]])
  }, character(1))
  explicit <- explicit[nzchar(explicit)]

  derived <- character(0)
  if (!is.null(ctx$folder) && nzchar(ctx$folder)) {
    derived <- c(
      paste0("rep_", ctx$folder),
      ctx$folder
    )
  }

  unique(c(explicit, derived))
}

#' Resolve a local path to a study replication package
#'
#' Search order:
#' \enumerate{
#'   \item Explicit path in \code{paper.package_path} (if it exists)
#'   \item \code{getOption("replicateEverything.replication_packages")} map
#'   \item Sibling folders under \code{replication_packages_root} or monorepo root
#' }
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Normalized path, or \code{NULL}.
#' @keywords internal
resolve_replication_package_path <- function(package, meta, ctx) {
  explicit_path <- meta$paper$package_path %||% NULL
  if (!is.null(explicit_path) && nzchar(as.character(explicit_path[[1]]))) {
    path <- as.character(explicit_path[[1]])
    if (dir.exists(path) && package_desc_matches(path, package)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  pkg_map <- getOption("replicateEverything.replication_packages", NULL)
  if (!is.null(pkg_map) && !is.null(pkg_map[[package]])) {
    path <- pkg_map[[package]]
    if (dir.exists(path) && package_desc_matches(path, package)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  roots <- c(
    getOption("replicateEverything.replication_packages_root", NULL),
    sibling_monorepo_root()
  )
  roots <- unique(roots[!vapply(roots, is.null, logical(1))])
  roots <- roots[dir.exists(roots)]

  folders <- package_folder_candidates(package, meta, ctx)
  for (root in roots) {
    for (folder in folders) {
      candidate <- file.path(root, folder)
      if (package_desc_matches(candidate, package)) {
        return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
      }
    }
  }

  NULL
}

#' @keywords internal
package_desc_matches <- function(path, pkg_name) {
  desc_path <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    return(FALSE)
  }
  desc <- tryCatch(
    read.dcf(desc_path),
    error = function(e) NULL
  )
  !is.null(desc) &&
    nrow(desc) >= 1 &&
    identical(as.character(desc[1, "Package"]), pkg_name)
}

#' Parent directory of the registry when developing in a monorepo
#'
#' @return Character path or \code{NULL}.
#' @keywords internal
sibling_monorepo_root <- function() {
  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    return(NULL)
  }
  normalizePath(file.path(registry_root, ".."), winslash = "/", mustWork = FALSE)
}

#' SHA recorded for a package installed from GitHub
#'
#' @param package Installed package name.
#' @return Character SHA or \code{NA_character_}.
#' @keywords internal
installed_package_remote_sha <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(NA_character_)
  }
  desc <- utils::packageDescription(package)
  sha <- desc$RemoteSha %||% NA_character_
  if (length(sha) != 1L || !nzchar(sha)) {
    return(NA_character_)
  }
  as.character(sha)
}

#' Latest commit SHA for a GitHub repo ref
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
github_remote_sha <- function(repo, ref = "main") {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    stop("Package remotes is required to check GitHub versions.", call. = FALSE)
  }
  remote <- remotes::github_remote(paste0(repo, "@", ref))
  remotes::remote_sha(remote)
}

#' Whether an installed package lags the GitHub ref
#'
#' @param package Installed package name.
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
github_package_outdated <- function(package, repo, ref = "main") {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(TRUE)
  }
  local_sha <- installed_package_remote_sha(package)
  if (is.na(local_sha)) {
    return(TRUE)
  }
  remote_sha <- tryCatch(
    github_remote_sha(repo, ref),
    error = function(e) NA_character_
  )
  if (is.na(remote_sha) || !nzchar(remote_sha)) {
    return(FALSE)
  }
  !identical(local_sha, remote_sha)
}

#' Install or upgrade a study package from GitHub
#'
#' @param package R package name.
#' @param repo GitHub slug.
#' @param ref Git ref.
#' @keywords internal
install_replication_package_github <- function(package, repo, ref = "main") {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    stop(
      "Package remotes is required to install ", package,
      " from GitHub (", repo, ").",
      call. = FALSE
    )
  }
  spec <- paste0(repo, "@", ref)
  message("Installing ", package, " from GitHub (", spec, ") ...")
  remotes::install_github(spec, upgrade = "always", quiet = TRUE)
}

#' Load or install a study replication package
#'
#' Tries, in order: local sibling package (when configured), installed package
#' (upgrade from GitHub when outdated), then fresh GitHub install from
#' \code{package_repo_slug()}.
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @keywords internal
ensure_replication_package <- function(package, meta = NULL, ctx = NULL) {
  local_path <- resolve_replication_package_path(package, meta, ctx)
  if (!is.null(local_path)) {
    load_replication_package_path(local_path, package)
    if (requireNamespace(package, quietly = TRUE)) {
      return(invisible(TRUE))
    }
  }

  if (!is.null(meta) && !is.null(ctx)) {
    repo <- package_repo_slug(meta, ctx)
    ref <- package_repo_ref(meta)
    needs_install <- !requireNamespace(package, quietly = TRUE)
    needs_update <- !needs_install && github_package_outdated(package, repo, ref)
    if (needs_install || needs_update) {
      install_replication_package_github(package, repo, ref)
    }
    if (requireNamespace(package, quietly = TRUE)) {
      return(invisible(TRUE))
    }
  } else if (requireNamespace(package, quietly = TRUE)) {
    return(invisible(TRUE))
  }

  if (is.null(meta) || is.null(ctx)) {
    stop(
      "Replication package ", package,
      " is not installed and no local sibling was found.",
      call. = FALSE
    )
  }

  repo <- package_repo_slug(meta, ctx)
  ref <- package_repo_ref(meta)
  install_replication_package_github(package, repo, ref)
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(
      "Could not install replication package ", package,
      " from ", repo, " (ref: ", ref, ").",
      " For local development, keep the package as a sibling folder or set ",
      "paper.package_folder in replication.yml.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Load a package from a local source tree
#'
#' @param path Path to package root (contains DESCRIPTION).
#' @param package Expected package name.
#' @keywords internal
load_replication_package_path <- function(path, package) {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(path, quiet = TRUE)
    return(invisible(TRUE))
  }
  if (requireNamespace("remotes", quietly = TRUE)) {
    remotes::install_local(path, upgrade = "never", quiet = TRUE)
    return(invisible(TRUE))
  }
  stop(
    "Found local replication package at ", path,
    " but need devtools or remotes to load it.",
    call. = FALSE
  )
}

#' Call a function from a study replication package
#'
#' @param package Package name.
#' @param fn Function name as string.
#' @param ... Arguments passed to the function.
#' @keywords internal
call_replication_package <- function(package, fn, ...) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Replication package ", package, " is not installed.", call. = FALSE)
  }
  fun <- get(fn, envir = asNamespace(package))
  fun(...)
}
