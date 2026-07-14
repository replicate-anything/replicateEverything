#' Build registry index row for a folder-backed study
#' @keywords internal
folder_registry_index_row <- function(meta, study_root) {
  registry_index_row_from_meta(meta, study_root = study_root)
}

#' Canonical lookup key (DOI or study handle) from paper metadata
#'
#' Used when a study has no DOI (reanalysis / extension repos) or when validating
#' registry stubs that only declare \code{study_handle}.
#'
#' @param paper \code{paper} list from replication metadata.
#' @param folder Optional registry folder name fallback.
#' @return Character lookup key.
#' @keywords internal
study_lookup_from_paper <- function(paper, folder = NULL) {
  paper <- paper %||% list()
  doi_val <- paper$doi %||% NULL
  if (!is.null(doi_val) && nzchar(trimws(as.character(doi_val[[1]] %||% doi_val)))) {
    return(normalize_doi(doi_val))
  }
  handle <- paper$study_handle %||% paper$handle %||% NULL
  if (!is.null(handle) && nzchar(trimws(as.character(handle[[1]] %||% handle)))) {
    return(as.character(handle[[1]] %||% handle))
  }
  folder_chr <- as.character(folder[[1]] %||% folder %||% "")
  folder_chr <- trimws(folder_chr)
  if (nzchar(folder_chr)) {
    return(folder_chr)
  }
  stop("paper needs doi or study_handle for lookup", call. = FALSE)
}

#' Registry folder / handle from paper metadata
#' @keywords internal
registry_folder_from_paper <- function(paper) {
  doi_val <- paper$doi %||% NULL
  if (!is.null(doi_val)) {
    doi_chr <- trimws(as.character(doi_val[[1]] %||% doi_val))
    if (nzchar(doi_chr)) {
      return(doi_to_registry_folder(doi_val))
    }
  }
  handle <- as.character(
    paper$study_handle %||% paper$study_folder %||% paper$handle %||% ""
  )
  handle <- trimws(handle[[1]] %||% handle)
  if (nzchar(handle)) {
    return(handle)
  }
  stop("paper needs doi or study_handle for registry index", call. = FALSE)
}

#' Build a registry index row from study or registry stub metadata
#' @keywords internal
registry_index_row_from_meta <- function(meta, study_root = NULL, folder = NULL) {
  paper <- meta$paper
  authors <- paper$authors %||% ""
  if (length(authors) > 1) {
    authors <- paste(authors, collapse = ", ")
  } else {
    authors <- as.character(authors[[1]] %||% "")
  }
  if (is.null(folder) || !nzchar(as.character(folder[[1]] %||% folder))) {
    folder <- registry_folder_from_paper(paper)
  } else {
    folder <- as.character(folder[[1]] %||% folder)
  }
  handle <- as.character(paper$handle %||% paper$study_handle %||% folder)
  handle <- trimws(handle[[1]] %||% handle)
  if (!nzchar(handle)) {
    handle <- folder
  }
  doi_val <- paper$doi %||% NULL
  doi_out <- if (!is.null(doi_val) && nzchar(trimws(as.character(doi_val[[1]] %||% doi_val)))) {
    normalize_doi(doi_val)
  } else {
    ""
  }
  collections <- meta$collections %||% paper$collections %||% character(0)
  collections <- unique(na.omit(as.character(unlist(collections, use.names = FALSE))))
  collections <- paste(collections[nzchar(collections)], collapse = "|")
  maintainer <- meta$maintainer %||% list()
  maintainer_name <- as.character(maintainer$name %||% maintainer$Name %||% "")
  maintainer_email <- as.character(maintainer$email %||% maintainer$Email %||% "")
  languages <- study_declared_languages(meta)
  languages <- paste(languages[nzchar(languages)], collapse = ";")
  article_url <- as.character(paper$article_url %||% paper$landing_url %||% paper$study_url %||% "")
  repo <- if (!is.null(study_root)) {
    infer_study_repo_slug(study_root, meta)
  } else {
    NULL
  }
  if (is.null(repo) || !nzchar(repo)) {
    repo <- as.character((
      meta$repo %||%
        paper$study_repo %||%
        paper$package_repo %||%
        ""
    )[[1]])
  }
  data.frame(
    folder = folder,
    handle = handle,
    doi = doi_out,
    title = as.character(paper$title[[1]]),
    journal = as.character(paper$journal %||% ""),
    year = as.integer(paper$year %||% NA_integer_),
    authors = authors,
    repo = repo,
    collections = collections,
    maintainer_name = maintainer_name,
    maintainer_email = maintainer_email,
    languages = languages,
    article_url = article_url,
    stringsAsFactors = FALSE
  )
}

#' Package name from a local package source tree
#' @keywords internal
package_name_from_root <- function(pkg_root) {
  desc_path <- file.path(pkg_root, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    stop("Missing DESCRIPTION in ", pkg_root, call. = FALSE)
  }
  desc <- read.dcf(desc_path)
  as.character(desc[1, "Package"])
}

