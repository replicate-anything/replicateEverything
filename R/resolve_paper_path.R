#' Resolve the registry folder name for a paper
#'
#' Uses the registry index \code{folder} column when available, otherwise
#' derives a path from the normalized DOI.
#'
#' @param doi Character. DOI of the paper.
#'
#' @return Character folder name under \code{papers/}.
#' @keywords internal
resolve_paper_path <- function(doi) {
  doi <- normalize_doi(doi)

  index <- tryCatch(load_index(), error = function(e) NULL)

  if (!is.null(index) && "folder" %in% names(index) && "doi" %in% names(index)) {
    normalized_index_dois <- vapply(index$doi, normalize_doi, character(1))
    row <- index[normalized_index_dois == doi, , drop = FALSE]
    if (nrow(row) > 0 && nzchar(row$folder[[1]])) {
      return(row$folder[[1]])
    }
  }

  gsub("/", "_", doi)
}

#' Build base URLs and paths for a paper in the registry
#'
#' Registry stubs live as \code{papers/<folder>.yml} files.
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
  doi <- normalize_doi(doi)
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
    registry_paper_yaml_path(registry_root, folder)
  } else {
    NULL
  }
  registry_local_root <- if (!is.null(registry_root)) {
    file.path(registry_root, "papers")
  } else {
    NULL
  }

  stub <- read_registry_stub_yaml(folder, registry_root = registry_root)
  if (is.null(stub)) {
    stub <- infer_folder_study_stub(doi, folder = folder)
  }
  ctx_stub <- list(repo = index_repo, folder = folder)

  is_folder_study <- !is.null(stub) && is_folder_study_replication(stub, ctx_stub)
  is_package_study <- !is.null(stub) && is_package_replication(stub)

  materials_repo <- if (is_folder_study) {
    study_repo_slug(stub, ctx_stub)
  } else {
    DEFAULT_REGISTRY_REPO
  }

  if (is_folder_study) {
    study_ref <- study_repo_ref(stub)
    local_root <- resolve_study_folder_path(stub, ctx_stub)
    base_url <- registry_url(
      paste0("https://raw.githubusercontent.com/", materials_repo),
      paste0(study_ref, "/")
    )
  } else if (is_package_study) {
    pkg_repo <- as.character((stub$repo %||% stub$paper$package_repo %||% index_repo)[[1]])
    ref <- as.character((stub$paper$package_ref %||% stub$package_ref %||% "main")[[1]])
    local_root <- NULL
    base_url <- paste0(
      "https://raw.githubusercontent.com/",
      pkg_repo,
      "/",
      ref,
      "/"
    )
  } else {
    local_root <- resolve_local_study_folder(doi)
    base_url <- paste0(
      "https://raw.githubusercontent.com/",
      DEFAULT_REGISTRY_REPO,
      "/main/papers/"
    )
  }

  if (is.null(local_root)) {
    local_root <- resolve_local_study_folder(doi)
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
