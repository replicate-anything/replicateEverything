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

#' Bundled Shiny build stamp from an installed package
#'
#' Reads \code{inst/shiny/BUNDLE_SHA} from the installed package. This is the
#' canonical identity for matching a deployed app bundle to a package build.
#'
#' @param package Package name.
#' @return Seven-character SHA or \code{NA_character_}.
#' @keywords internal
package_bundled_sha <- function(package = "replicateEverything") {
  read_build_sha_file(system.file("shiny", "BUNDLE_SHA", package = package))
}

#' GitHub install SHA from package DESCRIPTION
#'
#' @param package Package name.
#' @return Seven-character SHA or \code{NA_character_}.
#' @keywords internal
package_remote_install_sha <- function(package = "replicateEverything") {
  desc <- tryCatch(
    utils::packageDescription(package),
    error = function(e) NULL
  )
  if (!is.null(desc) && nzchar(desc$RemoteSha %||% "")) {
    return(short_build_sha(desc$RemoteSha))
  }
  NA_character_
}

#' Package version and build identity
#'
#' \code{sha} / \code{bundled_sha} come from the bundled \code{inst/shiny/BUNDLE_SHA}
#' stamp (used for deploy matching). \code{remote_sha} records \code{RemoteSha}
#' from \code{packageDescription()} when installed via GitHub (\code{remotes}, etc.).
#'
#' @param package Package name.
#' @return List with \code{version}, \code{sha}, \code{bundled_sha}, \code{remote_sha},
#'   and \code{source}.
#' @export
package_build_info <- function(package = "replicateEverything") {
  version <- tryCatch(
    as.character(utils::packageVersion(package)),
    error = function(e) "unknown"
  )
  bundled <- package_bundled_sha(package)
  remote <- package_remote_install_sha(package)
  source <- character(0)
  if (nzchar(bundled)) {
    source <- c(source, "BUNDLE_SHA")
  }
  if (nzchar(remote)) {
    source <- c(source, "RemoteSha")
  }
  sha <- bundled
  if (!nzchar(sha)) {
    sha <- remote
  }

  list(
    version = version,
    sha = sha,
    bundled_sha = bundled,
    remote_sha = remote,
    source = paste(unique(source), collapse = "+")
  )
}

#' Whether a loaded package namespace is older than the on-disk install
#'
#' @param package Package name.
#' @return Logical scalar.
#' @keywords internal
package_namespace_stale <- function(package = "replicateEverything") {
  if (!isNamespaceLoaded(package)) {
    return(FALSE)
  }
  disk_ver <- tryCatch(
    as.character(utils::packageVersion(package)),
    error = function(e) NULL
  )
  ns_ver <- tryCatch(
    as.character(getNamespaceVersion(package)),
    error = function(e) NULL
  )
  is.character(disk_ver) &&
    is.character(ns_ver) &&
    nzchar(disk_ver) &&
    nzchar(ns_ver) &&
    !identical(disk_ver, ns_ver)
}

#' Resolve a function from an installed package namespace
#'
#' Checks exported and internal bindings. When the namespace version differs
#' from the on-disk package version, stops with a restart hint (typical when
#' Shiny workers were not restarted after \code{install_github()}).
#'
#' @param name Function name.
#' @param package Package name.
#' @param aliases Optional alternate names to try.
#' @return The resolved function.
#' @keywords internal
get_package_namespace_fn <- function(
  name,
  package = "replicateEverything",
  aliases = character(0)
) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(package, " is not installed.", call. = FALSE)
  }
  ns <- asNamespace(package)
  candidates <- unique(c(name, aliases))
  for (nm in candidates) {
    if (exists(nm, envir = ns, inherits = FALSE)) {
      return(get(nm, envir = ns, inherits = FALSE))
    }
  }
  pkg_ver <- tryCatch(
    as.character(utils::packageVersion(package)),
    error = function(e) "unknown"
  )
  if (package_namespace_stale(package)) {
    ns_ver <- tryCatch(
      as.character(getNamespaceVersion(package)),
      error = function(e) "unknown"
    )
    stop(
      "Function ", package, "::", name,
      " is not available because this R session loaded ", package, " ",
      ns_ver, " but version ", pkg_ver, " is installed on disk. ",
      "Restart all Shiny/R worker processes after updating the package.",
      call. = FALSE
    )
  }
  stop(
    "Function ", package, "::", name,
    " is not available (installed version ", pkg_ver, "). ",
    "Update ", package,
    " (remotes::install_github('replicate-anything/replicateEverything')) ",
    "and redeploy the Shiny app from the same release.",
    call. = FALSE
  )
}