#' Resolve a study repository root (folder-backed or package-backed)
#' @keywords internal
resolve_study_root <- function(location) {
  if (length(location) != 1L || is.na(location) || !nzchar(trimws(location))) {
    stop("location must be a non-empty path or GitHub address.", call. = FALSE)
  }
  loc <- trimws(location)
  if (dir.exists(loc)) {
    if (
      file.exists(file.path(loc, "replication.yml")) ||
        file.exists(file.path(loc, "DESCRIPTION"))
    ) {
      return(normalizePath(loc, winslash = "/", mustWork = FALSE))
    }
  }
  alias_root <- try_resolve_study_by_common_alias(loc)
  if (!is.null(alias_root)) {
    return(alias_root)
  }
  folder_err <- NULL
  pkg_err <- NULL
  root <- tryCatch(
    resolve_study_location(loc),
    error = function(e) {
      folder_err <<- conditionMessage(e)
      NULL
    }
  )
  if (!is.null(root)) {
    return(root)
  }
  root <- tryCatch(
    resolve_package_location(loc),
    error = function(e) {
      pkg_err <<- conditionMessage(e)
      NULL
    }
  )
  if (!is.null(root)) {
    return(root)
  }
  stop(
    "Could not resolve study location: ", loc,
    ". Provide a folder with replication.yml, an R package with DESCRIPTION, ",
    "or a GitHub URL/slug (org/repo).",
    study_location_input_hints(loc),
    call. = FALSE
  )
}

#' Detect study layout from a local repository root
#' @keywords internal
detect_study_kind_from_root <- function(study_root) {
  if (file.exists(file.path(study_root, "DESCRIPTION"))) {
    return("package")
  }
  if (file.exists(file.path(study_root, "replication.yml"))) {
    return("folder")
  }
  stop(
    "Not a recognized study repository: ", study_root,
    " (expected replication.yml or DESCRIPTION).",
    call. = FALSE
  )
}

#' Directory for registry handoff files inside a study repository
#'
#' Folder-backed studies use `registry/`. Package-backed studies use
#' `inst/registry/` (preferred) or legacy `registry/` at the package root.
#'
#' @param study_root Normalized study repository path.
#' @param kind `"folder"` or `"package"`. Inferred when omitted.
#' @param create If `TRUE`, create the directory when missing.
#' @keywords internal
study_registry_stub_dir <- function(study_root, kind = NULL, create = FALSE) {
  kind <- kind %||% detect_study_kind_from_root(study_root)
  if (identical(kind, "package")) {
    inst_reg <- file.path(study_root, "inst", "registry")
    root_reg <- file.path(study_root, "registry")
    stub_dir <- if (dir.exists(inst_reg)) {
      inst_reg
    } else if (dir.exists(root_reg)) {
      root_reg
    } else {
      inst_reg
    }
  } else {
    stub_dir <- file.path(study_root, "registry")
  }
  if (isTRUE(create)) {
    dir.create(stub_dir, recursive = TRUE, showWarnings = FALSE)
  }
  stub_dir
}

#' Read full replication metadata from a study repository root
#' @keywords internal
read_study_meta_from_root <- function(study_root, kind = NULL) {
  kind <- kind %||% detect_study_kind_from_root(study_root)
  meta <- if (identical(kind, "package")) {
    read_package_replication_yaml(study_root)
  } else {
    read_study_replication_yaml(study_root)
  }
  if (is.null(meta)) {
    stop("Missing replication.yml in ", study_root, call. = FALSE)
  }
  meta
}

#' Build registry stub list from full study metadata
#' @keywords internal
build_registry_stub_from_meta <- function(meta, study_root, kind = NULL) {
  kind <- kind %||% detect_study_kind_from_root(study_root)
  if (identical(kind, "package")) {
    registry_stub_from_package_meta(meta, package_folder = basename(study_root))
  } else {
    registry_stub_from_folder_meta(
      meta,
      study_folder = basename(study_root),
      study_root = study_root
    )
  }
}

