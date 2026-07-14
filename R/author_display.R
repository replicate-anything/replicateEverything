#' Detect Stata-style middle initials in author names
#' @keywords internal
is_author_middle_initial <- function(part) {
  grepl("^[A-Za-z]\\.?$", part)
}

#' Split a comma-separated author list without breaking "Last, First" pairs
#' @keywords internal
parse_author_names <- function(authors_str) {
  authors_str <- as.character(authors_str %||% "")
  if (!nzchar(trimws(authors_str))) {
    return(character(0))
  }
  parts <- trimws(strsplit(authors_str, ",\\s*")[[1]])
  parts <- parts[nzchar(parts)]
  if (length(parts) <= 1L) {
    return(parts)
  }

  authors <- character(0)
  buffer <- parts[[1]]
  for (i in seq(2L, length(parts))) {
    part <- parts[[i]]
    if (!nzchar(buffer) || !grepl("\\s", buffer, perl = TRUE)) {
      buffer <- if (!nzchar(buffer)) part else paste0(buffer, ", ", part)
      if (grepl("\\s", buffer, perl = TRUE)) {
        authors <- c(authors, buffer)
        buffer <- ""
      }
    } else {
      authors <- c(authors, buffer)
      buffer <- part
    }
  }
  if (nzchar(buffer)) {
    authors <- c(authors, buffer)
  }
  authors[nzchar(authors)]
}

#' Whether an author string is already in "Last, First ..." form
#' @keywords internal
author_name_has_comma_form <- function(name) {
  name <- trimws(as.character(name %||% ""))
  if (!nzchar(name) || !grepl(",", name, fixed = TRUE)) {
    return(FALSE)
  }
  before <- trimws(sub(",.*$", "", name))
  after <- trimws(sub("^[^,]+,\\s*", "", name))
  nzchar(before) && nzchar(after)
}

#' Format one author as "Last, First [Middle ...]"
#' @keywords internal
format_author_name <- function(name) {
  name <- trimws(as.character(name %||% ""))
  if (!nzchar(name)) {
    return("Unknown")
  }
  if (author_name_has_comma_form(name)) {
    surname <- trimws(sub(",.*$", "", name))
    given <- trimws(sub("^[^,]+,\\s*", "", name))
    return(paste0(surname, ", ", given))
  }

  parts <- strsplit(name, "\\s+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) {
    return("Unknown")
  }
  if (length(parts) == 1L) {
    return(parts[[1]])
  }

  drop <- rep(FALSE, length(parts))
  if (length(parts) > 2L) {
    drop <- vapply(
      seq_along(parts),
      function(i) {
        i > 1L && i < length(parts) && is_author_middle_initial(parts[[i]])
      },
      logical(1L)
    )
    parts <- parts[!drop]
  }
  if (length(parts) == 1L) {
    return(parts[[1]])
  }
  if (length(parts) == 2L) {
    return(paste0(parts[[2]], ", ", parts[[1]]))
  }
  surname <- if (length(parts) >= 3L) {
    paste(tail(parts, 2L), collapse = " ")
  } else {
    parts[[length(parts)]]
  }
  given <- paste(head(parts, length(parts) - if (length(parts) >= 3L) 2L else 1L), collapse = " ")
  paste0(surname, ", ", given)
}

#' Extract the surname from a single author name
#'
#' Handles "Last, First", middle initials (e.g. \dQuote{Robert A. Blair}),
#' and compound surnames (e.g. \dQuote{Andrés Vargas Castillo}).
#' @param name Character scalar.
#' @return Character scalar.
#' @keywords internal
first_author_surname <- function(name) {
  name <- trimws(as.character(name %||% ""))
  if (!nzchar(name)) {
    return("Unknown")
  }
  if (author_name_has_comma_form(name)) {
    return(trimws(sub(",.*$", "", name)))
  }

  parts <- strsplit(name, "\\s+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0L) {
    return("Unknown")
  }
  if (length(parts) == 1L) {
    return(parts[[1]])
  }

  if (length(parts) > 2L) {
    drop <- vapply(
      seq_along(parts),
      function(i) {
        i > 1L && i < length(parts) && is_author_middle_initial(parts[[i]])
      },
      logical(1L)
    )
    parts <- parts[!drop]
  }

  if (length(parts) == 1L) {
    return(parts[[1]])
  }
  if (length(parts) == 2L) {
    return(parts[[2]])
  }

  paste(tail(parts, 2L), collapse = " ")
}

#' Short author label for dropdowns (e.g. Velez et al)
#' @keywords internal
format_author_label <- function(authors_str) {
  authors <- parse_author_names(authors_str)
  if (length(authors) == 0L) {
    return("Unknown")
  }
  lead <- first_author_surname(authors[[1]])
  if (length(authors) == 1L) {
    return(lead)
  }
  if (length(authors) == 2L) {
    return(paste0(lead, " and ", first_author_surname(authors[[2]])))
  }
  paste0(lead, " et al")
}

#' Full author list for study details panel
#' @keywords internal
format_authors_summary <- function(authors_str) {
  authors <- parse_author_names(authors_str)
  formatted <- vapply(authors, format_author_name, character(1L))
  n <- length(formatted)
  if (n == 0L) {
    return("Unknown")
  }
  if (n > 4L) {
    return(paste0(paste(head(formatted, 4L), collapse = ", "), ", et al."))
  }
  if (n == 1L) {
    return(formatted[[1]])
  }
  if (n == 2L) {
    return(paste(formatted, collapse = " and "))
  }
  paste0(paste(head(formatted, n - 1L), collapse = ", "), ", and ", formatted[[n]])
}