#' Installed package library path
#'
#' @param package Package name.
#' @return Normalized path to the installed package directory, or \code{""}.
#' @keywords internal
package_library_path <- function(package = "replicateEverything") {
  path <- tryCatch(
    normalizePath(
      system.file(package = package),
      winslash = "/",
      mustWork = FALSE
    ),
    error = function(e) ""
  )
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    return("")
  }
  path
}

#' Functions probed when diagnosing a Shiny deployment
#' @keywords internal
PACKAGE_DEPLOY_PROBE_FUNCTIONS <- c(
  "shiny_feedback_github_category_url",
  "shiny_feedback_github_issue_url",
  "package_build_info",
  "source_shiny_deploy_config",
  "package_deploy_diagnostics"
)

#' Diagnose Shiny deployment and installed package identity
#'
#' Use on the Shiny host (interactive R session) to confirm which
#' \code{replicateEverything} build is installed, where it lives on disk,
#' whether the deployed \code{app.R} bundle matches, and whether expected
#' functions exist in the loaded namespace.
#'
#' @param deploy_dir Deploy directory containing \code{app.R}. Defaults to
#'   [shiny_deploy_dir()].
#' @param package Package name; default \code{"replicateEverything"}.
#' @param print If \code{TRUE}, print a human-readable report to the console.
#' @return Named list (invisibly when \code{print = TRUE}).
#' @export
#' @examples
#' \dontrun{
#' remotes::install_github("replicate-anything/replicateEverything")
#' replicateEverything::save_local_shiny("/srv/shiny/replicate")
#' replicateEverything::package_deploy_diagnostics("/srv/shiny/replicate")
#' }
package_deploy_diagnostics <- function(
  deploy_dir = NULL,
  package = "replicateEverything",
  print = TRUE
) {
  if (is.null(deploy_dir)) {
    deploy_dir <- shiny_deploy_dir()
  } else {
    deploy_dir <- as.character(deploy_dir[[1L]] %||% deploy_dir)
    if (nzchar(deploy_dir) && dir.exists(deploy_dir)) {
      deploy_dir <- normalizePath(deploy_dir, winslash = "/", mustWork = FALSE)
    }
  }

  pkg_info <- package_build_info(package)
  lib_path <- package_library_path(package)
  lib_index <- which(vapply(.libPaths(), function(p) {
    file.exists(file.path(p, package))
  }, logical(1L)))
  if (!length(lib_index)) {
    lib_index <- NA_integer_
  }

  app_sha <- if (nzchar(deploy_dir) && dir.exists(deploy_dir)) {
    read_build_sha_file(file.path(deploy_dir, "BUNDLE_SHA"))
  } else {
    NA_character_
  }
  deploy_stamp <- read_deploy_stamp_options(deploy_dir)
  bundled_sha <- pkg_info$bundled_sha %||% pkg_info$sha
  version_stale <- isTRUE(
    nzchar(deploy_stamp$version %||% "") &&
      !identical(deploy_stamp$version, pkg_info$version)
  )
  lib_stale <- isTRUE(
    nzchar(deploy_stamp$lib %||% "") &&
      nzchar(lib_path) &&
      !identical(
        normalizePath(deploy_stamp$lib, winslash = "/", mustWork = FALSE),
        lib_path
      )
  )
  app_bundle_mismatch <- isTRUE(
    nzchar(app_sha %||% "") &&
      nzchar(bundled_sha %||% "") &&
      !identical(app_sha, bundled_sha)
  )
  namespace_stale <- package_namespace_stale(package)

  fn_status <- setNames(
    vapply(PACKAGE_DEPLOY_PROBE_FUNCTIONS, function(name) {
      if (!requireNamespace(package, quietly = TRUE)) {
        return(FALSE)
      }
      exists(name, envir = asNamespace(package), inherits = FALSE)
    }, logical(1L)),
    PACKAGE_DEPLOY_PROBE_FUNCTIONS
  )

  feedback_enabled <- if (requireNamespace(package, quietly = TRUE) &&
      exists("shiny_feedback_log_enabled", envir = asNamespace(package), inherits = FALSE)) {
    get("shiny_feedback_log_enabled", envir = asNamespace(package))()
  } else {
    NA
  }

  out <- list(
    package = package,
    version = pkg_info$version,
    pkg_sha = bundled_sha,
    pkg_bundled_sha = bundled_sha,
    pkg_remote_sha = pkg_info$remote_sha,
    pkg_sha_source = pkg_info$source,
    library_path = lib_path,
    lib_paths = .libPaths(),
    package_lib_index = lib_index,
    deploy_dir = deploy_dir,
    deploy_stamp = deploy_stamp,
    app_sha = app_sha,
    app_bundle_mismatch = app_bundle_mismatch,
    version_stale = version_stale,
    lib_stale = lib_stale,
    namespace_stale = namespace_stale,
    app_stale = isTRUE(
      version_stale ||
        lib_stale ||
        namespace_stale ||
        length(names(fn_status)[!fn_status]) > 0L
    ),
    getwd = getwd(),
    shiny_app_dir = Sys.getenv("SHINY_APP_DIR", unset = ""),
    use_local_dev = isTRUE(getOption("replicate_shiny.use_local_replicate_everything", FALSE)),
    local_r_loaded = isTRUE(getOption("replicate_shiny.local_r_loaded", FALSE)),
    live_run = isTRUE(getOption("replicate_shiny.live_run", TRUE)),
    feedback_enabled = feedback_enabled,
    functions = fn_status,
    missing_functions = names(fn_status)[!fn_status]
  )

  if (isTRUE(print)) {
    cat("replicateEverything deploy diagnostics\n")
    cat("======================================\n")
    cat("Package version: ", out$version, "\n", sep = "")
    cat(
      "Package bundled SHA: ", bundled_sha %||% "(none)",
      if (nzchar(pkg_info$remote_sha %||% "")) {
        paste0(" · GitHub install SHA: ", pkg_info$remote_sha)
      } else {
        ""
      },
      "\n",
      sep = ""
    )
    if (isTRUE(namespace_stale)) {
      cat(
        "WARNING: loaded namespace version differs from installed package — restart Shiny workers\n"
      )
    }
    cat("Library path: ", if (nzchar(lib_path)) lib_path else "(not installed)", "\n", sep = "")
    cat(
      "Found in .libPaths()[", out$package_lib_index, "]: ",
      if (is.na(out$package_lib_index)) "no" else .libPaths()[[out$package_lib_index]],
      "\n",
      sep = ""
    )
    cat("\n.libPaths():\n")
    for (i in seq_along(out$lib_paths)) {
      cat("  [", i, "] ", out$lib_paths[[i]], "\n", sep = "")
    }
    cat("\nDeploy directory: ", deploy_dir, "\n", sep = "")
    cat("App BUNDLE_SHA: ", app_sha %||% "(missing)", "\n", sep = "")
    if (isTRUE(version_stale)) {
      cat(
        "WARNING: deploy stamp version (", deploy_stamp$version,
        ") differs from installed package — re-run save_local_shiny()\n",
        sep = ""
      )
    } else if (isTRUE(lib_stale)) {
      cat("WARNING: deploy library path differs from installed package — re-run save_local_shiny()\n")
    } else if (isTRUE(app_bundle_mismatch)) {
      cat(
        "NOTE: app BUNDLE_SHA differs from bundled package stamp (often harmless after GitHub→local reinstall); ",
        "re-run save_local_shiny() to refresh the deploy stamp\n",
        sep = ""
      )
    } else if (length(out$missing_functions)) {
      cat("WARNING: key functions missing from installed package — update and restart workers\n")
    }
    cat("getwd(): ", out$getwd, "\n", sep = "")
    if (nzchar(out$shiny_app_dir)) {
      cat("SHINY_APP_DIR: ", out$shiny_app_dir, "\n", sep = "")
    }
    cat(
      "Local dev load_all: ", if (out$use_local_dev) "yes" else "no",
      " · local.R loaded: ", if (out$local_r_loaded) "yes" else "no",
      "\n",
      sep = ""
    )
    cat("Live Run: ", if (out$live_run) "enabled" else "disabled", "\n", sep = "")
    cat(
      "Feedback logging: ",
      if (is.na(feedback_enabled)) "unknown" else if (feedback_enabled) "enabled" else "disabled",
      "\n",
      sep = ""
    )
    cat("\nKey functions in namespace:\n")
    for (nm in names(fn_status)) {
      cat("  ", nm, ": ", if (fn_status[[nm]]) "OK" else "MISSING", "\n", sep = "")
    }
    if (length(out$missing_functions)) {
      cat(
        "\nUpdate replicateEverything and restart Shiny workers ",
        "(remotes::install_github('replicate-anything/replicateEverything')).\n",
        sep = ""
      )
    }
    cat("\nAfter install: save_local_shiny('<deploy-dir>') then restart ALL Shiny processes.\n")
  }

  invisible(out)
}

