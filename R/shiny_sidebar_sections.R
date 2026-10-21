#' Whether a sidebar label is the reserved Steps token
#'
#' Matches \code{"Steps"} / \code{"steps"} and legacy \code{"Data steps"}
#' (case-insensitive). Transform / prep rows do not need \code{family: Steps};
#' the token only positions the data block in root \code{sidebar:}.
#'
#' @param label Character scalar (or length-1 vector).
#' @return Logical scalar.
#' @keywords internal
is_sidebar_steps_label <- function(label) {
  val <- tolower(trimws(as.character(label[[1]] %||% label %||% "")))
  identical(val, "steps") || identical(val, "data steps")
}

#' Study-level sidebar section titles (ordered)
#'
#' Reads optional root \code{sidebar:} from \code{replication.yml}. Each
#' entry is a section heading string (e.g. \code{"SI Figures"}) or the
#' reserved \code{"Steps"} token for the prep/transform block. Empty when
#' omitted — Shiny then uses legacy type-run-length headings unless steps
#' declare \code{family:}.
#'
#' @param meta Parsed study metadata (list).
#' @return Character vector of section titles (may be length 0; may include
#'   \code{"Steps"}).
#' @keywords internal
study_sidebar_section_labels <- function(meta) {
  if (is.null(meta) || !is.list(meta)) {
    return(character(0))
  }
  raw <- meta$sidebar %||% NULL
  if (is.null(raw) || !length(raw)) {
    return(character(0))
  }
  labels <- vapply(raw, function(x) {
    if (is.list(x)) {
      as.character(x$label[[1]] %||% x$title[[1]] %||% x$id[[1]] %||% x[[1]] %||% "")
    } else {
      as.character(x[[1]] %||% x)
    }
  }, character(1))
  labels <- trimws(labels)
  labels[nzchar(labels)]
}

#' Exhibit-only labels from root \code{sidebar:} (Steps token stripped)
#'
#' @param meta Parsed study metadata (list), or a character vector of labels.
#' @return Character vector of exhibit section titles.
#' @keywords internal
study_sidebar_exhibit_labels <- function(meta) {
  labs <- if (is.character(meta)) {
    trimws(as.character(meta))
  } else {
    study_sidebar_section_labels(meta)
  }
  labs <- labs[nzchar(labs)]
  if (!length(labs)) {
    return(character(0))
  }
  labs[!vapply(labs, is_sidebar_steps_label, logical(1))]
}

#' Unified sidebar render plan (exhibit sections + optional Steps)
#'
#' Single root \code{sidebar:} orders both exhibit families and the
#' prep/transform block. Reserved token \code{Steps} (also \code{steps},
#' legacy \code{Data steps}) marks where the data block appears.
#'
#' Behavior:
#' \itemize{
#'   \item \code{sidebar:} omitted — legacy: data block first with heading
#'     \strong{Data steps}, then exhibit sections.
#'   \item \code{sidebar:} present with \code{Steps} — data block at that
#'     position, heading \strong{Steps}. Empty Steps (no data rows) is omitted.
#'   \item \code{sidebar:} present without \code{Steps} but data rows exist —
#'     prepend data block at top (heading \strong{Steps}) so exhibit-only
#'     lists keep the old default.
#' }
#'
#' @param sidebar_labels Full root \code{sidebar:} labels (may include Steps).
#' @param exhibit_sections List of \code{list(title=, rows=)} from
#'   [exhibit_sidebar_sections()] or [exhibit_type_run_sections()].
#' @param has_data Logical: whether prep/transform rows exist to show.
#' @return List of items: \code{list(kind="data", title=...)} or
#'   \code{list(kind="exhibit", title=..., rows=...)}.
#' @keywords internal
sidebar_unified_plan <- function(
  sidebar_labels = character(0),
  exhibit_sections = list(),
  has_data = FALSE
) {
  sidebar_labels <- as.character(sidebar_labels %||% character(0))
  sidebar_labels <- trimws(sidebar_labels)
  sidebar_labels <- sidebar_labels[nzchar(sidebar_labels)]
  has_data <- isTRUE(has_data)

  sec_by_title <- list()
  sec_order <- character(0)
  for (sec in exhibit_sections) {
    title <- as.character(sec$title %||% "")
    if (!nzchar(title)) {
      next
    }
    if (is.null(sec_by_title[[title]])) {
      sec_by_title[[title]] <- sec
      sec_order <- c(sec_order, title)
    }
  }

  plan <- list()
  append_data <- function(title) {
    if (!has_data) {
      return(invisible(NULL))
    }
    plan[[length(plan) + 1L]] <<- list(kind = "data", title = title)
    invisible(NULL)
  }
  append_exhibit <- function(title) {
    sec <- sec_by_title[[title]]
    if (is.null(sec)) {
      return(invisible(NULL))
    }
    plan[[length(plan) + 1L]] <<- list(
      kind = "exhibit",
      title = title,
      rows = sec$rows
    )
    sec_by_title[[title]] <<- NULL
    invisible(NULL)
  }

  if (!length(sidebar_labels)) {
    # Legacy: no sidebar: — Data steps at top, existing heading string.
    append_data("Data steps")
    for (title in sec_order) {
      append_exhibit(title)
    }
    return(plan)
  }

  steps_in_list <- any(vapply(sidebar_labels, is_sidebar_steps_label, logical(1)))
  if (has_data && !steps_in_list) {
    # Section mode without Steps entry: keep data at top (old default).
    append_data("Steps")
  }

  data_emitted <- FALSE
  for (lab in sidebar_labels) {
    if (is_sidebar_steps_label(lab)) {
      if (!data_emitted) {
        append_data("Steps")
        data_emitted <- TRUE
      }
    } else if (!is.null(sec_by_title[[lab]])) {
      append_exhibit(lab)
    }
  }

  for (title in sec_order) {
    if (!is.null(sec_by_title[[title]])) {
      append_exhibit(title)
    }
  }

  plan
}

