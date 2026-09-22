#' Resolve the registry folder name for a paper
#'
#' Uses the registry index \code{folder} column when available, otherwise
#' derives a path from the normalized DOI.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return Character folder name under \code{studies/}.
#' @keywords internal
resolve_paper_path <- function(doi) {
  doi <- normalize_doi(doi)

  index <- tryCatch(load_index(), error = function(e) NULL)

  if (!is.null(index) && "folder" %in% names(index) && "doi" %in% names(index)) {
    normalized_index_dois <- vapply(index[["doi"]], function(x) {
      if (is.null(x) || !nzchar(as.character(x))) return(NA_character_)
      normalize_doi(x)
    }, character(1))
    match_idx <- which(!is.na(normalized_index_dois) & normalized_index_dois == doi)
    if (length(match_idx) > 0L) {
      folder_val <- as.character(index[["folder"]][[match_idx[[1]]]] %||% "")
      if (nzchar(folder_val)) {
        return(folder_val)
      }
    }
  }
  if (!is.null(index) && "handle" %in% names(index) && "folder" %in% names(index)) {
    handles <- tolower(as.character(index[["handle"]]))
    match_idx <- which(!is.na(handles) & handles == tolower(doi))
    if (length(match_idx) > 0L) {
      folder_val <- as.character(index[["folder"]][[match_idx[[1]]]] %||% "")
      if (nzchar(folder_val)) {
        return(folder_val)
      }
    }
  }

  gsub("/", "_", doi)
}

