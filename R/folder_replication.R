#' Folder-backed replication helpers
#'
#' Studies whose materials live in a separate Git repository as a simple
#' \code{data/}, \code{code/}, and \code{outputs/} tree (not an R package).
#'
#' @name folder_replication
#' @keywords internal
NULL

#' Default registry repository slug
#'
#' @keywords internal
DEFAULT_REGISTRY_REPO <- "replicate-anything/registry"

#' Derive the standard study repo folder name from a DOI
#'
#' @param doi Character DOI.
#' @return Character folder name such as \code{rep-10.1596-1813-9450-10626}.
#' @keywords internal
study_folder_from_doi <- function(doi) {
  paste0("rep-", gsub("/", "-", normalize_doi(doi), fixed = TRUE))
}

#' Whether a location string looks like a DOI (not a GitHub org/repo slug)
#'
#' DOIs such as \code{10.1017/S0003055426101622} match \code{org/repo} patterns
#' but must not be sent to GitHub clone helpers.
#'
#' @param x Character scalar.
#' @return Logical scalar.
#' @keywords internal
looks_like_doi_location <- function(x) {
  if (is.null(x) || length(x) != 1L) {
    return(FALSE)
  }
  x <- trimws(as.character(x))
  grepl("^10\\.\\d", x, perl = TRUE) ||
    grepl("^https?://doi\\.org/10\\.", x, ignore.case = TRUE) ||
    grepl("^doi:10\\.", x, ignore.case = TRUE)
}

#' Walk up directory tree until a relative path exists
#'
#' @param start Starting directory.
#' @param relative Path relative to each candidate root.
#' @param max_depth Maximum levels to ascend.
#' @return Normalized directory containing \code{relative}, or \code{NULL}.
#' @keywords internal
walk_up_for_relative <- function(start, relative, max_depth = 12L) {
  if (is.null(start) || length(start) != 1L || is.na(start) || !nzchar(start)) {
    return(NULL)
  }
  dir <- tryCatch(
    normalizePath(start, winslash = "/", mustWork = FALSE),
    error = function(e) NULL
  )
  if (is.null(dir) || !dir.exists(dir)) {
    return(NULL)
  }
  for (i in seq_len(max_depth)) {
    candidate <- file.path(dir, relative)
    if (file.exists(candidate)) {
      return(dir)
    }
    parent <- normalizePath(file.path(dir, ".."), winslash = "/", mustWork = FALSE)
    if (identical(parent, dir)) {
      break
    }
    dir <- parent
  }
  NULL
}

