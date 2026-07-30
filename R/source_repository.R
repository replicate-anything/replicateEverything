#' Canonical package GitHub URL used when source is replicateEverything itself
#' @noRd
REPLICATE_EVERYTHING_SOURCE_URL <-
  "https://github.com/replicate-anything/replicateEverything"

#' Normalize a source_repository yaml value to a character vector
#'
#' Accepts a scalar string, a yaml sequence (list), or a character vector.
#' Empty / NA entries are dropped.
#' @keywords internal
normalize_source_repository_values <- function(val) {
  if (is.null(val)) {
    return(character(0))
  }
  if (is.list(val) && !is.data.frame(val)) {
    vals <- unlist(val, use.names = FALSE)
  } else {
    vals <- val
  }
  vals <- trimws(as.character(vals))
  vals[!is.na(vals) & nzchar(vals)]
}

#' Resolve all paper.source_repository credits
#'
#' Canonical field is \code{paper.source_repository}: one URL (preferred) or a
#' yaml list of URLs / short credits for original materials deposits. Legacy
#' aliases \code{source_url} and \code{source_repo} are accepted when the
#' canonical field is empty. When multiple sources are declared, the first is
#' treated as primary (see [paper_source_repository()]).
#'
#' @param paper Optional \code{paper} list from \code{replication.yml} or a
#'   registry stub.
#' @param meta Optional full parsed metadata (uses \code{meta$paper}).
#' @return Character vector (possibly empty).
#' @keywords internal
paper_source_repositories <- function(paper = NULL, meta = NULL) {
  if (is.null(paper) && !is.null(meta)) {
    paper <- meta$paper %||% NULL
  }
  if (is.null(paper) || !length(paper)) {
    return(character(0))
  }
  for (field in c("source_repository", "source_url", "source_repo")) {
    vals <- normalize_source_repository_values(paper[[field]] %||% NULL)
    if (length(vals)) {
      return(unique(vals))
    }
  }
  character(0)
}

#' Resolve paper.source_repository (with legacy aliases)
#'
#' Canonical field is \code{paper.source_repository}: URL (preferred) or short
#' text credit for the original data / materials deposit. May also be a yaml
#' list of sources; this helper returns the **primary** (first) entry. Use
#' [paper_source_repositories()] for the full list. Legacy aliases
#' \code{source_url} and \code{source_repo} are accepted when the canonical
#' field is empty.
#'
#' @param paper Optional \code{paper} list from \code{replication.yml} or a
#'   registry stub.
#' @param meta Optional full parsed metadata (uses \code{meta$paper}).
#' @return Character scalar, or \code{NULL} when unset.
#' @keywords internal
paper_source_repository <- function(paper = NULL, meta = NULL) {
  vals <- paper_source_repositories(paper = paper, meta = meta)
  if (!length(vals)) {
    return(NULL)
  }
  vals[[1L]]
}

#' Classify a source-repository credit for display icons
#'
#' Heuristics from the URL / credit string. Authors only need to set
#' \code{paper.source_repository}; optional explicit kinds are not required.
#'
#' @param value Character URL or short credit from [paper_source_repository()].
#' @return One of \code{"dataverse"}, \code{"osf"}, \code{"worldbank"},
#'   \code{"icpsr"}, \code{"git"}, \code{"personal"},
#'   \code{"replicateEverything"}, or \code{"other"}.
#' @keywords internal
source_repository_kind <- function(value) {
  raw <- trimws(as.character(value %||% ""))
  if (!nzchar(raw)) {
    return("other")
  }
  lower <- tolower(raw)

  if (
    identical(lower, "replicateeverything") ||
      grepl("replicate-anything/replicateeverything", lower, fixed = TRUE) ||
      grepl("(^|/)replicateeverything(/|$)", lower)
  ) {
    return("replicateEverything")
  }

  if (
    grepl("dataverse", lower, fixed = TRUE) ||
      grepl("/dvn/", lower, fixed = TRUE) ||
      grepl("doi:10\\.7910/dvn/", lower)
  ) {
    return("dataverse")
  }

  if (grepl("osf\\.io", lower) || grepl("/osf/", lower)) {
    return("osf")
  }

  if (
    grepl("worldbank\\.org", lower) ||
      grepl("reproducibility\\.worldbank", lower) ||
      grepl("microdata\\.worldbank", lower)
  ) {
    return("worldbank")
  }

  if (
    grepl("openicpsr\\.org", lower) ||
      grepl("icpsr\\.umich\\.edu", lower) ||
      grepl("openicpsr", lower, fixed = TRUE) ||
      grepl("icpsr", lower, fixed = TRUE)
  ) {
    return("icpsr")
  }

  if (
    grepl("github\\.com", lower) ||
      grepl("gitlab\\.com", lower) ||
      grepl("bitbucket\\.org", lower) ||
      grepl("codeberg\\.org", lower) ||
      grepl("git\\.io", lower)
  ) {
    return("git")
  }

  if (
    grepl("github\\.io", lower) ||
      grepl("^https?://", lower) ||
      grepl("^[a-z0-9.-]+\\.[a-z]{2,}", lower)
  ) {
    return("personal")
  }

  "other"
}

