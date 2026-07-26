#' Load a study descriptor for summary and related links
#'
#' Returns a compact \code{replicate_study} object from the registry index and
#' study \code{replication.yml}. Use with \code{\link{summary.replicate_study}}
#' for a console overview (metadata, step counts, related studies, gap tags).
#'
#' @param doi Character. DOI, registry handle, or \code{"local"} / study path
#'   (see [resolve_doi_input()]).
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return An object of class \code{replicate_study}.
#'
#' @examples
#' \dontrun{
#' st <- get_study("10.1017/S0003055403000534")
#' summary(st)
#' summary_study("rep-10.1017-S0003055403000534--alt-1")
#' }
#'
#' @seealso [summary.replicate_study()], [list_replications()], [load_index()]
#' @export
get_study <- function(doi, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  paper <- meta$paper %||% list()
  lookup <- tryCatch(
    study_lookup_from_paper(paper, folder = folder),
    error = function(e) as.character(doi)
  )

  index <- tryCatch(load_index(), error = function(e) NULL)
  row <- NULL
  if (!is.null(index) && nrow(index) > 0L) {
    index <- ensure_index_handles(index)
    hit <- match_related_ref_to_index(
      list(
        doi = paper$doi %||% lookup,
        handle = paper$study_handle %||% paper$handle %||% lookup,
        repo = meta$repo %||% paper$study_repo %||% NULL
      ),
      index
    )
    if (!is.na(hit)) {
      row <- index[hit, , drop = FALSE]
    }
  }

  doi_out <- if (!is.null(row)) {
    index_row_field(row, "doi", "")
  } else {
    doi_raw <- paper$doi %||% ""
    if (nzchar(trimws(as.character(doi_raw[[1]] %||% doi_raw)))) {
      normalize_doi(doi_raw)
    } else {
      ""
    }
  }
  handle_out <- if (!is.null(row)) {
    index_row_field(row, "handle", lookup)
  } else {
    as.character(paper$study_handle %||% paper$handle %||% lookup)
  }
  title <- if (!is.null(row) && nzchar(index_row_field(row, "title", ""))) {
    index_row_field(row, "title", "")
  } else {
    as.character(paper$title[[1]] %||% paper$title %||% "")
  }
  authors <- if (!is.null(row) && nzchar(index_row_field(row, "authors", ""))) {
    index_row_field(row, "authors", "")
  } else {
    auth <- paper$authors %||% ""
    if (length(auth) > 1L) paste(auth, collapse = ", ") else as.character(auth[[1]] %||% "")
  }
  journal <- if (!is.null(row)) {
    index_row_field(row, "journal", "")
  } else {
    as.character(paper$journal %||% "")
  }
  year <- if (!is.null(row)) {
    suppressWarnings(as.integer(index_row_field(row, "year", NA_character_)))
  } else {
    suppressWarnings(as.integer(paper$year %||% NA_integer_))
  }
  collections <- if (!is.null(row)) {
    index_row_field(row, "collections", "")
  } else {
    paste(
      unique(na.omit(as.character(unlist(
        meta$collections %||% paper$collections %||% character(0),
        use.names = FALSE
      )))),
      collapse = "|"
    )
  }
  languages <- if (!is.null(row) && nzchar(index_row_field(row, "languages", ""))) {
    index_row_field(row, "languages", "")
  } else {
    paste(study_declared_languages(meta), collapse = ";")
  }
  maintainer_name <- if (!is.null(row)) {
    index_row_field(row, "maintainer_name", "")
  } else {
    as.character(meta$maintainer$name %||% "")
  }
  maintainer_email <- if (!is.null(row)) {
    index_row_field(row, "maintainer_email", "")
  } else {
    as.character(meta$maintainer$email %||% "")
  }
  repo_slug <- if (!is.null(row) && nzchar(index_row_field(row, "repo", ""))) {
    index_row_field(row, "repo", "")
  } else {
    as.character((meta$repo %||% paper$study_repo %||% paper$package_repo %||% "")[[1]])
  }

  related <- if (!is.null(row)) {
    related_studies_for_index_row(row, index = index)
  } else {
    up_keys <- resolve_upstream_keys_for_meta(meta, index %||% data.frame())
    list(
      upstream = resolve_related_studies(up_keys, direction = "upstream", index = index),
      downstream = list()
    )
  }

  entries <- tryCatch(
    filter_replication_entries(meta, include = "all"),
    error = function(e) list()
  )
  step_counts <- study_step_type_counts(entries)
  gaps <- study_gap_flags_from_entries(entries)
  gap_counts <- study_gap_step_counts(entries)

  structure(
    list(
      doi = doi_out,
      handle = handle_out,
      title = title,
      authors = authors,
      journal = journal,
      year = year,
      collections = collections,
      languages = languages,
      maintainer_name = maintainer_name,
      maintainer_email = maintainer_email,
      repo = repo_slug,
      step_counts = step_counts,
      gaps = gaps,
      gap_counts = gap_counts,
      related = related,
      folder = if (!is.null(row)) index_row_field(row, "folder", "") else ""
    ),
    class = "replicate_study"
  )
}