#' Locate monorepo root from a starting directory
#'
#' @param path Directory path (e.g. session launch directory).
#' @return Normalized monorepo path or \code{NULL}.
#' @keywords internal
monorepo_root_from_path <- function(path) {
  if (is.null(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    return(NULL)
  }
  if (!dir.exists(path)) {
    return(NULL)
  }
  found <- walk_up_for_relative(path, "registry/index.csv")
  if (is.null(found)) {
    return(NULL)
  }
  if (dir.exists(file.path(found, "replicateEverything"))) {
    return(normalizePath(found, winslash = "/", mustWork = FALSE))
  }
  NULL
}

#' Detect a local replicate-anything monorepo root
#'
#' Looks for \code{registry/index.csv} next to the installed or loaded
#' \pkg{replicateEverything} package, the Shiny launch directory, or uses
#' \code{getOption("replicateEverything.study_folders_root")}.
#'
#' @return Normalized path or \code{NULL}.
#' @keywords internal
auto_detect_monorepo_root <- function() {
  study_root <- getOption("replicateEverything.study_folders_root", NULL)
  if (!is.null(study_root) && dir.exists(study_root)) {
    return(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  }

  launch_wd <- getOption("replicateEverything.shiny_launch_wd", NULL)
  if (!is.null(launch_wd) && nzchar(launch_wd)) {
    found <- monorepo_root_from_path(launch_wd)
    if (!is.null(found)) {
      return(found)
    }
  }

  env_root <- Sys.getenv("REPLICATE_MONOREPO_ROOT", unset = "")
  if (nzchar(env_root) && file.exists(file.path(env_root, "registry", "index.csv"))) {
    return(normalizePath(env_root, winslash = "/", mustWork = FALSE))
  }

  pkg_root <- tryCatch(
    getNamespaceInfo("replicateEverything", "path"),
    error = function(e) ""
  )
  if (!nzchar(pkg_root)) {
    pkg_root <- tryCatch(system.file(package = "replicateEverything"), error = function(e) "")
  }
  shiny_root <- tryCatch(system.file("shiny", package = "replicateEverything"), error = function(e) "")

  starts <- unique(c(
    getwd(),
    pkg_root,
    shiny_root,
    if (nzchar(pkg_root)) dirname(pkg_root),
    if (nzchar(shiny_root)) dirname(shiny_root)
  ))
  starts <- starts[nzchar(starts)]
  for (start in starts) {
    found <- walk_up_for_relative(start, "registry/index.csv")
    if (!is.null(found)) {
      return(found)
    }
  }

  NULL
}

#' Resolve a local folder-backed study directory for a DOI
#'
#' @param doi Character DOI.
#' @return Normalized study path or \code{NULL}.
#' @keywords internal
resolve_local_study_folder <- function(doi) {
  doi <- as.character(doi)
  study_names <- unique(c(
    study_folder_from_doi(doi),
    if (grepl("^rep[-_]", doi)) doi else character(0)
  ))
  roots <- unique(c(
    getOption("replicateEverything.study_folders_root", NULL),
    sibling_monorepo_root(),
    Sys.getenv("REPLICATE_MONOREPO_ROOT", unset = "")
  ))
  roots <- roots[nzchar(roots) & dir.exists(roots)]
  for (monorepo in roots) {
    for (study_name in study_names) {
      candidate <- file.path(monorepo, study_name)
      if (dir.exists(candidate) && file.exists(file.path(candidate, "replication.yml"))) {
        return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
      }
    }
  }

  pkg_root <- tryCatch(
    getNamespaceInfo("replicateEverything", "path"),
    error = function(e) ""
  )
  if (!nzchar(pkg_root)) {
    pkg_root <- tryCatch(system.file(package = "replicateEverything"), error = function(e) "")
  }
  shiny_root <- tryCatch(system.file("shiny", package = "replicateEverything"), error = function(e) "")
  starts <- unique(c(getwd(), pkg_root, shiny_root))
  starts <- starts[nzchar(starts)]
  for (study_name in study_names) {
    for (start in starts) {
      found <- walk_up_for_relative(start, file.path(study_name, "replication.yml"))
      if (!is.null(found)) {
        return(normalizePath(file.path(found, study_name), winslash = "/", mustWork = FALSE))
      }
    }
  }

  NULL
}

#' Detect whether input is a filesystem path to a study repository
#'
#' @param x Character scalar.
#' @return Logical scalar.
#' @keywords internal
is_study_path_query <- function(x) {
  if (is.null(x) || length(x) != 1L) {
    return(FALSE)
  }
  x <- trimws(as.character(x))
  if (!nzchar(x)) {
    return(FALSE)
  }
  if (grepl("^https?://", x, ignore.case = TRUE)) {
    return(FALSE)
  }
  if (grepl("^doi:", x, ignore.case = TRUE)) {
    return(FALSE)
  }
  if (grepl("\\\\", x)) {
    return(TRUE)
  }
  if (grepl("^[a-zA-Z]:", x)) {
    return(TRUE)
  }
  if (grepl("^~", x)) {
    return(TRUE)
  }
  if (grepl("^/", x)) {
    return(TRUE)
  }
  if (grepl("^\\./|^\\.\\.[/\\\\]", x)) {
    return(TRUE)
  }
  suppressWarnings(dir.exists(x))
}

#' Expand a study-path input for filesystem lookup
#'
#' @param path Character path.
#' @return Normalized path or \code{NULL}.
#' @keywords internal
expand_study_path_input <- function(path) {
  path <- trimws(as.character(path))
  if (!nzchar(path)) {
    return(NULL)
  }
  if (grepl("^~", path)) {
    path <- path.expand(path)
  }
  tryCatch(
    normalizePath(path, winslash = "/", mustWork = FALSE),
    error = function(e) NULL
  )
}

#' User-facing hint when a DOI or study-path lookup fails
#'
#' @param kind Failure kind: \code{path}, \code{cwd}, \code{empty}, \code{doi},
#'   \code{registry_bulk}, or \code{generic}.
#' @param path Optional path string entered by the user.
#' @param input Optional raw input string.
#' @return Multi-line character message.
#' @keywords internal
study_input_error_message <- function(
  kind = c("path", "cwd", "empty", "doi", "registry_bulk", "generic"),
  path = NULL,
  input = NULL
) {
  kind <- match.arg(kind)
  path_hint <- paste(
    "For a local study repo, enter the path to the folder that contains replication.yml.",
    "Use forward slashes; quote paths that contain spaces.",
    "  Windows: c:/Users/you/my_repo/  or  \"c:/typical path/my_repo/\"",
    "  macOS:   /Users/you/my_repo/  or  ~/my_repo/",
    sep = "\n"
  )
  doi_hint <- paste(
    "For a registered study, enter its DOI (with or without https://doi.org/).",
    "Check spelling against the Studies tab.",
    sep = " "
  )

  switch(
    kind,
    path = paste0(
      "Could not find replication.yml at that path",
      if (!is.null(path) && nzchar(path)) paste0(" (", path, ")") else "",
      ".\n\n",
      path_hint,
      "\n\nIf this study is already in the registry, try its DOI instead.\n",
      doi_hint
    ),
    cwd = paste0(
      "No replication.yml found in the working directory or its parent folders.\n\n",
      path_hint,
      "\n\n",
      doi_hint
    ),
    empty = paste0(
      "Enter a DOI or the path to a study repository folder.\n\n",
      doi_hint,
      "\n",
      path_hint
    ),
    doi = paste0(
      "Could not interpret \"",
      input %||% "",
      "\" as a DOI or study path.\n\n",
      doi_hint,
      "\n",
      path_hint
    ),
    registry_bulk = paste0(
      "Registry bulk install could not resolve this index row",
      if (!is.null(input) && nzchar(input)) {
        paste0(" (", input, ")")
      } else {
        ""
      },
      ".\n",
      "Blank or \"local\" input means \"study in getwd()\" and is not used for ",
      "install_registry_dependencies().\n",
      "Expected a DOI, handle, or registry folder slug from index.csv; ",
      "metadata is loaded from the registry stub and study GitHub repo.\n\n",
      doi_hint
    ),
    generic = paste0(doi_hint, "\n", path_hint)
  )
}

#' Hints when \code{check_replication()} cannot resolve a study location string
#'
#' Detects common DOI / registry-folder / repo-folder mashups (slashes, dashes,
#' underscores, missing \code{rep-} prefix) and lists accepted input forms.
#'
#' @param loc Raw location string from the user.
#' @return Character scalar (may be empty).
#' @keywords internal
study_location_input_hints <- function(loc) {
  loc <- trimws(as.character(loc %||% ""))
  if (!nzchar(loc)) {
    return("")
  }
  lines <- character(0)
  if (grepl("^10\\.", loc) && !grepl("/", loc, fixed = TRUE)) {
    if (grepl("-", loc, fixed = TRUE) && !grepl("^rep[-_]", loc)) {
      doi_guess <- sub("-", "/", loc, fixed = TRUE)
      repo_folder <- study_folder_from_doi(doi_guess)
      lines <- c(
        lines,
        paste0(
          "Looks like a repo-folder or DOI fragment (dash, no slash): \"", loc, "\"."
        ),
        paste0("  DOI (for run_replication): ", doi_guess),
        paste0("  Registry folder: ", gsub("/", "_", doi_guess, fixed = TRUE)),
        paste0("  Study repo folder: ", repo_folder),
        paste0("  GitHub slug: replicate-anything/", repo_folder)
      )
    } else if (grepl("_", loc, fixed = TRUE)) {
      doi_guess <- gsub("_", "/", loc, fixed = TRUE)
      repo_folder <- study_folder_from_doi(doi_guess)
      lines <- c(
        lines,
        paste0("Looks like a registry folder (underscore): \"", loc, "\"."),
        paste0("  check_replication() needs a path or GitHub slug, not the registry folder."),
        paste0("  Try path: ", repo_folder, "  (from monorepo root)"),
        paste0("  Or GitHub: replicate-anything/", repo_folder)
      )
    }
  } else if (grepl("^rep[-_]", loc) && !dir.exists(loc)) {
    lines <- c(
      lines,
      paste0("Looks like a study-repo folder name: \"", loc, "\"."),
      "Pass the full or monorepo-relative path to that folder, or org/repo on GitHub.",
      paste0("  Example: replicate-anything/", loc)
    )
  } else if (grepl("^10\\..*/", loc)) {
    repo_folder <- study_folder_from_doi(loc)
    lines <- c(
      lines,
      paste0("For validation, pass the study path or GitHub slug (", repo_folder, "),"),
      paste0("or call configure_local_monorepo() and pass the DOI: ", normalize_doi(loc), "."),
      paste0("For execution, use run_replication(\"", normalize_doi(loc), "\", ...).")
    )
  }
  if (length(lines) == 0L) {
    lines <- c(
      "Accepted forms:",
      "  - Path to folder containing replication.yml",
      "  - GitHub URL or org/repo slug (e.g. replicate-anything/rep-10.1017-s...)",
      "  - DOI works with run_replication(), not check_replication()"
    )
  } else {
    lines <- c(lines, "Call configure_local_monorepo() once per session for sibling discovery.")
  }
  paste0("\n", paste(lines, collapse = "\n"))
}

#' Message when GitHub clone fails but a local sibling may exist
#'
#' @param slug GitHub \code{org/repo} slug that was cloned.
#' @param loc Original location string from the user.
#' @return Character scalar error message.
#' @keywords internal
study_location_clone_failure_message <- function(slug, loc = slug) {
  base <- paste0("Failed to clone study repository: ", slug)
  local <- try_resolve_study_by_common_alias(loc)
  if (is.null(local) && looks_like_doi_location(loc)) {
    local <- resolve_local_study_folder(normalize_doi(loc))
  }
  if (is.null(local)) {
    return(base)
  }
  paste0(
    base,
    ".\nLocal sibling study found at: ", local,
    "\nPass that path to check_replication(), or call configure_local_monorepo() ",
    "so DOI lookup uses local folders instead of GitHub."
  )
}

#' Resolve a local study root from a registry folder name
#'
#' Reads the registry stub (or index row) for \code{loc} and resolves
#' \code{paper.study_folder} / repo slug siblings under the monorepo.
#'
#' @param loc Registry folder name such as \code{10.5555_cahw}.
#' @return Normalized study path or \code{NULL}.
#' @keywords internal
try_resolve_study_from_registry_folder <- function(loc) {
  loc <- trimws(as.character(loc %||% ""))
  if (!nzchar(loc)) {
    return(NULL)
  }

  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }

  study_names <- character(0)
  stub <- if (!is.null(registry_root)) {
    read_registry_stub_yaml(loc, registry_root = registry_root)
  } else {
    NULL
  }
  if (!is.null(stub)) {
    study_names <- c(study_names, study_folder_candidates(stub, list(folder = loc)))
  }

  idx <- tryCatch(load_index(), error = function(e) NULL)
  if (!is.null(idx) && "folder" %in% names(idx)) {
    row <- idx[idx$folder == loc, , drop = FALSE]
    if (nrow(row) > 0L && "repo" %in% names(row)) {
      repo_slug <- as.character(row$repo[[1]] %||% "")
      if (nzchar(repo_slug)) {
        study_names <- c(study_names, basename(repo_slug))
      }
    }
  }

  study_names <- unique(study_names[nzchar(study_names)])
  for (name in study_names) {
    if (dir.exists(name) && file.exists(file.path(name, "replication.yml"))) {
      return(normalizePath(name, winslash = "/", mustWork = FALSE))
    }
    local <- resolve_local_study_folder(name)
    if (!is.null(local)) {
      return(local)
    }
  }

  NULL
}

#' Whether a location string looks like a study alias, not an R package name
#'
#' @param x Character scalar.
#' @return Logical scalar.
#' @keywords internal
looks_like_study_alias <- function(x) {
  if (is.null(x) || length(x) != 1L) {
    return(FALSE)
  }
  x <- trimws(as.character(x))
  if (!nzchar(x)) {
    return(FALSE)
  }
  grepl("^10\\.", x, perl = TRUE) ||
    grepl("^rep[-_]", x) ||
    grepl("_", x, fixed = TRUE) ||
    grepl("--", x, fixed = TRUE)
}

#' Resolve a study root from common alias strings (DOI, registry folder, rep- slug)
#'
#' @param loc Trimmed location string.
#' @return Normalized study path or \code{NULL}.
#' @keywords internal
try_resolve_study_by_common_alias <- function(loc) {
  loc <- trimws(as.character(loc %||% ""))
  if (!nzchar(loc)) {
    return(NULL)
  }
  candidates <- character(0)
  if (grepl("^rep[-_]", loc)) {
    candidates <- c(candidates, loc)
  }
  if (grepl("^10\\.", loc)) {
    if (grepl("/", loc, fixed = TRUE)) {
      candidates <- c(candidates, study_folder_from_doi(loc))
    } else if (grepl("_", loc, fixed = TRUE)) {
      candidates <- c(candidates, study_folder_from_doi(gsub("_", "/", loc, fixed = TRUE)))
    } else if (grepl("-", loc, fixed = TRUE)) {
      candidates <- c(candidates, paste0("rep-", loc))
    }
  }
  candidates <- unique(candidates[nzchar(candidates)])
  for (name in candidates) {
    if (dir.exists(name) && file.exists(file.path(name, "replication.yml"))) {
      return(normalizePath(name, winslash = "/", mustWork = FALSE))
    }
    local <- resolve_local_study_folder(name)
    if (!is.null(local)) {
      return(local)
    }
  }
  try_resolve_study_from_registry_folder(loc)
}

register_local_study_from_root <- function(local_root) {
  meta <- read_study_replication_yaml(local_root)
  if (is.null(meta)) {
    stop("Local replication.yml not found.", call. = FALSE)
  }
  paper <- meta$paper %||% list()
  doi_raw <- paper$doi %||% NULL
  if (!is.null(doi_raw) && nzchar(as.character(doi_raw[[1]] %||% doi_raw))) {
    doi_out <- normalize_doi(doi_raw)
  } else {
    handle <- paper$study_handle %||% basename(local_root)
    doi_out <- as.character(handle[[1]] %||% handle)
  }
  configure_study_folder(doi_out, local_root)
  list(doi = doi_out, local_root = local_root, is_local = TRUE)
}

#' Detect whether a DOI argument requests the local working-directory study
#'
#' @param doi Character. Use \code{""}, \code{"local"}, or \code{"."}.
#' @return Logical scalar.
#' @keywords internal
is_local_doi_query <- function(doi) {
  if (is.null(doi) || length(doi) != 1L) {
    return(FALSE)
  }
  x <- tolower(trimws(as.character(doi)))
  x %in% c("", "local", ".")
}

#' Find a folder-backed study root containing \code{replication.yml}
#'
#' Walks up from \code{location} (default working directory).
#'
#' @param location Directory to start from.
#' @return Normalized study root or \code{NULL}.
#' @keywords internal
find_local_study_root <- function(location = getwd()) {
  if (is.null(location) || length(location) != 1L || is.na(location) || !nzchar(location)) {
    return(NULL)
  }
  dir <- tryCatch(
    normalizePath(location, winslash = "/", mustWork = FALSE),
    error = function(e) NULL
  )
  if (is.null(dir) || !dir.exists(dir)) {
    return(NULL)
  }
  if (file.exists(file.path(dir, "replication.yml"))) {
    return(dir)
  }
  found <- walk_up_for_relative(dir, "replication.yml")
  if (is.null(found)) {
    return(NULL)
  }
  normalizePath(found, winslash = "/", mustWork = FALSE)
}

#' Resolve a DOI or local study query into a canonical DOI
#'
#' When \code{doi} is blank or \code{"local"}, searches for
#' \code{replication.yml} from the working directory upward. When \code{doi} is a
#' filesystem path, searches that folder (and parents). When a matching local
#' study is found, registers it via \code{\link{configure_study_folder}}.
#'
#' @param doi Character DOI, DOI URL, study-repo path, \code{"local"}, or blank.
#' @param location Directory to search for a local study (default \code{getwd()}).
#' @param allow_local When \code{FALSE}, never treat blank/\code{local}/\code{.}
#'   as a working-directory study (used by [install_registry_dependencies()]).
#' @return A list with \code{doi}, \code{local_root}, and \code{is_local}.
#' @keywords internal
resolve_doi_input <- function(
  doi = NULL,
  location = getwd(),
  allow_local = TRUE
) {
  raw <- trimws(as.character(doi %||% ""))

  if (is_study_path_query(raw)) {
    if (!isTRUE(allow_local)) {
      stop(study_input_error_message("registry_bulk", input = raw), call. = FALSE)
    }
    path_root <- expand_study_path_input(raw)
    local_root <- if (!is.null(path_root)) {
      find_local_study_root(path_root)
    } else {
      NULL
    }
    if (is.null(local_root)) {
      stop(study_input_error_message("path", path = raw), call. = FALSE)
    }
    return(register_local_study_from_root(local_root))
  }

  local_root <- if (isTRUE(allow_local)) {
    find_local_study_root(location)
  } else {
    NULL
  }

  if (is_local_doi_query(raw)) {
    if (!isTRUE(allow_local) || is.null(local_root)) {
      stop(
        if (isTRUE(allow_local)) {
          study_input_error_message("cwd")
        } else {
          study_input_error_message("registry_bulk", input = raw)
        },
        call. = FALSE
      )
    }
    return(register_local_study_from_root(local_root))
  }

  if (!nzchar(raw)) {
    stop(
      if (isTRUE(allow_local)) {
        study_input_error_message("empty")
      } else {
        study_input_error_message("registry_bulk")
      },
      call. = FALSE
    )
  }

  handle_doi <- resolve_registry_handle(raw)
  if (!is.null(handle_doi)) {
    raw <- handle_doi
  }

  doi_out <- normalize_doi(raw)
  if (isTRUE(allow_local)) {
    local_sibling <- resolve_local_study_folder(doi_out)
    if (!is.null(local_sibling)) {
      return(register_local_study_from_root(local_sibling))
    }
    if (!is.null(local_root)) {
      meta <- read_study_replication_yaml(local_root)
      if (!is.null(meta) && !is.null(meta$paper$doi)) {
        local_doi <- normalize_doi(meta$paper$doi)
        if (identical(local_doi, doi_out)) {
          configure_study_folder(doi_out, local_root)
          return(list(doi = doi_out, local_root = local_root, is_local = FALSE))
        }
      }
    }
  }

  list(doi = doi_out, local_root = NULL, is_local = FALSE)
}

#' Prepare a DOI for replication API calls
#'
#' Wrapper around \code{\link{resolve_doi_input}} that returns the canonical DOI.
#'
#' @inheritParams resolve_doi_input
#' @return Character DOI.
#' @keywords internal
prepare_doi_for_replication <- function(
  doi,
  location = getwd(),
  allow_local = TRUE
) {
  resolve_doi_input(doi, location = location, allow_local = allow_local)$doi
}

#' Configure options for a local replicate-anything monorepo
#'
#' Sets \code{replicateEverything.registry_root},
#' \code{replicateEverything.study_folders_root}, and enables sibling study
#' discovery. Call once per session when developing unpublished studies locally.
#'
#' @param root Monorepo root containing \code{registry/} and \code{rep-*} study
#'   folders. When \code{NULL}, attempts \code{auto_detect_monorepo_root()}.
#' @return Invisibly, the monorepo root path.
#' @export
configure_local_monorepo <- function(root = NULL) {
  if (is.null(root) || !dir.exists(root)) {
    root <- auto_detect_monorepo_root()
  }
  if (is.null(root) || !dir.exists(root)) {
    stop(
      "Could not find a local monorepo (expected registry/index.csv). ",
      "Pass root = to your replicate_everything checkout, e.g.\n",
      "  configure_local_monorepo(\"c:/path/to/replicate_everything\")",
      call. = FALSE
    )
  }
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  registry_root <- file.path(root, "registry")
  if (!file.exists(file.path(registry_root, "index.csv"))) {
    stop("No registry/index.csv under ", root, call. = FALSE)
  }
  options(
    replicateEverything.registry_root = registry_root,
    replicateEverything.study_folders_root = root,
    replicateEverything.use_sibling_packages = TRUE
  )
  invisible(root)
}

#' Detect a local registry checkout
#'
#' Uses \code{getOption("replicateEverything.registry_root")} or a sibling
#' \code{registry/} folder in an auto-detected monorepo.
#'
#' @return Normalized path or \code{NULL}.
#' @keywords internal
auto_detect_registry_root <- function() {
  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (!is.null(registry_root) && dir.exists(registry_root)) {
    return(normalizePath(registry_root, winslash = "/", mustWork = FALSE))
  }

  monorepo <- auto_detect_monorepo_root()
  if (!is.null(monorepo)) {
    candidate <- file.path(monorepo, "registry")
    if (dir.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    }
  }

  NULL
}


#' Whether replication metadata refers to a folder-backed external study repo
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Optional paper context list with \code{repo} and \code{folder}.
#' @return Logical.
#' @keywords internal
is_folder_study_replication <- function(meta, ctx = NULL) {
  if (is_package_replication(meta)) {
    return(FALSE)
  }
  layout <- meta$paper$materials %||% meta$materials %||% NULL
  if (!is.null(layout) && identical(as.character(layout[[1]]), "folder")) {
    return(TRUE)
  }
  slug <- study_repo_slug(meta, ctx)
  !identical(slug, DEFAULT_REGISTRY_REPO) && nzchar(slug)
}

#' Resolve GitHub repo slug for a folder-backed study
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character repo slug.
#' @keywords internal
study_repo_slug <- function(meta, ctx = NULL) {
  from_meta <- meta$repo %||% meta$paper$study_repo %||% NULL
  if (!is.null(from_meta) && nzchar(as.character(from_meta[[1]]))) {
    return(as.character(from_meta[[1]]))
  }
  if (!is.null(ctx) && !is.null(ctx$repo) && nzchar(ctx$repo)) {
    return(ctx$repo)
  }
  DEFAULT_REGISTRY_REPO
}

#' Git ref for folder-backed study materials
#'
#' @param meta Parsed replication.yml contents.
#' @return Character branch, tag, or commit.
#' @keywords internal
study_repo_ref <- function(meta) {
  ref <- meta$paper$study_ref %||% meta$study_ref %||% "main"
  as.character(ref[[1]])
}

#' URLs for \code{replication.yml} in a folder-backed study repo
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
folder_study_yaml_urls <- function(repo, ref = "main") {
  sprintf("https://raw.githubusercontent.com/%s/%s/replication.yml", repo, ref)
}

#' Fetch replication metadata from a folder-backed study repository
#'
#' @param meta Parsed registry stub.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Parsed yaml list or \code{NULL}.
#' @keywords internal
fetch_folder_study_replication_yaml <- function(meta, ctx = NULL) {
  if (!is.null(ctx) && !is.null(ctx$local_root)) {
    local_yml <- file.path(ctx$local_root, "replication.yml")
    if (file.exists(local_yml)) {
      return(tryCatch(yaml::read_yaml(local_yml), error = function(e) NULL))
    }
  }

  local_path <- resolve_study_folder_path(meta, ctx)
  if (!is.null(local_path)) {
    local_yml <- file.path(local_path, "replication.yml")
    if (file.exists(local_yml)) {
      return(tryCatch(yaml::read_yaml(local_yml), error = function(e) NULL))
    }
  }

  repo <- study_repo_slug(meta, ctx)
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    return(NULL)
  }
  if (identical(repo, DEFAULT_REGISTRY_REPO)) {
    return(NULL)
  }
  ref <- study_repo_ref(meta)
  for (meta_url in folder_study_yaml_urls(repo, ref)) {
    parsed <- read_yaml_url(meta_url)
    if (!is.null(parsed)) {
      return(parsed)
    }
  }
  NULL
}