#' Shiny deploy directory (app bundle root)
#'
#' Prefers \code{options(replicate_shiny.app_dir)}, then \code{SHINY_APP_DIR},
#' then \code{getwd()}. Relative feedback paths and \code{local.R} resolve here.
#'
#' @return Normalized path.
#' @keywords internal
shiny_deploy_dir <- function() {
  opt <- getOption("replicate_shiny.app_dir", NULL)
  if (!is.null(opt) && length(opt) == 1L && !is.na(opt)) {
    opt <- as.character(opt)
    if (nzchar(opt) && dir.exists(opt)) {
      return(normalizePath(opt, winslash = "/", mustWork = FALSE))
    }
  }
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
  sha <- info$bundled_sha
  if (!nzchar(sha %||% "")) {
    sha <- info$remote_sha
  }
  if (!nzchar(sha %||% "")) {
    sha <- format(Sys.time(), "%Y%m%d")
  }
  dest <- resolve_shiny_deploy_dest(dest)
  writeLines(sha, file.path(dest, "BUNDLE_SHA"), useBytes = TRUE)
  invisible(sha)
}

#' Read deploy stamp options from deploy-options.R without sourcing
#'
#' @param deploy_dir Deploy directory.
#' @return Named list with optional \code{version}, \code{sha}, and \code{lib}.
#' @keywords internal
read_deploy_stamp_options <- function(deploy_dir) {
  empty <- list(version = NA_character_, sha = NA_character_, lib = NA_character_)
  if (length(deploy_dir) != 1L || is.na(deploy_dir) || !nzchar(deploy_dir)) {
    return(empty)
  }
  path <- file.path(deploy_dir, "deploy-options.R")
  if (!file.exists(path)) {
    return(empty)
  }
  lines <- tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) character(0)
  )
  if (!length(lines)) {
    return(empty)
  }
  read_option <- function(option_name) {
    pattern <- sprintf(
      "^\\s*options\\(%s\\s*=\\s*\"([^\"]*)\"\\)\\s*$",
      gsub("([.|()\\^{}+$*?\\[\\]\\\\])", "\\\\\\1", option_name, perl = TRUE)
    )
    hit <- grep(pattern, lines, value = TRUE, perl = TRUE)
    if (!length(hit)) {
      return(NA_character_)
    }
    sub(pattern, "\\1", hit[[1L]], perl = TRUE)
  }
  list(
    version = read_option("replicate_shiny.deploy_pkg_version"),
    sha = read_option("replicate_shiny.deploy_pkg_sha"),
    lib = read_option("replicate_shiny.deploy_lib")
  )
}
