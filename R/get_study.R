#' Resolve a study handle (metadata once)
#'
#' Returns a compact \code{replicate_study} **handle**: registry index fields plus
#' step counts, related studies, and gap tags from the study
#' \code{replication.yml}, resolved once. Pass a journal DOI, registry handle
#' (e.g. \code{"rep-template"}), or \code{"local"} / a study path (see
#' [resolve_doi_input()]).
#'
#' Besides \code{\link{summary.replicate_study}} / [summary_study()] for a
#' console overview, use the handle to:
#' \itemize{
#'   \item Inspect fields programmatically (\code{st$doi}, \code{st$handle},
#'     \code{st$title}, \code{st$languages}, \code{st$step_counts},
#'     \code{st$related}, \code{st$gaps}, \code{st$repo}, \ldots).
#'   \item Feed DOI / handle strings into other consumer verbs — e.g.
#'     [list_replications()], [run_replication()], [check_replication()]
#'     (via a local path), [describe_study_dag()], [get_code()] — which take
#'     character keys, not the handle object itself:
#'     \code{list_replications(st$doi)} or \code{describe_study_dag(st$handle)}.
#'   \item Filter or join against [load_index()] / [search_papers()] results,
#'     or share the same resolved context with Shiny / reports.
#' }
#'
#' @param doi Character. DOI, registry handle, or \code{"local"} / study path
#'   (see [resolve_doi_input()]).
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return An object of class \code{replicate_study}.
#'
#' @examples
#' \dontrun{
#' # Fearon & Laitin (APSR 2003)
#' st <- get_study("10.1017/S0003055403000534")
#' summary(st)
#' st$doi
#' st$languages
#' st$step_counts
#' list_replications(st$doi)
#' describe_study_dag(st$doi)
#'
#' # Blair et al. (APSR 2022); Acemoglu et al. (AER 2001); template handle
#' get_study("10.1017/S0003055422000284")
#' get_study("10.1257/aer.91.5.1369")
#' get_study("rep-template")
#'
#' # Reanalysis handle (no journal DOI on the extension itself)
#' summary_study("rep-10.1017-S0003055403000534--alt-1")
#' }
#'
#' @seealso [summary.replicate_study()], [summary_study()], [list_replications()],
#'   [describe_study_dag()], [run_replication()], [load_index()]
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
    y <- index_row_field(row, "year", "")
    if (!nzchar(y)) NA_character_ else y
  } else {
    normalize_registry_year(paper$year)
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
  source_repositories <- paper_source_repositories(paper = paper)
  source_repository <- if (length(source_repositories)) {
    source_repositories[[1L]]
  } else {
    NULL
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
      source_repository = source_repository %||% "",
      source_repository_kind = if (!is.null(source_repository) && nzchar(source_repository)) {
        source_repository_kind(source_repository)
      } else {
        ""
      },
      source_repositories = as.list(source_repositories),
      source_repository_kinds = as.list(
        if (length(source_repositories)) {
          vapply(source_repositories, source_repository_kind, character(1))
        } else {
          character(0)
        }
      ),
      folder = if (!is.null(row)) index_row_field(row, "folder", "") else ""
    ),
    class = "replicate_study"
  )
}

#' Summarize a study by DOI / handle (constructs then summarizes)
#'
#' Convenience wrapper around \code{summary(get_study(doi))}. Prefer
#' [get_study()] when you need the handle for field access or downstream
#' verbs; use this when you only want the printed overview.
#'
#' @inheritParams get_study
#' @param ... Passed to \code{\link{summary.replicate_study}}.
#' @return Invisibly, the \code{replicate_study} object.
#'
#' @examples
#' \dontrun{
#' summary_study("10.1017/S0003055403000534")
#' summary_study("10.1017/S0003055422000284")
#' summary_study("10.1257/aer.91.5.1369")
#' summary_study("rep-template")
#' summary_study("rep-10.1017-S0003055403000534--alt-1")
#' }
#'
#' @seealso [get_study()], [summary.replicate_study()]
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
#' Prints title and DOI/handle; points to \code{summary()} for the full
#' overview. See [get_study()] for field access and passing keys to other verbs.
#'
#' @param x A \code{replicate_study} object.
#' @param ... Ignored.
#' @return \code{x}, invisibly.
#'
#' @examples
#' \dontrun{
#' get_study("10.1017/S0003055403000534")
#' get_study("rep-template")
#' }
#'
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
#' Console overview for a [get_study()] handle: citation fields, step counts,
#' related upstream/downstream studies, and gap tags. For programmatic access
#' to the same information, read fields on the handle (e.g. \code{object$doi},
#' \code{object$step_counts}) rather than parsing this printout.
#'
#' @param object A \code{replicate_study} from \code{\link{get_study}}.
#' @param ... Ignored.
#' @return \code{object}, invisibly.
#'
#' @examples
#' \dontrun{
#' summary(get_study("10.1017/S0003055403000534"))
#' summary(get_study("10.1257/aer.91.5.1369"))
#' summary(get_study("rep-template"))
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
  srcs <- normalize_source_repository_values(object$source_repositories %||% NULL)
  if (!length(srcs)) {
    srcs <- normalize_source_repository_values(object$source_repository %||% "")
  }
  if (length(srcs)) {
    kinds <- normalize_source_repository_values(object$source_repository_kinds %||% NULL)
    for (i in seq_along(srcs)) {
      kind <- if (length(kinds) >= i) kinds[[i]] else {
        trimws(as.character(object$source_repository_kind %||% ""))
      }
      kind_bit <- if (nzchar(kind %||% "")) paste0(" [", kind, "]") else ""
      prefix <- if (length(srcs) > 1L && i == 1L) {
        "Sources:     "
      } else if (length(srcs) > 1L) {
        "             "
      } else {
        "Source:      "
      }
      cat(prefix, srcs[[i]], kind_bit, "\n", sep = "")
    }
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