#' Merge study-repo fields into registry stub metadata
#'
#' Registry stubs omit \code{replications}, \code{stata_deps_probe}, and related
#' study-repo-only fields. Overlay them from the folder-backed study yaml.
#'
#' @param meta Parsed metadata (often a registry stub).
#' @param study_meta Full \code{replication.yml} from the study repo.
#' @return Updated \code{meta} list.
#' @keywords internal
merge_folder_study_meta_fields <- function(meta, study_meta) {
  paper_field_empty <- function(val) {
    if (is.null(val) || length(val) == 0L) {
      return(TRUE)
    }
    if (is.list(val) && !is.null(names(val)) && length(names(val)) > 0L) {
      return(FALSE)
    }
    if (is.list(val)) {
      return(length(val) == 0L)
    }
    chr <- as.character(unlist(val, use.names = FALSE))
    chr <- chr[!is.na(chr)]
    length(chr) == 0L || all(!nzchar(chr))
  }

  if (length(meta$steps %||% list()) == 0L) {
    meta$steps <- study_meta$steps %||% list()
  }
  if (is.null(meta$paper)) {
    meta$paper <- list()
  }
  if (length(meta$paper$dependencies %||% list()) == 0L) {
    meta$paper$dependencies <- study_meta$paper$dependencies %||% list()
  }
  if (length(meta$paper$languages %||% list()) == 0L) {
    meta$paper$languages <- study_meta$paper$languages %||% list()
  }
  if (length(meta$paper$python_dependencies %||% list()) == 0L) {
    meta$paper$python_dependencies <- study_meta$paper$python_dependencies %||% list()
  }
  for (field in c(
    "package",
    "package_repo",
    "package_folder",
    "package_ref",
    "source_repo",
    "study_handle",
    "study_url",
    "abstract",
    "related",
    "title",
    "authors",
    "year",
    "journal"
  )) {
    val <- meta$paper[[field]] %||% NULL
    study_val <- study_meta$paper[[field]] %||% NULL
    if (paper_field_empty(val) && !is.null(study_val) && length(study_val) > 0L) {
      meta$paper[[field]] <- study_val
    }
  }
  if (is.null(meta$paper$extends) || length(meta$paper$extends) == 0L) {
    study_ext <- study_meta$paper$extends %||% study_meta$extends %||% NULL
    if (!is.null(study_ext) && length(study_ext) > 0L) {
      meta$paper$extends <- study_ext
    }
  }
  if (is.null(meta$extends) || length(meta$extends) == 0L) {
    meta$extends <- study_meta$extends %||% study_meta$paper$extends %||% meta$extends
  }
  for (field in c(
    "languages",
    "python_dependencies",
    "r_dependencies",
    "stata_deps_probe",
    "stata_dependencies",
    "stata_packages"
  )) {
    val <- meta[[field]] %||% NULL
    if (is.null(val) || length(val) == 0L) {
      study_val <- study_meta[[field]] %||% NULL
      if (!is.null(study_val) && length(study_val) > 0L) {
        meta[[field]] <- study_val
      }
    }
  }
  repo <- meta$repo %||% NULL
  if (is.null(repo) || length(repo) == 0L || !nzchar(as.character(repo[[1]]))) {
    meta$repo <- study_meta$repo %||% repo
  }
  meta
}