#' Human label for a source-repository kind
#' @param kind Kind from [source_repository_kind()].
#' @return Character label.
#' @keywords internal
source_repository_kind_label <- function(kind) {
  switch(
    as.character(kind %||% "other"),
    dataverse = "Dataverse",
    osf = "OSF",
    worldbank = "World Bank",
    icpsr = "ICPSR / OpenICPSR",
    git = "Git repository",
    personal = "Personal / institutional archive",
    replicateEverything = "replicateEverything",
    "Source repository"
  )
}

#' Browse URL for a source-repository credit
#'
#' Returns an http(s) URL when \code{value} is already a link, or maps the
#' bare credit \code{"replicateEverything"} to the package GitHub page.
#'
#' @param value Character from [paper_source_repository()].
#' @return Character URL, or \code{NULL}.
#' @keywords internal
source_repository_href <- function(value) {
  raw <- trimws(as.character(value %||% ""))
  if (!nzchar(raw)) {
    return(NULL)
  }
  if (grepl("^https?://", raw, ignore.case = TRUE)) {
    return(raw)
  }
  if (identical(tolower(raw), "replicateeverything")) {
    return(REPLICATE_EVERYTHING_SOURCE_URL)
  }
  NULL
}

#' check_replication row for paper.source_repository
#' @param paper Paper list.
#' @return A one-row check result data frame.
#' @keywords internal
check_paper_source_repository <- function(paper) {
  srcs <- paper_source_repositories(paper = paper)
  if (!length(srcs)) {
    return(check_result(
      "paper_source_repository",
      FALSE,
      "paper.source_repository is required (URL of the original data deposit)"
    ))
  }
  detail <- paste(
    vapply(
      srcs,
      function(src) paste0(src, " [", source_repository_kind(src), "]"),
      character(1)
    ),
    collapse = "; "
  )
  check_result(
    "paper_source_repository",
    TRUE,
    detail
  )
}

#' Studies in a registry missing paper.source_repository
#'
#' Reads registry stubs (and falls back to legacy aliases). Used by
#' [audit_everything()] summary and maintainer messaging.
#'
#' @param registry_root Path to the registry checkout.
#' @param index Optional index data frame.
#' @return Character vector of study keys (DOI or handle) that are missing a
#'   source repository credit.
#' @keywords internal
registry_source_repository_gaps <- function(registry_root = NULL, index = NULL) {
  root <- registry_root %||% getOption("replicateEverything.registry_root", NULL)
  if (is.null(root) || !nzchar(as.character(root)) || !dir.exists(root)) {
    return(character(0))
  }
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  if (is.null(index)) {
    index <- tryCatch(
      compile_registry_index_from_stubs(root),
      error = function(e) NULL
    )
  }
  if (is.null(index) || !is.data.frame(index) || nrow(index) == 0L) {
    return(character(0))
  }
  studies_dir <- registry_studies_dir(root)
  gaps <- character(0)
  for (i in seq_len(nrow(index))) {
    folder <- as.character(index$folder[[i]] %||% "")
    if (!nzchar(folder)) {
      next
    }
    path <- file.path(studies_dir, paste0(folder, ".yml"))
    meta <- if (file.exists(path)) {
      tryCatch(yaml::read_yaml(path), error = function(e) NULL)
    } else {
      NULL
    }
    src <- paper_source_repository(meta = meta)
    if (is.null(src) || !nzchar(src)) {
      doi <- trimws(as.character(index$doi[[i]] %||% ""))
      handle <- if ("handle" %in% names(index)) {
        trimws(as.character(index$handle[[i]] %||% ""))
      } else {
        ""
      }
      key <- if (nzchar(doi)) {
        tryCatch(normalize_doi(doi), error = function(e) doi)
      } else if (nzchar(handle)) {
        handle
      } else {
        folder
      }
      gaps <- c(gaps, key)
    }
  }
  unique(gaps)
}