#' Compare registry stub fields against full study metadata
#' @keywords internal
validate_registry_stub_consistency <- function(meta, stub, study_root, kind = NULL) {
  kind <- kind %||% detect_study_kind_from_root(study_root)
  expected <- build_registry_stub_from_meta(meta, study_root, kind = kind)
  issues <- character()

  norm_chr <- function(x) {
    trimws(as.character(x[[1]] %||% x %||% ""))
  }

  if (norm_chr(stub$repo) != norm_chr(expected$repo)) {
    issues <- c(
      issues,
      paste0(
        "repo mismatch: stub has '", norm_chr(stub$repo),
        "', expected '", norm_chr(expected$repo), "'"
      )
    )
  }

  stub_paper <- stub$paper %||% list()
  exp_paper <- expected$paper %||% list()
  for (field in c("doi", "title", "journal", "year")) {
    s <- norm_chr(stub_paper[[field]])
    e <- norm_chr(exp_paper[[field]])
    if (nzchar(e) && nzchar(s) && !identical(s, e)) {
      issues <- c(
        issues,
        paste0("paper.", field, " mismatch between stub and replication.yml")
      )
    }
  }

  stub_m <- stub$maintainer %||% list()
  exp_m <- expected$maintainer %||% list()
  if (norm_chr(stub_m$name) != norm_chr(exp_m$name)) {
    issues <- c(issues, "maintainer.name mismatch between stub and replication.yml")
  }
  if (norm_chr(stub_m$email) != norm_chr(exp_m$email)) {
    issues <- c(issues, "maintainer.email mismatch between stub and replication.yml")
  }

  stub_langs <- sort(unique(na.omit(as.character(unlist(stub$languages %||% list())))))
  exp_langs <- sort(unique(na.omit(as.character(unlist(expected$languages %||% list())))))
  if (length(exp_langs) > 0L && !identical(stub_langs, exp_langs)) {
    issues <- c(issues, "languages mismatch between stub and replication.yml")
  }

  index_row <- registry_index_row_from_meta(meta, study_root = study_root)
  folder <- registry_folder_from_paper(meta$paper)
  if (!identical(as.character(index_row$folder[[1]]), as.character(folder))) {
    issues <- c(
      issues,
      paste0("registry folder '", folder, "' does not match index row folder")
    )
  }

  list(ok = length(issues) == 0L, issues = issues)
}

#' Paths to prepared registry handoff files in a study repository
#' @keywords internal
study_registry_handoff_paths <- function(study_root, kind = NULL) {
  kind <- kind %||% detect_study_kind_from_root(study_root)
  stub_dir <- study_registry_stub_dir(study_root, kind = kind)
  list(
    stub_dir = stub_dir,
    stub_path = file.path(stub_dir, "replication.yml"),
    index_path = file.path(stub_dir, "index.csv")
  )
}

#' Write registry stub files into a study repository
#'
#' Creates the short registry yaml and one-row `index.csv` under
#' `registry/` (folder studies) or `inst/registry/` (package studies).
#'
#' @param location Study repo path. Defaults to `"."`.
#' @param stub_dir Optional override for the handoff directory.
#' @return List with `stub_dir`, `stub_path`, `index_path`, `folder`, and `kind`.
#' @keywords internal
write_study_registry_stub <- function(location = ".", stub_dir = NULL) {
  study_root <- resolve_study_root(location)
  kind <- detect_study_kind_from_root(study_root)
  meta <- read_study_meta_from_root(study_root, kind = kind)

  if (is.null(stub_dir) || !nzchar(stub_dir)) {
    stub_dir <- study_registry_stub_dir(study_root, kind = kind, create = TRUE)
  } else if (!dir.exists(stub_dir) && !grepl("^[A-Za-z]:[/\\\\]|^/", stub_dir)) {
    stub_dir <- file.path(study_root, stub_dir)
    dir.create(stub_dir, recursive = TRUE, showWarnings = FALSE)
  }

  stub <- build_registry_stub_from_meta(meta, study_root, kind = kind)
  folder <- registry_folder_from_paper(meta$paper)
  materials <- if (identical(kind, "package")) "package-backed" else "folder-backed"

  stub_path <- file.path(stub_dir, "replication.yml")
  stub_yaml <- yaml::as.yaml(stub)
  header <- c(
    paste0("# Lightweight registry stub for a ", materials, " study."),
    "# Copy to registry/studies/<folder>.yml in the registry repo.",
    paste0("# Registry folder: ", folder),
    ""
  )
  writeLines(c(header, stub_yaml), stub_path, useBytes = TRUE)

  index_path <- file.path(stub_dir, "index.csv")
  utils::write.csv(
    registry_index_row_from_meta(meta, study_root = study_root),
    index_path,
    row.names = FALSE
  )

  written_stub <- yaml::read_yaml(stub_path)
  validation <- validate_registry_stub_consistency(
    meta,
    written_stub,
    study_root,
    kind = kind
  )
  if (!isTRUE(validation$ok)) {
    stop(
      "Registry stub failed consistency checks:\n",
      paste0("  - ", validation$issues, collapse = "\n"),
      call. = FALSE
    )
  }

  readme_path <- file.path(stub_dir, "README.md")
  if (!file.exists(readme_path)) {
    writeLines(
      c(
        "# Registry sync files",
        "",
        "Generated by `replicateEverything::prepare_study_for_registry()`.",
        "",
        paste0("- Maintainer copies `replication.yml` to `registry/studies/", folder, ".yml`"),
        "- Or run `replicateEverything::sync_study_to_registry()` from a registry checkout.",
        "- After a full registry refresh, run `refresh_registry()` to rebuild `index.csv` and audit."
      ),
      readme_path
    )
  }

  invisible(list(
    stub_dir = stub_dir,
    stub_path = stub_path,
    index_path = index_path,
    folder = folder,
    kind = kind,
    validation = validation
  ))
}

#' @rdname write_study_registry_stub
#' @keywords internal
write_folder_registry_stub <- function(location = ".", stub_dir = NULL) {
  write_study_registry_stub(location = location, stub_dir = stub_dir)
}