#' Local study root that already has replication.yml (no GitHub)
#'
#' Used so [paper_context()] can skip remote registry stub fetches for
#' unpublished folders registered via [configure_study_folder()] / `doi = "local"`.
#'
#' @param doi Normalized DOI or study handle.
#' @param folder Optional registry folder name.
#' @return Normalized path or \code{NULL}.
#' @keywords internal
local_yaml_root_for_doi <- function(doi, folder = NULL) {
  doi_chr <- as.character(doi %||% "")
  doi <- if (length(doi_chr) >= 1L) doi_chr[[1]] else ""
  folder_chr <- as.character(folder %||% "")
  folder <- if (length(folder_chr) >= 1L) folder_chr[[1]] else ""
  roots <- character(0)
  found <- tryCatch(resolve_local_study_folder(doi), error = function(e) NULL)
  if (!is.null(found)) {
    roots <- c(roots, found)
  }
  folder_map <- getOption("replicateEverything.study_folders", NULL)
  if (!is.null(folder_map) && length(folder_map) > 0L) {
    keys <- unique(c(doi, folder, tolower(doi), tolower(folder)))
    keys <- keys[nzchar(keys)]
    for (key in keys) {
      if (is.null(folder_map[[key]])) {
        next
      }
      mapped <- as.character(folder_map[[key]][[1]] %||% folder_map[[key]])
      if (nzchar(mapped) && dir.exists(mapped)) {
        roots <- c(roots, mapped)
      }
    }
  }
  for (root in unique(roots)) {
    if (
      file.exists(file.path(root, "replication.yml")) ||
        file.exists(file.path(root, "inst/replication.yml"))
    ) {
      return(normalizePath(root, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' Build base URLs and paths for a paper in the registry
#'
#' Registry stubs live as \code{studies/<folder>.yml} files.
#' For folder-backed external studies, materials live at the study repo root.
#' For package-backed studies, the registry stub path is still exposed but
#' materials are resolved via the study package API.
#'
#' @param doi Character. DOI of the paper.
#' @param repo Optional repository slug. Defaults to \code{find_repo(doi)}.
#' @param folder Optional registry folder name from \code{index.csv}.
#'
#' @return A list with \code{repo}, \code{folder}, \code{base_url},
#'   \code{registry_local_root}, \code{local_root}, \code{materials_repo},
#'   \code{is_folder_study}, and related fields.
#' @keywords internal
paper_context <- function(doi, repo = NULL, folder = NULL) {
  pinned_local <- NULL
  raw <- unwrap_quoted_study_input(doi %||% "")
  if (is.null(doi) || length(doi) == 0L || is_local_doi_query(raw)) {
    resolved <- resolve_doi_input(doi)
    doi <- resolved$doi
    pinned_local <- resolved$local_root
  } else {
    doi_chr <- as.character(doi %||% "")
    doi <- if (length(doi_chr) >= 1L) normalize_doi(doi_chr[[1]]) else ""
  }
  if (is.null(folder) || !nzchar(folder)) {
    folder <- resolve_paper_path(doi)
  }

  index_repo <- repo
  if (is.null(index_repo) || !nzchar(index_repo)) {
    index_repo <- tryCatch(
      find_repo(doi),
      error = function(e) DEFAULT_REGISTRY_REPO
    )
  }

  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }
  registry_stub_path <- if (!is.null(registry_root)) {
    registry_study_yaml_path(registry_root, folder)
  } else {
    NULL
  }
  registry_local_root <- if (!is.null(registry_root)) {
    registry_studies_dir(registry_root)
  } else {
    NULL
  }

  local_root <- pinned_local %||% local_yaml_root_for_doi(doi, folder = folder)
  has_local_yaml <- !is.null(local_root)

  stub <- read_registry_stub_yaml(
    folder,
    registry_root = registry_root,
    remote = !has_local_yaml
  )
  if (is.null(stub) && !has_local_yaml) {
    stub <- infer_folder_study_stub(doi, folder = folder)
  }
  if (is.null(stub) && has_local_yaml) {
    yml <- file.path(local_root, "replication.yml")
    if (!file.exists(yml)) {
      yml <- file.path(local_root, "inst/replication.yml")
    }
    stub <- tryCatch(yaml::read_yaml(yml), error = function(e) NULL)
  }
  ctx_stub <- list(repo = index_repo, folder = folder)

  is_folder_study <- !is.null(stub) && is_folder_study_replication(stub, ctx_stub)
  is_package_study <- !is.null(stub) && is_package_replication(stub)
  if (has_local_yaml && !is_package_study) {
    is_folder_study <- TRUE
  }

  materials_repo <- if (is_folder_study) {
    study_repo_slug(stub, ctx_stub)
  } else {
    DEFAULT_REGISTRY_REPO
  }

  saved_local <- local_root
  if (is_folder_study) {
    study_ref <- study_repo_ref(stub)
    local_root <- resolve_study_folder_path(stub, ctx_stub)
    if (is.null(local_root)) {
      local_root <- saved_local
    }
    base_url <- registry_url(
      paste0("https://raw.githubusercontent.com/", materials_repo),
      paste0(study_ref, "/")
    )
  } else if (is_package_study) {
    pkg_repo <- as.character((stub$repo %||% stub$paper$package_repo %||% index_repo)[[1]])
    ref <- as.character((stub$paper$package_ref %||% stub$package_ref %||% "main")[[1]])
    if (!has_local_yaml) {
      local_root <- NULL
    }
    base_url <- paste0(
      "https://raw.githubusercontent.com/",
      pkg_repo,
      "/",
      ref,
      "/"
    )
  } else {
    if (is.null(local_root)) {
      local_root <- resolve_local_study_folder(doi)
    }
    base_url <- paste0(
      "https://raw.githubusercontent.com/",
      DEFAULT_REGISTRY_REPO,
      "/main/studies/"
    )
  }

  if (is.null(local_root)) {
    local_root <- saved_local
  }
  if (is.null(local_root)) {
    local_root <- resolve_local_study_folder(doi)
  }
  if (is.null(local_root)) {
    folder_map <- getOption("replicateEverything.study_folders", NULL)
    if (!is.null(folder_map) && length(folder_map) > 0L) {
      for (key in unique(c(doi, folder, tolower(doi)))) {
        if (!nzchar(key) || is.null(folder_map[[key]])) {
          next
        }
        mapped <- as.character(folder_map[[key]][[1]] %||% folder_map[[key]])
        if (nzchar(mapped) && dir.exists(mapped) &&
            file.exists(file.path(mapped, "replication.yml"))) {
          local_root <- normalizePath(mapped, winslash = "/", mustWork = FALSE)
          break
        }
      }
    }
  }

  list(
    doi = doi,
    repo = index_repo,
    folder = folder,
    base_url = base_url,
    local_root = local_root,
    registry_stub_path = registry_stub_path,
    registry_local_root = registry_local_root,
    materials_repo = materials_repo,
    is_folder_study = is_folder_study,
    is_package_study = is_package_study
  )
}
