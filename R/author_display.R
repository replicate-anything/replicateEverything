#' Detect Stata-style middle initials in author names
#' @keywords internal
is_author_middle_initial <- function(part) {
  grepl("^[A-Za-z]\\.?$", part)
}

#' Extract the surname from a single author name
#'
#' Handles middle initials (e.g. \dquote{Robert A. Blair} \eqn{\rightarrow} Blair)
#' and compound surnames (e.g. \dquote{Andrés Vargas Castillo} \eqn{\rightarrow}
#' Vargas Castillo).
#' @param name Character scalar.
#' @return Character scalar.
#' @keywords internal
first_author_surname <- function(name) {
  parts <- strsplit(trimws(name), "\\s+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0) {
    return("Unknown")
  }
  if (length(parts) == 1) {
    return(parts[[1]])
  }

  if (length(parts) > 2) {
    drop <- vapply(
      seq_along(parts),
      function(i) {
        i > 1L && i < length(parts) && is_author_middle_initial(parts[[i]])
      },
      logical(1L)
    )
    parts <- parts[!drop]
  }

  if (length(parts) == 1) {
    return(parts[[1]])
  }
  if (length(parts) == 2) {
    return(parts[[2]])
  }

  paste(tail(parts, 2L), collapse = " ")
}

#' Short author label for dropdowns (e.g. Blair et al)
#' @keywords internal
format_author_label <- function(authors_str) {
  authors <- trimws(strsplit(authors_str %||% "", ",\\s*")[[1]])
  authors <- authors[nzchar(authors)]
  if (length(authors) == 0) {
    return("Unknown")
  }
  lead <- first_author_surname(authors[[1]])
  if (length(authors) == 1) {
    return(lead)
  }
  if (length(authors) == 2) {
    return(paste0(lead, " and ", first_author_surname(authors[[2]])))
  }
  paste0(lead, " et al")
}

#' Full author list for study details panel
#' @keywords internal
format_authors_summary <- function(authors_str) {
  authors <- trimws(strsplit(authors_str %||% "", ",\\s*")[[1]])
  authors <- authors[nzchar(authors)]
  n <- length(authors)
  if (n == 0) {
    return("Unknown")
  }
  if (n > 4L) {
    return(paste0(paste(head(authors, 4L), collapse = ", "), ", et al."))
  }
  if (n == 1L) {
    return(authors[[1]])
  }
  if (n == 2L) {
    return(paste(authors, collapse = " and "))
  }
  paste0(paste(head(authors, n - 1L), collapse = ", "), ", and ", authors[[n]])
}