#' Summarize a study by DOI / handle (constructs then summarizes)
#'
#' Convenience wrapper around \code{summary(get_study(doi))}.
#'
#' @inheritParams get_study
#' @param ... Passed to \code{\link{summary.replicate_study}}.
#' @return Invisibly, the \code{replicate_study} object.
#' @export
summary_study <- function(doi, repo = NULL, folder = NULL, ...) {
  st <- get_study(doi, repo = repo, folder = folder)
  summary(st, ...)
  invisible(st)
}

#' Count table / figure / transform steps
#' @keywords internal
study_step_type_counts <- function(entries) {
  counts <- list(
    steps = 0L,
    tables = 0L,
    figures = 0L,
    transforms = 0L,
    other = 0L
  )
  if (!is.list(entries) || !length(entries)) {
    return(counts)
  }
  counts$steps <- length(entries)
  for (entry in entries) {
    type <- tolower(as.character(entry$type %||% ""))
    if (identical(type, "table")) {
      counts$tables <- counts$tables + 1L
    } else if (identical(type, "figure")) {
      counts$figures <- counts$figures + 1L
    } else if (type %in% c("transform", "prep", "pipeline")) {
      counts$transforms <- counts$transforms + 1L
    } else if (isTRUE(is_prep_entry(entry))) {
      counts$transforms <- counts$transforms + 1L
    } else {
      counts$other <- counts$other + 1L
    }
  }
  counts
}

#' Count incomplete / data-unavailable / missing-engine steps
#' @keywords internal
study_gap_step_counts <- function(entries) {
  out <- list(
    incomplete = 0L,
    data_unavailable = 0L,
    missing_engine = 0L
  )
  if (!is.list(entries) || !length(entries)) {
    return(out)
  }
  for (entry in entries) {
    if (!is.list(entry)) {
      next
    }
    gap <- classify_shiny_run_gap(entry, output_exists = FALSE)
    if (identical(gap$kind, "padlock")) {
      out$data_unavailable <- out$data_unavailable + 1L
    } else if (identical(gap$kind, "hammer")) {
      out$missing_engine <- out$missing_engine + 1L
    }
    inc <- entry$incomplete %||% NULL
    if (isTRUE(inc) || identical(tolower(as.character(inc[[1]] %||% "")), "true")) {
      out$incomplete <- out$incomplete + 1L
    }
  }
  out
}

#' Compact print for a study descriptor
#'
#' @param x A \code{replicate_study} object.
#' @param ... Ignored.
#' @return \code{x}, invisibly.
#' @export
#' @exportS3Method print replicate_study
print.replicate_study <- function(x, ...) {
  title <- trimws(as.character(x$title %||% ""))
  key <- trimws(as.character(x$doi %||% ""))
  if (!nzchar(key)) {
    key <- trimws(as.character(x$handle %||% ""))
  }
  if (nzchar(title)) {
    cat(title, "\n", sep = "")
  }
  if (nzchar(key)) {
    cat(key, "\n", sep = "")
  }
  cat("Use summary() for a study overview.\n")
  invisible(x)
}