#' Sidebar family label for one display step
#'
#' Uses step \code{family:} when set; otherwise defaults to \code{"Figures"}
#' or \code{"Tables"} from \code{type:} (same strings as legacy Shiny headings).
#'
#' @param rep A single replication / step entry (list) or a one-row data.frame.
#' @return Character scalar section title.
#' @keywords internal
step_sidebar_family <- function(rep) {
  if (is.null(rep)) {
    return("Tables")
  }
  fam <- if (is.data.frame(rep)) {
    as.character(rep$family[[1]] %||% "")
  } else if (is.list(rep)) {
    as.character(rep$family[[1]] %||% rep$family %||% "")
  } else {
    ""
  }
  fam <- trimws(fam)
  if (nzchar(fam)) {
    return(fam)
  }
  typ <- if (is.data.frame(rep)) {
    tolower(as.character(rep$type[[1]] %||% ""))
  } else if (is.list(rep)) {
    tolower(as.character(rep$type[[1]] %||% rep$type %||% ""))
  } else {
    ""
  }
  if (identical(typ, "figure")) {
    "Figures"
  } else {
    "Tables"
  }
}

#' Whether exhibit sidebar should use explicit section mode
#'
#' Section mode when the study declares root \code{sidebar:} exhibit labels
#' (ignoring the reserved \code{Steps} token) and/or any display step declares
#' \code{family:}. Otherwise Shiny keeps legacy type-run-length headings
#' (\code{Figures} / \code{Tables}).
#'
#' @param meta Parsed study metadata (list), or \code{NULL}.
#' @param reps List of step entries and/or a replications data.frame with an
#'   optional \code{family} column.
#' @return Logical scalar.
#' @keywords internal
study_uses_sidebar_sections <- function(meta = NULL, reps = NULL) {
  if (length(study_sidebar_exhibit_labels(meta)) > 0L) {
    return(TRUE)
  }
  if (is.null(reps)) {
    return(FALSE)
  }
  if (is.data.frame(reps)) {
    if (!"family" %in% names(reps)) {
      return(FALSE)
    }
    fams <- as.character(reps$family %||% character(0))
    return(any(nzchar(trimws(fams))))
  }
  if (!is.list(reps) || !length(reps)) {
    return(FALSE)
  }
  any(vapply(reps, function(x) {
    if (!is.list(x)) {
      return(FALSE)
    }
    fam <- as.character(x$family[[1]] %||% x$family %||% "")
    nzchar(trimws(fam))
  }, logical(1)))
}

#' Ordered exhibit sidebar sections for Shiny
#'
#' Builds \code{list(list(title = ..., rows = <data.frame>), ...)} for
#' figure/table rows. Section order follows root \code{sidebar:} when set
#' (non-empty sections only; reserved \code{Steps} token ignored), then any
#' leftover family labels in first-appearance order among \code{exhibit}.
#' Within a section, row order is preserved. Does not build the data block
#' (see [sidebar_unified_plan()]).
#'
#' @param exhibit Data frame of figure/table rows (yaml / sidebar order).
#' @param sidebar_labels Character vector from [study_sidebar_section_labels()]
#'   (Steps tokens are stripped automatically).
#' @return List of sections with \code{title} and \code{rows}.
#' @keywords internal
exhibit_sidebar_sections <- function(exhibit, sidebar_labels = character(0)) {
  if (is.null(exhibit) || !is.data.frame(exhibit) || nrow(exhibit) == 0L) {
    return(list())
  }
  n <- nrow(exhibit)
  families <- character(n)
  for (i in seq_len(n)) {
    families[[i]] <- step_sidebar_family(exhibit[i, , drop = FALSE])
  }
  sidebar_labels <- study_sidebar_exhibit_labels(as.character(sidebar_labels %||% character(0)))

  appearance <- unique(families)
  ordered <- character(0)
  for (lab in sidebar_labels) {
    if (lab %in% appearance && !lab %in% ordered) {
      ordered <- c(ordered, lab)
    }
  }
  for (lab in appearance) {
    if (!lab %in% ordered) {
      ordered <- c(ordered, lab)
    }
  }

  sections <- vector("list", length(ordered))
  for (j in seq_along(ordered)) {
    title <- ordered[[j]]
    idx <- which(families == title)
    sections[[j]] <- list(
      title = title,
      rows = exhibit[idx, , drop = FALSE]
    )
  }
  sections
}

#' Legacy type-run-length exhibit blocks (Figures / Tables)
#'
#' Same heading behavior as pre-section-mode Shiny: a heading whenever
#' consecutive exhibit rows change between figure and table.
#'
#' @param exhibit Data frame of figure/table rows.
#' @return List of sections with \code{title} and \code{rows}.
#' @keywords internal
exhibit_type_run_sections <- function(exhibit) {
  if (is.null(exhibit) || !is.data.frame(exhibit) || nrow(exhibit) == 0L) {
    return(list())
  }
  types <- as.character(exhibit$type)
  change <- c(TRUE, types[-1L] != types[-length(types)])
  starts <- which(change)
  ends <- c(starts[-1L] - 1L, length(types))
  sections <- vector("list", length(starts))
  for (b in seq_along(starts)) {
    block <- exhibit[starts[[b]]:ends[[b]], , drop = FALSE]
    title <- if (identical(types[[starts[[b]]]], "figure")) "Figures" else "Tables"
    sections[[b]] <- list(title = title, rows = block)
  }
  sections
}
