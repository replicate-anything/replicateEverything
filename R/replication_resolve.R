#' Normalize a replication language argument
#'
#' @param language \code{"R"}, \code{"r"}, \code{"Stata"}, or \code{"stata"}.
#' @return \code{"r"}, \code{"stata"}, or \code{NULL}.
#' @keywords internal
normalize_replication_language <- function(language) {
  if (is.null(language) || length(language) == 0L) {
    return(NULL)
  }
  lang <- tolower(trimws(as.character(language[[1]])))
  if (!nzchar(lang)) {
    return(NULL)
  }
  if (lang %in% c("r")) {
    return("r")
  }
  if (lang %in% c("stata")) {
    return("stata")
  }
  if (lang %in% c("python", "py")) {
    return("python")
  }
  stop('language must be "R", "stata", or "python"', call. = FALSE)
}

#' Infer replication language when only one engine implements \code{what}
#'
#' @param meta Parsed replication metadata.
#' @param what Replication id or logical group id.
#' @param language Optional explicit language (normalized when set).
#' @return \code{"r"}, \code{"stata"}, \code{"python"}, or \code{NULL}.
#' @keywords internal
resolve_replication_language <- function(meta, what, language = NULL) {
  lang <- normalize_replication_language(language)
  if (!is.null(lang)) {
    return(lang)
  }
  entries <- collect_replication_entries(meta)
  matches <- entries[
    vapply(entries, function(x) {
      identical(as.character(x$id), what) ||
        identical(replication_logical_id(x), what)
    }, logical(1))
  ]
  if (length(matches) == 0L) {
    return(NULL)
  }
  engines <- unique(vapply(
    matches,
    function(x) replication_engine(x, meta$paper),
    character(1)
  ))
  if (length(engines) == 1L) {
    return(engines[[1]])
  }
  NULL
}

#' Logical replication id (group) for a yaml entry
#'
#' @param rep Replication entry from \code{replication.yml}.
#' @return Character scalar.
#' @keywords internal
replication_logical_id <- function(rep) {
  grp <- as.character(rep$group %||% "")
  if (nzchar(grp)) {
    return(grp)
  }
  as.character(rep$id %||% "")
}

#' Collect replication entries from parsed metadata
#'
#' @param meta Parsed replication metadata.
#' @return List of replication entries.
#' @keywords internal
collect_replication_entries <- function(meta) {
  if (!is.null(meta$steps) && length(meta$steps) > 0L) {
    steps <- normalize_study_steps(meta)
    return(steps[vapply(steps, function(x) {
      !identical(as.character(x$type), "format")
    }, logical(1))])
  }
  entries <- c(meta$prep %||% list(), meta$replications %||% list())
  if (length(entries) > 0L || !is_folder_study_replication(meta)) {
    return(entries)
  }
  ctx <- list(
    repo = study_repo_slug(meta, NULL),
    folder = meta$paper$study_folder %||% NULL
  )
  study_meta <- fetch_folder_study_replication_yaml(meta, ctx)
  if (is.null(study_meta)) {
    return(entries)
  }
  if (!is.null(study_meta$steps) && length(study_meta$steps) > 0L) {
    return(normalize_study_steps(study_meta))
  }
  c(study_meta$prep %||% list(), study_meta$replications %||% list())
}

#' Default engine when multiple entries share a logical id
#'
#' Prefers R when available, otherwise Stata.
#'
#' @param entries List of replication entries sharing a logical id.
#' @param paper_meta Optional paper-level metadata.
#' @return \code{"r"} or \code{"stata"}.
#' @keywords internal
default_replication_language <- function(entries, paper_meta = NULL) {
  langs <- vapply(
    entries,
    function(x) replication_engine(x, paper_meta),
    character(1)
  )
  if ("r" %in% langs) {
    return("r")
  }
  if ("stata" %in% langs) {
    return("stata")
  }
  langs[[1]]
}

#' Find a single replication entry by logical id and optional language
#'
#' \code{what} is the logical replication id (the \code{group} field when set,
#' otherwise the entry \code{id}). When \code{language} is \code{NULL}, R is
#' preferred when both R and Stata entries exist. Legacy suffixed ids such as
#' \code{tab_1_stata} still match by exact \code{id}.
#'
#' @param meta Parsed replication metadata.
#' @param what Replication identifier (logical id or legacy entry id).
#' @param language Optional \code{"R"} or \code{"stata"} engine selector.
#' @param paper_meta Optional paper metadata; defaults to \code{meta$paper}.
#' @keywords internal
find_replication_entry <- function(meta, what, language = NULL, paper_meta = NULL) {
  paper_meta <- paper_meta %||% meta$paper %||% NULL
  language <- resolve_replication_language(meta, what, language)
  entries <- collect_replication_entries(meta)

  exact <- entries[
    vapply(entries, function(x) identical(as.character(x$id), what), logical(1))
  ]
  if (length(exact) == 1L) {
    rep <- exact[[1]]
    if (is.null(language) || identical(replication_engine(rep, paper_meta), language)) {
      return(rep)
    }
  }

  group_matches <- entries[
    vapply(entries, function(x) {
      identical(replication_logical_id(x), what) ||
        identical(as.character(x$id), what)
    }, logical(1))
  ]

  if (length(group_matches) == 0L && is_package_replication(meta)) {
    pkg_entries <- package_replication_entries(meta)
    exact <- pkg_entries[
      vapply(pkg_entries, function(x) identical(x$id, what), logical(1))
    ]
    if (length(exact) == 1L) {
      return(exact[[1]])
    }
    group_matches <- pkg_entries[
      vapply(pkg_entries, function(x) {
        identical(replication_logical_id(x), what) ||
          identical(as.character(x$id), what)
      }, logical(1))
    ]
  }

  if (length(group_matches) == 0L) {
    stop("Replication ", what, " not found in metadata", call. = FALSE)
  }

  lang <- language %||% default_replication_language(group_matches, paper_meta)
  engine_matches <- group_matches[
    vapply(group_matches, function(x) {
      identical(replication_engine(x, paper_meta), lang)
    }, logical(1))
  ]

  if (length(engine_matches) == 0L) {
    stop(
      "Replication ", what, " is not available for language ",
      lang,
      call. = FALSE
    )
  }

  engine_matches[[1]]
}