#' Study overview (metadata, steps, related, gaps)
#'
#' @param object A \code{replicate_study} from \code{\link{get_study}}.
#' @param ... Ignored.
#' @return \code{object}, invisibly.
#'
#' @examples
#' \dontrun{
#' summary(get_study("10.1017/S0003055403000534"))
#' }
#'
#' @export
#' @exportS3Method summary replicate_study
summary.replicate_study <- function(object, ...) {
  title <- trimws(as.character(object$title %||% ""))
  doi <- trimws(as.character(object$doi %||% ""))
  handle <- trimws(as.character(object$handle %||% ""))
  authors <- trimws(as.character(object$authors %||% ""))
  journal <- trimws(as.character(object$journal %||% ""))
  year <- object$year
  collections <- trimws(as.character(object$collections %||% ""))
  languages <- trimws(as.character(object$languages %||% ""))
  maint_name <- trimws(as.character(object$maintainer_name %||% ""))
  maint_email <- trimws(as.character(object$maintainer_email %||% ""))
  repo <- normalize_repo_slug(object$repo %||% "")
  counts <- object$step_counts %||% list()
  gap_counts <- object$gap_counts %||% list()
  related <- object$related %||% list()

  cat("Study summary\n")
  cat(strrep("-", 40), "\n", sep = "")
  if (nzchar(title)) {
    cat("Title:       ", title, "\n", sep = "")
  }
  if (nzchar(doi)) {
    cat("DOI:         ", doi, "\n", sep = "")
  } else if (nzchar(handle)) {
    cat("Handle:      ", handle, "\n", sep = "")
  }
  cite_bits <- character(0)
  if (nzchar(authors)) {
    cite_bits <- c(cite_bits, authors)
  }
  if (nzchar(journal)) {
    cite_bits <- c(cite_bits, journal)
  }
  if (!is.null(year) && length(year) == 1L && !is.na(year)) {
    cite_bits <- c(cite_bits, as.character(year))
  }
  if (length(cite_bits)) {
    cat("Citation:    ", paste(cite_bits, collapse = " / "), "\n", sep = "")
  }
  if (nzchar(collections)) {
    cat("Collections: ", gsub("|", ", ", collections, fixed = TRUE), "\n", sep = "")
  }
  if (nzchar(languages)) {
    cat("Languages:   ", gsub(";", ", ", languages, fixed = TRUE), "\n", sep = "")
  }
  if (nzchar(maint_name) || nzchar(maint_email)) {
    maint <- maint_name
    if (nzchar(maint_email)) {
      maint <- if (nzchar(maint)) paste0(maint, " <", maint_email, ">") else maint_email
    }
    cat("Maintainer:  ", maint, "\n", sep = "")
  }
  if (nzchar(repo)) {
    cat("Repo:        ", paste0("https://github.com/", repo), "\n", sep = "")
  }

  n_steps <- as.integer(counts$steps %||% 0L)
  n_tab <- as.integer(counts$tables %||% 0L)
  n_fig <- as.integer(counts$figures %||% 0L)
  n_tr <- as.integer(counts$transforms %||% 0L)
  cat(
    "Steps:       ",
    n_steps,
    " (",
    n_tab, " table", if (n_tab == 1L) "" else "s", ", ",
    n_fig, " figure", if (n_fig == 1L) "" else "s", ", ",
    n_tr, " transform", if (n_tr == 1L) "" else "s",
    ")\n",
    sep = ""
  )

  up <- related$upstream %||% list()
  down <- related$downstream %||% list()
  if (length(up) || length(down)) {
    cat("Related:\n")
    for (item in up) {
      cat("  ↑ ", related_summary_line(item), "\n", sep = "")
    }
    for (item in down) {
      cat("  ↓ ", related_summary_line(item), "\n", sep = "")
    }
  } else {
    cat("Related:     (none)\n")
  }

  gap_bits <- character(0)
  n_inc <- as.integer(gap_counts$incomplete %||% 0L)
  n_data <- as.integer(gap_counts$data_unavailable %||% 0L)
  n_eng <- as.integer(gap_counts$missing_engine %||% 0L)
  if (n_inc > 0L) {
    gap_bits <- c(gap_bits, paste0(n_inc, " incomplete"))
  }
  if (n_data > 0L) {
    gap_bits <- c(gap_bits, paste0(n_data, " data unavailable"))
  }
  if (n_eng > 0L) {
    gap_bits <- c(gap_bits, paste0(n_eng, " missing engine"))
  }
  if (length(gap_bits)) {
    cat("Gaps:        ", paste(gap_bits, collapse = "; "), "\n", sep = "")
  } else {
    cat("Gaps:        (none)\n")
  }

  invisible(object)
}

#' One-line related study label for summary()
#' @keywords internal
related_summary_line <- function(item) {
  title <- trimws(as.character(item$title %||% ""))
  key <- trimws(as.character(item$key %||% ""))
  repo <- trimws(as.character(item$repo %||% ""))
  if (nzchar(title) && nzchar(key)) {
    return(paste0(title, " [", key, "]"))
  }
  if (nzchar(title)) {
    return(title)
  }
  if (nzchar(key)) {
    return(key)
  }
  if (nzchar(repo)) {
    return(repo)
  }
  "(unknown)"
}
