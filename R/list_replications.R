#' List available replications for a paper
#'
#' Returns step entries from \code{replication.yml}: tables, figures, and (when
#' requested) pipeline transforms. Use \code{grouped = TRUE} for one entry per
#' logical product (e.g. a single \code{tab_1} when both R and Stata exist).
#'
#' @param doi Character. DOI, registry handle, or local study path.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @param grouped Logical. When \code{TRUE}, return one entry per logical
#'   table/figure group (R preferred when \code{language} is unset).
#' @param language Optional \code{"R"}, \code{"stata"}, or \code{"python"} when
#'   \code{grouped = TRUE}.
#' @param include Which steps to return: \code{"display"} (tables and figures,
#'   default), \code{"pipeline"} (transform / prep steps), or \code{"all"}
#'   (every non-format step).
#' @return A \code{replication_list} object (a list with a compact
#'   \code{print()} method).
#'
#' @examples
#' \dontrun{
#' list_replications("10.1177/00491241211036161")
#' list_replications("10.1257/aer.91.5.1369", grouped = TRUE)
#' list_replications("10.1257/aer.91.5.1369", grouped = TRUE, language = "stata")
#' list_replications("10.1017/s0003055426101749", include = "pipeline")
#' }
#'
#' @export
list_replications <- function(
  doi,
  repo = NULL,
  folder = NULL,
  grouped = FALSE,
  language = NULL,
  include = c("display", "pipeline", "all")
) {
  include <- match.arg(include)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  reps <- filter_replication_entries(meta, include = include)
  wrap <- function(x) {
    as_replication_list(
      x,
      doi = normalize_doi(meta$paper$doi %||% doi),
      title = as.character(meta$paper$title %||% "")
    )
  }

  if (grouped) {
    return(wrap(list_replication_groups_impl(
      meta,
      entries = reps,
      language = language,
      display_only = include != "pipeline"
    )))
  }

  if (length(reps) > 0L) {
    return(wrap(reps))
  }

  if (include == "pipeline") {
    return(wrap(list()))
  }

  if (is_package_replication(meta)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
    pkg_meta <- fetch_package_replication_yaml(meta, ctx)
    if (!is.null(pkg_meta)) {
      legacy <- c(pkg_meta$prep %||% list(), pkg_meta$replications %||% list())
      return(wrap(filter_replication_entries(list(steps = legacy), include = include)))
    }
    pkg <- as.character(meta$paper$package[[1]])
    ensure_replication_package(pkg, meta = meta, ctx = ctx)
    if (replication_package_usable(pkg)) {
      pkg_meta <- tryCatch(
        read_package_replication_meta(pkg),
        error = function(e) NULL
      )
      if (!is.null(pkg_meta)) {
        legacy <- package_yaml_entries(pkg_meta)
        return(wrap(filter_replication_entries(list(steps = legacy), include = include)))
      }
      ns <- asNamespace(pkg)
      if (exists("list_replications", envir = ns, inherits = FALSE)) {
        out <- call_replication_package(pkg, "list_replications")
        return(wrap(out))
      }
    }
  }
  if (is_folder_study_replication(meta)) {
    ctx <- paper_context(doi, repo = repo, folder = folder)
    study_meta <- fetch_folder_study_replication_yaml(meta, ctx)
    if (!is.null(study_meta)) {
      legacy <- c(study_meta$prep %||% list(), study_meta$replications %||% list())
      return(wrap(filter_replication_entries(list(steps = legacy), include = include)))
    }
  }
  wrap(reps)
}

#' Attach replication_list class and study metadata for printing
#' @keywords internal
as_replication_list <- function(x, doi = NULL, title = NULL) {
  structure(
    x,
    class = c("replication_list", "list"),
    doi = doi,
    title = title
  )
}

#' Compact print method for replication step lists
#' @param x A \code{replication_list} object.
#' @param n Maximum rows to display.
#' @param ... Ignored.
#' @keywords internal
#' @exportS3Method print replication_list
print.replication_list <- function(x, n = 20, ...) {
  title <- attr(x, "title", exact = TRUE)
  doi <- attr(x, "doi", exact = TRUE)
  if (!is.null(title) && nzchar(as.character(title))) {
    cat("Replications: ", title, sep = "")
    if (!is.null(doi) && nzchar(as.character(doi))) {
      cat(" [", doi, "]", sep = "")
    }
    cat("\n")
  }
  if (length(x) == 0L) {
    cat("(none listed)\n")
    return(invisible(x))
  }

  rows <- lapply(x, function(entry) {
    label <- as.character(entry$label %||% entry$description %||% entry$id %||% "")
    if (length(label) > 1L) {
      label <- label[[1]]
    }
    if (nchar(label) > 48L) {
      label <- paste0(substr(label, 1, 45L), "...")
    }
    data.frame(
      id = as.character(entry$id %||% ""),
      type = as.character(entry$type %||% ""),
      engine = replication_engine(entry),
      label = label,
      stringsAsFactors = FALSE
    )
  })
  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  if (nrow(df) > n) {
    print(utils::head(df, n), row.names = FALSE)
    cat("[ ", nrow(df) - n, " more row(s) not shown ]\n", sep = "")
  } else {
    print(df, row.names = FALSE)
  }
  invisible(x)
}

#' Filter step entries by display / pipeline / all
#' @keywords internal
filter_replication_entries <- function(meta, include = c("display", "pipeline", "all")) {
  include <- match.arg(include)
  reps <- collect_replication_entries(meta)
  if (length(reps) == 0L) {
    return(reps)
  }
  if (identical(include, "all")) {
    return(reps)
  }
  if (identical(include, "pipeline")) {
    return(reps[vapply(reps, is_prep_entry, logical(1))])
  }
  reps[vapply(reps, function(x) {
    type <- tolower(as.character(x$type %||% ""))
    type %in% c("figure", "table")
  }, logical(1))]
}

#' One replication entry per logical group (internal)
#' @keywords internal
list_replication_groups_impl <- function(
  meta,
  entries = NULL,
  language = NULL,
  display_only = TRUE
) {
  entries <- entries %||% collect_replication_entries(meta)
  if (display_only) {
    entries <- entries[vapply(entries, function(x) {
      type <- as.character(x$type %||% "")
      type %in% c("figure", "table")
    }, logical(1))]
  }
  if (length(entries) == 0L) {
    return(list())
  }
  groups <- unique(vapply(entries, replication_logical_id, character(1)))
  lapply(groups, function(g) {
    find_replication_entry(meta, g, language = language)
  })
}
