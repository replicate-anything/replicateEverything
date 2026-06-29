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

#' Whether replication metadata refers to a folder-backed external study repo
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Optional paper context list with \code{repo} and \code{folder}.
#' @return Logical.
#' @export
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

  unique(c(explicit, derived))
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
  candidates <- study_folder_candidates(meta, ctx)
  for (path in candidates) {
    if (dir.exists(path) && file.exists(file.path(path, "replication.yml"))) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  folder_map <- getOption("replicateEverything.study_folders", NULL)
  if (!is.null(folder_map)) {
    key <- ctx$folder %||% basename(study_repo_slug(meta, ctx))
    if (!is.null(folder_map[[key]])) {
      path <- folder_map[[key]]
      if (dir.exists(path) && file.exists(file.path(path, "replication.yml"))) {
        return(normalizePath(path, winslash = "/", mustWork = FALSE))
      }
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

#' Path to a registry paper stub yaml file
#'
#' Prefers \code{papers/<folder>.yml}; falls back to legacy
#' \code{papers/<folder>/replication.yml} when present.
#'
#' @param registry_root Registry checkout root.
#' @param folder Registry folder name.
#' @return Character path (flat layout path even when missing).
#' @keywords internal
registry_paper_yaml_path <- function(registry_root, folder) {
  flat <- file.path(registry_root, "papers", paste0(folder, ".yml"))
  legacy <- file.path(registry_root, "papers", folder, "replication.yml")
  if (file.exists(flat)) {
    return(flat)
  }
  if (file.exists(legacy)) {
    return(legacy)
  }
  flat
}

#' GitHub raw URL for a registry paper stub yaml
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
  sprintf(
    "https://raw.githubusercontent.com/%s/%s/papers/%s.yml",
    registry_repo,
    ref,
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
  if (!is.null(registry_root)) {
    path <- registry_paper_yaml_path(registry_root, folder)
    if (file.exists(path)) {
      return(tryCatch(yaml::read_yaml(path), error = function(e) NULL))
    }
  }
  meta <- read_yaml_url(registry_paper_yaml_url(folder))
  if (!is.null(meta)) {
    return(meta)
  }
  legacy_url <- sprintf(
    "https://raw.githubusercontent.com/%s/main/papers/%s/replication.yml",
    DEFAULT_REGISTRY_REPO,
    folder
  )
  read_yaml_url(legacy_url)
}