#' Fill study-repo fields using a materialized local \code{replication.yml}
#'
#' @param meta Parsed metadata passed to Stata dependency helpers.
#' @param study_root Local study repository root.
#' @return Updated \code{meta} list.
#' @keywords internal
complete_folder_study_meta <- function(meta, study_root = NULL) {
  if (is.null(meta) || is.null(study_root) || !nzchar(study_root)) {
    return(meta)
  }
  local_yml <- file.path(study_root, "replication.yml")
  if (!file.exists(local_yml)) {
    return(meta)
  }
  study_meta <- tryCatch(yaml::read_yaml(local_yml), error = function(e) NULL)
  if (is.null(study_meta)) {
    return(meta)
  }
  merge_folder_study_meta_fields(meta, study_meta)
}

#' Merge replication entries from a folder-backed study repo into a registry stub
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Updated metadata list.
#' @keywords internal
enrich_folder_study_replication_meta <- function(meta, ctx) {
  if (!is_folder_study_replication(meta, ctx)) {
    return(meta)
  }

  study_meta <- fetch_folder_study_replication_yaml(meta, ctx)
  if (is.null(study_meta)) {
    return(meta)
  }

  merge_folder_study_meta_fields(meta, study_meta)
}

#' Folder names to check when locating a sibling folder-backed study repo
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character vector of folder names (no duplicates).
#' @keywords internal
study_folder_candidates <- function(meta, ctx = NULL) {
  explicit <- c(
    meta$paper$study_folder %||% NULL,
    meta$paper$study_path %||% NULL,
    meta$study_folder %||% NULL
  )
  explicit <- vapply(explicit, function(x) {
    if (is.null(x)) {
      return("")
    }
    path <- as.character(x[[1]])
    if (dir.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
    as.character(x[[1]])
  }, character(1))
  explicit <- explicit[nzchar(explicit)]

  repo_slug <- study_repo_slug(meta, ctx)
  derived <- character(0)
  if (nzchar(repo_slug)) {
    derived <- c(derived, basename(repo_slug))
  }
  paper_doi <- meta$paper$doi %||% NULL
  if (!is.null(paper_doi) && length(paper_doi) > 0L && nzchar(as.character(paper_doi[[1]]))) {
    derived <- c(derived, study_folder_from_doi(as.character(paper_doi[[1]])))
  }
  paper_handle <- meta$paper$study_handle %||% NULL
  if (!is.null(paper_handle) && length(paper_handle) > 0L && nzchar(as.character(paper_handle[[1]]))) {
    derived <- c(derived, as.character(paper_handle[[1]]))
  }

  unique(c(explicit, derived))
}

#' Candidate keys for \code{replicateEverything.study_folders} lookups
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character vector of non-empty keys (no duplicates).
#' @keywords internal
study_folder_map_keys <- function(meta, ctx = NULL) {
  keys <- character(0)
  if (!is.null(ctx) && is.list(ctx) && !is.null(ctx$folder) && nzchar(ctx$folder)) {
    keys <- c(keys, as.character(ctx$folder))
  }
  doi <- NULL
  if (!is.null(meta$paper$doi) && length(meta$paper$doi) > 0L) {
    doi <- normalize_doi(as.character(meta$paper$doi[[1]]))
  } else if (!is.null(ctx) && is.list(ctx) && !is.null(ctx$doi) && nzchar(ctx$doi)) {
    doi <- normalize_doi(as.character(ctx$doi))
  }
  if (!is.null(doi) && nzchar(doi)) {
    keys <- c(keys, gsub("/", "_", doi, fixed = TRUE), study_folder_from_doi(doi))
  }
  paper_handle <- meta$paper$study_handle %||% NULL
  if (!is.null(paper_handle) && length(paper_handle) > 0L) {
    handle_val <- as.character(paper_handle[[1]] %||% paper_handle)
    if (nzchar(handle_val)) {
      keys <- c(keys, handle_val, tolower(handle_val))
    }
  }
  study_name <- c(
    meta$paper$study_folder %||% NULL,
    meta$study_folder %||% NULL
  )
  for (item in study_name) {
    if (!is.null(item) && length(item) > 0L) {
      value <- as.character(item[[1]])
      if (nzchar(value)) {
        keys <- c(keys, value)
      }
    }
  }
  slug <- study_repo_slug(meta, ctx)
  if (length(slug) == 1L && !is.na(slug) && nzchar(slug)) {
    keys <- c(keys, basename(slug))
  }
  unique(keys[nzchar(keys)])
}

#' Resolve a path from \code{replicateEverything.study_folders}
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Normalized path, or \code{NULL}.
#' @keywords internal
lookup_study_folders_option <- function(meta, ctx = NULL) {
  folder_map <- getOption("replicateEverything.study_folders", NULL)
  if (is.null(folder_map) || length(folder_map) == 0L) {
    return(NULL)
  }
  keys <- study_folder_map_keys(meta, ctx)
  for (key in keys) {
    if (is.null(folder_map[[key]])) {
      next
    }
    path <- as.character(folder_map[[key]][[1]] %||% folder_map[[key]])
    if (!nzchar(path)) {
      next
    }
    marker <- file.path(path, "replication.yml")
    if (dir.exists(path) && file.exists(marker)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' Whether \code{study_folders} includes an entry for this study
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @keywords internal
study_folders_configured <- function(meta, ctx = NULL) {
  folder_map <- getOption("replicateEverything.study_folders", NULL)
  if (is.null(folder_map) || length(folder_map) == 0L) {
    return(FALSE)
  }
  keys <- study_folder_map_keys(meta, ctx)
  any(keys %in% names(folder_map))
}

#' Register a server-local study folder for a DOI
#'
#' Sets \code{replicateEverything.study_folders} under every alias the package
#' uses for lookups (registry folder name, \code{rep-<doi>}, etc.).
#'
#' @param doi Character DOI.
#' @param path Absolute path to the study root (must contain \code{replication.yml}).
#' @return Invisibly, the normalized path.
#' @keywords internal
configure_study_folder <- function(doi, path) {
  doi <- normalize_doi(doi)
  if (length(path) != 1L || is.na(path) || !nzchar(path)) {
    stop("Study path must be a non-empty string.", call. = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Study folder does not exist: ", path, call. = FALSE)
  }
  marker <- file.path(path, "replication.yml")
  if (!file.exists(marker)) {
    stop("Study folder missing replication.yml: ", path, call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  stub <- list(paper = list(doi = doi))
  ctx <- list(doi = doi, folder = resolve_paper_path(doi))
  keys <- study_folder_map_keys(stub, ctx)
  map <- getOption("replicateEverything.study_folders", list())
  for (key in keys) {
    map[[key]] <- path
  }
  options(replicateEverything.study_folders = map)
  invisible(path)
}

#' Resolve a local path to a folder-backed study repository
#'
#' Search order mirrors package sibling resolution:
#' explicit \code{paper.study_path}, option map, then sibling monorepo folders.
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Normalized path, or \code{NULL}.
#' @keywords internal
resolve_study_folder_path <- function(meta, ctx = NULL) {
  mapped <- lookup_study_folders_option(meta, ctx)
  if (!is.null(mapped)) {
    return(mapped)
  }

  candidates <- study_folder_candidates(meta, ctx)
  for (path in candidates) {
    if (dir.exists(path) && file.exists(file.path(path, "replication.yml"))) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  if (!sibling_packages_enabled()) {
    return(NULL)
  }

  roots <- c(
    getOption("replicateEverything.study_folders_root", NULL),
    getOption("replicateEverything.replication_packages_root", NULL),
    sibling_monorepo_root()
  )
  roots <- unique(roots[!vapply(roots, is.null, logical(1))])
  roots <- roots[dir.exists(roots)]

  folder_names <- candidates[!dir.exists(candidates)]
  for (root in roots) {
    for (folder in folder_names) {
      candidate <- file.path(root, folder)
      if (dir.exists(candidate) && file.exists(file.path(candidate, "replication.yml"))) {
        return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
      }
    }
  }

  NULL
}

#' Default directory for cached GitHub study checkouts
#'
#' @return Normalized path.
#' @keywords internal
default_study_cache_root <- function() {
  tryCatch(
    file.path(tools::R_user_dir("replicateEverything", which = "cache"), "study-repos"),
    error = function(e) {
      file.path(tempdir(), "replicateEverything-study-cache")
    }
  )
}

#' GitHub archive URL for a folder-backed study repository
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
study_repo_archive_url <- function(repo, ref = "main") {
  sprintf("https://github.com/%s/archive/%s.zip", repo, ref)
}

#' Move or copy a directory to a destination path
#'
#' @param from Source directory.
#' @param to Destination directory.
#' @keywords internal
move_directory <- function(from, to) {
  if (dir.exists(to)) {
    unlink(to, recursive = TRUE)
  }
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  # rename is atomic on the same filesystem; across devices (e.g. /tmp -> NFS
  # cache) it fails with EXDEV and emits a warning — fall back to copy+delete.
  renamed <- suppressWarnings(file.rename(from, to))
  if (isTRUE(renamed)) {
    return(invisible(TRUE))
  }
  if (!file.copy(from, to, recursive = TRUE, copy.mode = TRUE)) {
    stop("Failed to copy study repository into cache.", call. = FALSE)
  }
  unlink(from, recursive = TRUE)
  invisible(TRUE)
}

#' Download and cache a folder-backed study repository from GitHub
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @return Normalized path to cached study root.
#' @keywords internal
materialize_folder_study_from_github <- function(repo, ref = "main") {
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    stop("Study repository slug is missing.", call. = FALSE)
  }
  if (identical(repo, DEFAULT_REGISTRY_REPO)) {
    stop("Folder-backed study repository slug is invalid.", call. = FALSE)
  }
  ref <- as.character(ref[[1]] %||% ref)
  if (!nzchar(ref)) {
    ref <- "main"
  }

  cache_root <- getOption("replicateEverything.study_cache_root", default_study_cache_root())
  safe_repo <- gsub("[^a-zA-Z0-9._-]", "_", repo)
  safe_ref <- gsub("[^a-zA-Z0-9._-]", "_", ref)
  cache_dir <- file.path(cache_root, safe_repo, safe_ref)
  marker <- file.path(cache_dir, "replication.yml")
  sha_file <- file.path(cache_dir, ".replicate_ref_sha")
  cache_key <- paste0(safe_repo, "@", safe_ref)

  if (file.exists(marker)) {
    # A single live Run resolves the study folder several times (prep, table,
    # format). Once we have confirmed this study's cache is fresh, skip the
    # remote check for a short window so we do not re-hit the GitHub API for
    # the same repo repeatedly. Controlled by
    # options(replicateEverything.study_cache_ttl = <seconds>); 0 disables.
    if (study_cache_recently_verified(cache_key)) {
      return(normalizePath(cache_dir, winslash = "/", mustWork = FALSE))
    }
    remote_sha <- github_ref_sha(repo, ref)
    cached_sha <- if (file.exists(sha_file)) {
      trimws(readLines(sha_file, warn = FALSE, n = 1L)[1])
    } else {
      NA_character_
    }
    # Reuse the cache when we cannot check the remote (offline / rate-limited)
    # or when the cached checkout already matches the current remote commit.
    # Otherwise the cache is stale (e.g. built before new data was committed);
    # drop it so we re-download the current tree.
    reusable <- is.na(remote_sha) ||
      (!is.na(cached_sha) && nzchar(cached_sha) && identical(cached_sha, remote_sha))
    if (reusable) {
      mark_study_cache_verified(cache_key)
      return(normalizePath(cache_dir, winslash = "/", mustWork = FALSE))
    }
    unlink(cache_dir, recursive = TRUE)
  } else {
    remote_sha <- github_ref_sha(repo, ref)
  }

  dir.create(cache_root, recursive = TRUE, showWarnings = FALSE)
  zip_url <- study_repo_archive_url(repo, ref)
  zip_file <- download_registry_file(zip_url)
  # Unzip on the same filesystem as the cache so rename into cache_dir is
  # atomic when possible (/tmp on another mount causes EXDEV on Linux servers).
  unzip_scratch <- file.path(cache_root, ".unzip-tmp")
  dir.create(unzip_scratch, recursive = TRUE, showWarnings = FALSE)
  unzip_parent <- tempfile("study-unzip-", tmpdir = unzip_scratch)
  dir.create(unzip_parent)
  on.exit(unlink(unzip_parent, recursive = TRUE), add = TRUE)
  utils::unzip(zip_file, exdir = unzip_parent)
  subs <- list.dirs(unzip_parent, full.names = TRUE, recursive = FALSE)
  if (length(subs) != 1L) {
    stop(
      "Unexpected GitHub archive layout for study repo ", repo, ".",
      call. = FALSE
    )
  }
  move_directory(subs[[1]], cache_dir)
  if (!file.exists(marker)) {
    stop(
      "Downloaded study repo is missing replication.yml: ", repo, ".",
      call. = FALSE
    )
  }
  if (!is.na(remote_sha) && nzchar(remote_sha)) {
    tryCatch(
      writeLines(remote_sha, sha_file),
      error = function(e) NULL
    )
  }
  mark_study_cache_verified(cache_key)
  normalizePath(cache_dir, winslash = "/", mustWork = FALSE)
}

# Session-scoped record of study caches confirmed fresh, so repeated study
# folder resolutions within one run do not each trigger a GitHub API call.
.study_cache_verified <- new.env(parent = emptyenv())

#' Seconds a study-cache freshness check stays valid within a session
#'
#' Configurable via \code{options(replicateEverything.study_cache_ttl)}. A value
#' of \code{0} disables the session skip so every resolution re-checks the
#' remote.
#'
#' @return Numeric seconds (defaults to 300).
#' @keywords internal
study_cache_ttl_seconds <- function() {
  val <- suppressWarnings(
    as.numeric(getOption("replicateEverything.study_cache_ttl", 300))[1]
  )
  if (length(val) != 1L || is.na(val) || val < 0) {
    return(300)
  }
  val
}

#' Whether a study cache was confirmed fresh within the session TTL
#'
#' @param cache_key Character key \code{"<safe_repo>@<safe_ref>"}.
#' @return Logical scalar.
#' @keywords internal
study_cache_recently_verified <- function(cache_key) {
  ttl <- study_cache_ttl_seconds()
  if (ttl <= 0) {
    return(FALSE)
  }
  last <- .study_cache_verified[[cache_key]]
  if (is.null(last)) {
    return(FALSE)
  }
  as.numeric(Sys.time() - last, units = "secs") < ttl
}

#' Record that a study cache was just confirmed fresh
#'
#' @param cache_key Character key \code{"<safe_repo>@<safe_ref>"}.
#' @return Invisibly \code{NULL}.
#' @keywords internal
mark_study_cache_verified <- function(cache_key) {
  assign(cache_key, Sys.time(), envir = .study_cache_verified)
  invisible(NULL)
}

#' Current commit SHA for a GitHub repository ref
#'
#' Queries the GitHub API for the commit SHA of \code{ref}. Used to decide
#' whether a cached study checkout is stale. Returns \code{NA_character_} when
#' the SHA cannot be determined (offline, rate-limited, or missing ref), in
#' which case callers keep any existing cache rather than failing.
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @return Character SHA or \code{NA_character_}.
#' @keywords internal
github_ref_sha <- function(repo, ref = "main") {
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    return(NA_character_)
  }
  url <- sprintf("https://api.github.com/repos/%s/commits/%s", repo, ref)
  resp <- tryCatch(
    httr::GET(
      url,
      httr::add_headers(Accept = "application/vnd.github.sha"),
      httr::user_agent("replicateEverything"),
      httr::timeout(15)
    ),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) >= 400L) {
    return(NA_character_)
  }
  sha <- tryCatch(
    trimws(httr::content(resp, as = "text", encoding = "UTF-8")),
    error = function(e) ""
  )
  if (length(sha) != 1L || !nzchar(sha) || grepl("\\s", sha)) {
    return(NA_character_)
  }
  sha
}

#' Ensure a folder-backed study is available on local disk
#'
#' Search order: explicit paths and sibling folders, optional
#' \code{replicateEverything.study_folders} map, then GitHub archive cache.
#'
#' @param meta Parsed registry or study metadata.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Normalized study root, or \code{NULL}.
#' @keywords internal
ensure_study_folder_local <- function(meta, ctx = NULL) {
  path <- resolve_study_folder_path(meta, ctx)
  if (!is.null(path)) {
    return(path)
  }

  if (study_folders_configured(meta, ctx)) {
    folder_map <- getOption("replicateEverything.study_folders", NULL)
    keys <- study_folder_map_keys(meta, ctx)
    configured <- keys[keys %in% names(folder_map)]
    paths <- vapply(configured, function(key) {
      as.character(folder_map[[key]][[1]] %||% folder_map[[key]])
    }, character(1))
    stop(
      "replicateEverything.study_folders is set for this study but the path could not be used.\n",
      "Keys checked: ", paste(configured, collapse = ", "), "\n",
      "Configured paths:\n  ", paste(paths, collapse = "\n  "), "\n",
      "Each path must exist and contain replication.yml. ",
      "Use configure_study_folder(doi, path) to register all aliases.",
      call. = FALSE
    )
  }

  paper_doi <- meta$paper$doi %||% NULL
  if (is.null(paper_doi) && !is.null(ctx) && !is.null(ctx$doi)) {
    paper_doi <- ctx$doi
  }

  if (!is.null(paper_doi) && length(paper_doi) > 0L && nzchar(as.character(paper_doi[[1]]))) {
    local <- resolve_local_study_folder(normalize_doi(as.character(paper_doi[[1]])))
    if (!is.null(local)) {
      return(local)
    }
  }

  if (!is.null(ctx) && !is.null(ctx$local_root) && dir.exists(ctx$local_root)) {
    marker <- file.path(ctx$local_root, "replication.yml")
    if (file.exists(marker)) {
      cached <- normalizePath(ctx$local_root, winslash = "/", mustWork = FALSE)
      if (!is.null(paper_doi) && length(paper_doi) > 0L && nzchar(as.character(paper_doi[[1]]))) {
        sibling <- resolve_local_study_folder(normalize_doi(as.character(paper_doi[[1]])))
        if (!is.null(sibling)) {
          sibling_norm <- normalizePath(sibling, winslash = "/", mustWork = FALSE)
          if (!identical(cached, sibling_norm)) {
            return(sibling_norm)
          }
        }
      }
      return(cached)
    }
  }

  is_folder <- if (!is.null(ctx)) {
    isTRUE(ctx$is_folder_study)
  } else {
    is_folder_study_replication(meta, ctx)
  }
  if (!is_folder) {
    return(NULL)
  }

  repo <- study_repo_slug(meta, ctx)
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    return(NULL)
  }
  if (identical(repo, DEFAULT_REGISTRY_REPO)) {
    return(NULL)
  }

  ref <- study_repo_ref(meta)
  tryCatch(
    materialize_folder_study_from_github(repo, ref),
    error = function(e) {
      stop(
        "Could not materialize study folder for ", repo, ": ",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

#' Registry subdirectory name for study stub yaml files
#' @keywords internal
registry_studies_subdir <- function() {
  "studies"
}

#' Absolute path to \code{registry/studies/}
#' @param registry_root Registry checkout root.
#' @keywords internal
registry_studies_dir <- function(registry_root) {
  file.path(registry_root, registry_studies_subdir())
}

#' Path to a registry study stub yaml file
#'
#' Prefers \code{studies/<folder>.yml}; falls back to legacy \code{papers/}
#' layouts when present.
#'
#' @param registry_root Registry checkout root.
#' @param folder Registry folder name.
#' @return Character path (flat layout path under \code{studies/} when missing).
#' @keywords internal
registry_paper_yaml_path <- function(registry_root, folder) {
  registry_study_yaml_path(registry_root, folder)
}

#' @rdname registry_paper_yaml_path
#' @keywords internal
registry_study_yaml_path <- function(registry_root, folder) {
  file.path(registry_studies_dir(registry_root), paste0(folder, ".yml"))
}

#' GitHub raw URL for a registry study stub yaml
#'
#' @param folder Registry folder name.
#' @param registry_repo Registry repository slug.
#' @param ref Git ref.
#' @keywords internal
registry_paper_yaml_url <- function(
  folder,
  registry_repo = DEFAULT_REGISTRY_REPO,
  ref = "main"
) {
  registry_study_yaml_url(folder, registry_repo = registry_repo, ref = ref)
}

#' @rdname registry_paper_yaml_url
#' @keywords internal
registry_study_yaml_url <- function(
  folder,
  registry_repo = DEFAULT_REGISTRY_REPO,
  ref = "main"
) {
  sprintf(
    "https://raw.githubusercontent.com/%s/%s/%s/%s.yml",
    registry_repo,
    ref,
    registry_studies_subdir(),
    folder
  )
}

#' Read the registry stub yaml for a paper folder
#'
#' @param folder Registry folder name.
#' @param registry_root Optional registry checkout root.
#' @keywords internal
read_registry_stub_yaml <- function(folder, registry_root = NULL) {
  if (is.null(registry_root)) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (!is.null(registry_root) && dir.exists(registry_root)) {
    path <- registry_study_yaml_path(registry_root, folder)
    if (file.exists(path)) {
      return(tryCatch(yaml::read_yaml(path), error = function(e) NULL))
    }
  }
  read_yaml_url(registry_study_yaml_url(folder))
}

#' Build a minimal folder-study stub when the registry yaml is missing
#'
#' Used when a study is loaded by DOI after its registry stub was moved to
#' \code{drafts/} or is not yet published. Looks up the study repo from
#' \code{index.csv}, then tries standard \code{rep-<doi>} GitHub paths.
#'
#' @param doi Normalized DOI.
#' @param folder Registry folder name when known.
#' @keywords internal
infer_folder_study_stub <- function(doi, folder = NULL) {
  idx <- tryCatch(load_index(), error = function(e) NULL)
  if (!is.null(idx) && "repo" %in% names(idx)) {
    row <- NULL
    if ("doi" %in% names(idx)) {
      norm <- vapply(idx$doi, normalize_doi, character(1))
      row <- idx[norm == doi, , drop = FALSE]
    }
    if ((is.null(row) || nrow(row) == 0L) && !is.null(folder) && nzchar(folder) &&
        "folder" %in% names(idx)) {
      row <- idx[idx$folder == folder, , drop = FALSE]
    }
    if (!is.null(row) && nrow(row) > 0L && nzchar(row$repo[[1]])) {
      slug <- as.character(row$repo[[1]])
      if (!identical(slug, DEFAULT_REGISTRY_REPO)) {
        return(list(
          repo = slug,
          paper = list(
            doi = row$doi[[1]] %||% doi,
            materials = "folder",
            study_repo = slug,
            study_ref = "main"
          )
        ))
      }
    }
  }

  slug_candidates <- unique(c(
    paste0("replicate-anything/", study_folder_from_doi(doi)),
    paste0("replicate-anything/", tolower(study_folder_from_doi(doi))),
    if (!is.null(folder) && nzchar(folder)) {
      c(
        paste0("replicate-anything/", folder),
        paste0("replicate-anything/", tolower(folder))
      )
    } else {
      character(0)
    }
  ))
  slug_candidates <- slug_candidates[nzchar(slug_candidates)]
  for (slug in slug_candidates) {
    yml <- read_yaml_url(folder_study_yaml_urls(slug))
    if (!is.null(yml)) {
      return(c(list(repo = slug), yml))
    }
  }
  NULL
}

#' Run an expression with \code{REPLICATE_STUDY_ROOT} set for folder studies
#'
#' @param study_root Normalized study repository path, or \code{NULL} to skip.
#' @param expr Expression to evaluate.
#' @return Value of \code{expr}.
#' @keywords internal
with_replicate_study_root <- function(study_root, expr) {
  old <- Sys.getenv("REPLICATE_STUDY_ROOT", unset = NA_character_)
  on.exit({
    if (is.na(old)) {
      Sys.unsetenv("REPLICATE_STUDY_ROOT")
    } else {
      Sys.setenv(REPLICATE_STUDY_ROOT = old)
    }
  }, add = TRUE)
  if (!is.null(study_root) && length(study_root) == 1L && nzchar(study_root)) {
    Sys.setenv(
      REPLICATE_STUDY_ROOT = normalizePath(study_root, winslash = "/", mustWork = FALSE)
    )
  }
  force(expr)
}
