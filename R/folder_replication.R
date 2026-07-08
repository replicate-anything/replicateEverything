#' Folder-backed replication helpers
#'
#' Studies whose materials live in a separate Git repository as a simple
#' \code{data/}, \code{code/}, and \code{artifacts/} tree (not an R package).
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

#' Detect a local replicate-anything monorepo root
#'
#' Looks for \code{registry/index.csv} next to the installed or loaded
#' \pkg{replicateEverything} package, or uses
#' \code{getOption("replicateEverything.study_folders_root")}.
#'
#' @return Normalized path or \code{NULL}.
#' @keywords internal
auto_detect_monorepo_root <- function() {
  study_root <- getOption("replicateEverything.study_folders_root", NULL)
  if (!is.null(study_root) && dir.exists(study_root)) {
    return(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  }

  pkg_root <- tryCatch(
    getNamespaceInfo("replicateEverything", "path"),
    error = function(e) ""
  )
  if (!nzchar(pkg_root)) {
    pkg_root <- tryCatch(system.file(package = "replicateEverything"), error = function(e) "")
  }

  starts <- unique(c(getwd(), pkg_root, if (nzchar(pkg_root)) dirname(pkg_root)))
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
  study_name <- study_folder_from_doi(doi)
  monorepo <- sibling_monorepo_root()
  if (!is.null(monorepo)) {
    candidate <- file.path(monorepo, study_name)
    if (dir.exists(candidate) && file.exists(file.path(candidate, "replication.yml"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    }
  }

  pkg_root <- tryCatch(
    getNamespaceInfo("replicateEverything", "path"),
    error = function(e) ""
  )
  starts <- unique(c(getwd(), pkg_root))
  for (start in starts) {
    found <- walk_up_for_relative(start, file.path(study_name, "replication.yml"))
    if (!is.null(found)) {
      return(normalizePath(file.path(found, study_name), winslash = "/", mustWork = FALSE))
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
#'   or \code{generic}.
#' @param path Optional path string entered by the user.
#' @param input Optional raw input string.
#' @return Multi-line character message.
#' @keywords internal
study_input_error_message <- function(
  kind = c("path", "cwd", "empty", "doi", "generic"),
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
    generic = paste0(doi_hint, "\n", path_hint)
  )
}

register_local_study_from_root <- function(local_root) {
  meta <- read_study_replication_yaml(local_root)
  if (is.null(meta) || is.null(meta$paper$doi)) {
    stop("Local replication.yml must include paper.doi.", call. = FALSE)
  }
  doi_out <- normalize_doi(meta$paper$doi)
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
#' @return A list with \code{doi}, \code{local_root}, and \code{is_local}.
#' @keywords internal
resolve_doi_input <- function(doi = NULL, location = getwd()) {
  raw <- trimws(as.character(doi %||% ""))

  if (is_study_path_query(raw)) {
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

  local_root <- find_local_study_root(location)

  if (is_local_doi_query(raw)) {
    if (is.null(local_root)) {
      stop(study_input_error_message("cwd"), call. = FALSE)
    }
    return(register_local_study_from_root(local_root))
  }

  if (!nzchar(raw)) {
    stop(study_input_error_message("empty"), call. = FALSE)
  }

  handle_doi <- resolve_registry_handle(raw)
  if (!is.null(handle_doi)) {
    raw <- handle_doi
  }

  doi_out <- normalize_doi(raw)
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

  list(doi = doi_out, local_root = NULL, is_local = FALSE)
}

#' Prepare a DOI for replication API calls
#'
#' Wrapper around \code{\link{resolve_doi_input}} that returns the canonical DOI.
#'
#' @inheritParams resolve_doi_input
#' @return Character DOI.
#' @keywords internal
prepare_doi_for_replication <- function(doi, location = getwd()) {
  resolve_doi_input(doi, location = location)$doi
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
#' @keywords internal
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
  reps <- meta$replications %||% list()
  if (length(reps) > 0) {
    return(meta)
  }

  study_meta <- fetch_folder_study_replication_yaml(meta, ctx)
  if (!is.null(study_meta)) {
    meta$replications <- study_meta$replications %||% list()
    if (length(meta$prep %||% list()) == 0) {
      meta$prep <- study_meta$prep %||% list()
    }
    if (length(meta$paper$dependencies %||% list()) == 0) {
      meta$paper$dependencies <- study_meta$paper$dependencies %||% list()
    }
  }
  meta
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
  if (file.rename(from, to)) {
    return(invisible(TRUE))
  }
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(from, full.names = TRUE, all.files = TRUE, no.. = TRUE)
  ok <- file.copy(from = entries, to = to, recursive = TRUE, copy.mode = TRUE)
  if (!all(ok)) {
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
  unzip_parent <- tempfile("study-unzip-")
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

  if (!is.null(ctx) && !is.null(ctx$local_root) && dir.exists(ctx$local_root)) {
    marker <- file.path(ctx$local_root, "replication.yml")
    if (file.exists(marker)) {
      return(normalizePath(ctx$local_root, winslash = "/", mustWork = FALSE))
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

#' Legacy registry subdirectory (pre-rename)
#' @keywords internal
registry_papers_subdir_legacy <- function() {
  "papers"
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
  for (sub in c(registry_studies_subdir(), registry_papers_subdir_legacy())) {
    flat <- file.path(registry_root, sub, paste0(folder, ".yml"))
    if (file.exists(flat)) {
      return(flat)
    }
    legacy <- file.path(registry_root, sub, folder, "replication.yml")
    if (file.exists(legacy)) {
      return(legacy)
    }
  }
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

#' Legacy GitHub raw URLs for registry study stubs
#' @keywords internal
registry_study_yaml_url_legacy <- function(
  folder,
  registry_repo = DEFAULT_REGISTRY_REPO,
  ref = "main"
) {
  c(
    sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/%s.yml",
      registry_repo,
      ref,
      registry_papers_subdir_legacy(),
      folder
    ),
    sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/%s/replication.yml",
      registry_repo,
      ref,
      registry_papers_subdir_legacy(),
      folder
    ),
    sprintf(
      "https://raw.githubusercontent.com/%s/%s/%s/%s/replication.yml",
      registry_repo,
      ref,
      registry_studies_subdir(),
      folder
    )
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
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }
  if (!is.null(registry_root)) {
    path <- registry_paper_yaml_path(registry_root, folder)
    if (file.exists(path)) {
      return(tryCatch(yaml::read_yaml(path), error = function(e) NULL))
    }
    draft_path <- file.path(registry_root, "drafts", paste0(folder, ".yml"))
    if (file.exists(draft_path)) {
      return(tryCatch(yaml::read_yaml(draft_path), error = function(e) NULL))
    }
  }
  meta <- read_yaml_url(registry_study_yaml_url(folder))
  if (!is.null(meta)) {
    return(meta)
  }
  for (legacy_url in registry_study_yaml_url_legacy(folder)) {
    meta <- read_yaml_url(legacy_url)
    if (!is.null(meta)) {
      return(meta)
    }
  }
  NULL
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
