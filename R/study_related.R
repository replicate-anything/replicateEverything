#' Registry key used for related-study links (DOI when present, else handle)
#' @keywords internal
index_row_related_key <- function(row) {
  if (!is.data.frame(row) || nrow(row) < 1L) {
    return("")
  }
  doi_val <- trimws(as.character(index_row_field(row, "doi", "")))
  if (nzchar(doi_val)) {
    return(normalize_doi(doi_val))
  }
  handle <- trimws(as.character(index_row_field(row, "handle", "")))
  if (nzchar(handle)) {
    return(handle)
  }
  trimws(as.character(index_row_field(row, "folder", "")))
}

#' Parse pipe-separated related keys from an index cell
#' @keywords internal
parse_related_keys <- function(x) {
  raw <- trimws(as.character(x %||% ""))
  if (!nzchar(raw) || is.na(raw)) {
    return(character(0))
  }
  parts <- strsplit(raw, "|", fixed = TRUE)[[1]]
  parts <- trimws(parts)
  unique(parts[nzchar(parts)])
}

#' Encode related keys for index.csv
#' @keywords internal
encode_related_keys <- function(keys) {
  keys <- unique(trimws(as.character(keys %||% character(0))))
  keys <- keys[nzchar(keys) & !is.na(keys)]
  paste(keys, collapse = "|")
}

#' Normalize a GitHub repo slug for matching
#' @keywords internal
normalize_repo_slug <- function(repo) {
  repo <- trimws(as.character(repo %||% ""))
  if (!nzchar(repo)) {
    return("")
  }
  repo <- sub("^https?://github.com/", "", repo, ignore.case = TRUE)
  repo <- sub("\\.git$", "", repo)
  trimws(repo)
}

#' Collect upstream pointers from study / stub metadata
#'
#' Prefers \code{paper.extends} (inheritance) and \code{paper.related}
#' (explicit citation of the original). Each entry is a list with optional
#' \code{doi}, \code{repo}, \code{handle}, \code{label}, and \code{source}.
#'
#' @param meta Parsed replication.yml or registry stub.
#' @return List of upstream reference lists.
#' @keywords internal
study_upstream_refs_from_meta <- function(meta) {
  refs <- list()
  if (is.null(meta) || !is.list(meta)) {
    return(refs)
  }
  paper <- meta$paper %||% list()

  extends <- paper$extends %||% meta$extends %||% NULL
  if (is.list(extends) && length(extends) > 0L) {
    refs[[length(refs) + 1L]] <- list(
      doi = extends$doi %||% NULL,
      repo = extends$repo %||% NULL,
      handle = extends$handle %||% extends$study_handle %||% NULL,
      label = extends$label %||% NULL,
      source = "extends"
    )
  }

  related <- paper$related %||% meta$related %||% NULL
  if (is.null(related) || length(related) == 0L) {
    return(refs)
  }
  # Single named related block vs list of related items
  if (
    is.list(related) &&
      !is.null(names(related)) &&
      any(c("doi", "repo", "handle", "study_handle", "label") %in% names(related)) &&
      !is.list(related[[1]])
  ) {
    related <- list(related)
  }
  for (item in related) {
    if (!is.list(item)) {
      next
    }
    refs[[length(refs) + 1L]] <- list(
      doi = item$doi %||% NULL,
      repo = item$repo %||% NULL,
      handle = item$handle %||% item$study_handle %||% NULL,
      label = item$label %||% NULL,
      source = "related"
    )
  }
  refs
}

#' Match one upstream ref to a registry index row index (1-based) or NA
#' @keywords internal
match_related_ref_to_index <- function(ref, index) {
  if (!is.data.frame(index) || nrow(index) == 0L) {
    return(NA_integer_)
  }
  index <- ensure_index_handles(index)

  doi_raw <- trimws(as.character(ref$doi[[1]] %||% ref$doi %||% ""))
  if (nzchar(doi_raw)) {
    doi_norm <- normalize_doi(doi_raw)
    index_dois <- vapply(as.character(index$doi %||% ""), function(x) {
      x <- trimws(x)
      if (!nzchar(x)) {
        return(NA_character_)
      }
      normalize_doi(x)
    }, character(1))
    hit <- which(!is.na(index_dois) & index_dois == doi_norm)
    if (length(hit) > 0L) {
      return(hit[[1]])
    }
    folders <- tolower(as.character(index$folder %||% ""))
    folder_from_doi <- tolower(doi_to_registry_folder(doi_norm))
    hit <- which(folders == folder_from_doi)
    if (length(hit) > 0L) {
      return(hit[[1]])
    }
  }

  handle_raw <- trimws(as.character(
    ref$handle[[1]] %||% ref$handle %||% ref$study_handle %||% ""
  ))
  if (nzchar(handle_raw)) {
    handles <- tolower(as.character(index$handle %||% ""))
    folders <- tolower(as.character(index$folder %||% ""))
    hit <- which(handles == tolower(handle_raw) | folders == tolower(handle_raw))
    if (length(hit) > 0L) {
      return(hit[[1]])
    }
  }

  repo_raw <- normalize_repo_slug(ref$repo[[1]] %||% ref$repo %||% "")
  if (nzchar(repo_raw)) {
    repos <- vapply(as.character(index$repo %||% ""), normalize_repo_slug, character(1))
    hit <- which(tolower(repos) == tolower(repo_raw))
    if (length(hit) > 0L) {
      return(hit[[1]])
    }
    # Match by repo basename (rep-…) against folder / handle
    base <- study_repo_folder_name(repo_raw)
    if (nzchar(base)) {
      folders <- tolower(as.character(index$folder %||% ""))
      handles <- tolower(as.character(index$handle %||% ""))
      hit <- which(folders == tolower(base) | handles == tolower(base))
      if (length(hit) > 0L) {
        return(hit[[1]])
      }
    }
  }

  NA_integer_
}

#' Resolve upstream keys for one study meta against the registry index
#'
#' Returns matched registry keys when possible; otherwise a normalized DOI
#' (so Shiny can still link out to doi.org).
#'
#' @keywords internal
resolve_upstream_keys_for_meta <- function(meta, index) {
  refs <- study_upstream_refs_from_meta(meta)
  if (length(refs) == 0L) {
    return(character(0))
  }
  keys <- character(0)
  for (ref in refs) {
    hit <- match_related_ref_to_index(ref, index)
    if (!is.na(hit)) {
      keys <- c(keys, index_row_related_key(index[hit, , drop = FALSE]))
      next
    }
    doi_raw <- trimws(as.character(ref$doi[[1]] %||% ref$doi %||% ""))
    if (nzchar(doi_raw)) {
      keys <- c(keys, normalize_doi(doi_raw))
    }
  }
  unique(keys[nzchar(keys)])
}

#' Fill related_upstream / related_downstream on a registry index
#'
#' Upstream comes from each study's \code{paper.related} / \code{paper.extends}.
#' Downstream is the reverse map: if B points at A, A lists B.
#'
#' @param index Registry index data frame.
#' @param metas Optional list of stub/study metas aligned with \code{index} rows.
#'   When \code{NULL}, only ensures empty related columns exist.
#' @return Index with \code{related_upstream} and \code{related_downstream}.
#' @keywords internal
annotate_index_related <- function(index, metas = NULL) {
  if (!is.data.frame(index) || nrow(index) == 0L) {
    if (is.data.frame(index)) {
      if (!"related_upstream" %in% names(index)) {
        index$related_upstream <- character(0)
      }
      if (!"related_downstream" %in% names(index)) {
        index$related_downstream <- character(0)
      }
    }
    return(index)
  }
  index <- ensure_index_handles(index)
  n <- nrow(index)
  upstream <- rep("", n)
  downstream_lists <- vector("list", n)

  if (is.list(metas) && length(metas) == n) {
    for (i in seq_len(n)) {
      keys <- resolve_upstream_keys_for_meta(metas[[i]], index)
      upstream[i] <- encode_related_keys(keys)
      self_key <- index_row_related_key(index[i, , drop = FALSE])
      for (uk in keys) {
        # Only tag reverse links for studies that resolve inside the registry
        hit <- match_related_ref_to_index(list(doi = uk, handle = uk), index)
        if (is.na(hit) || hit == i) {
          next
        }
        downstream_lists[[hit]] <- c(downstream_lists[[hit]], self_key)
      }
    }
  }

  downstream <- vapply(seq_len(n), function(i) {
    encode_related_keys(downstream_lists[[i]])
  }, character(1))

  index$related_upstream <- upstream
  index$related_downstream <- downstream
  index
}

#' Resolve related keys to display records (title / repo / href)
#'
#' Shared by Shiny Related column and \code{summary.replicate_study}.
#'
#' @param keys Character vector of DOI/handle keys.
#' @param direction \code{"upstream"} or \code{"downstream"} (for labels).
#' @param index Optional registry index (defaults to [load_index()]).
#' @return List of lists with \code{key}, \code{title}, \code{repo}, \code{doi},
#'   \code{in_registry}, \code{href}, \code{label}.
#' @keywords internal
resolve_related_studies <- function(
  keys,
  direction = c("upstream", "downstream"),
  index = NULL
) {
  direction <- match.arg(direction)
  keys <- parse_related_keys(if (length(keys) == 1L) keys else encode_related_keys(keys))
  if (length(keys) == 0L) {
    return(list())
  }
  if (is.null(index)) {
    index <- tryCatch(load_index(), error = function(e) NULL)
  }
  if (!is.null(index)) {
    index <- ensure_index_handles(index)
  }

  lapply(keys, function(key) {
    row <- NULL
    if (!is.null(index) && nrow(index) > 0L) {
      hit <- match_related_ref_to_index(list(doi = key, handle = key), index)
      if (!is.na(hit)) {
        row <- index[hit, , drop = FALSE]
      }
    }
    if (!is.null(row) && nrow(row) > 0L) {
      title <- trimws(as.character(index_row_field(row, "title", "")))
      repo <- trimws(as.character(index_row_field(row, "repo", "")))
      doi <- trimws(as.character(index_row_field(row, "doi", "")))
      display <- if (nzchar(title)) {
        title
      } else if (nzchar(repo)) {
        repo
      } else {
        key
      }
      href <- if (nzchar(doi)) {
        paste0("https://doi.org/", normalize_doi(doi))
      } else if (nzchar(repo)) {
        paste0("https://github.com/", normalize_repo_slug(repo))
      } else {
        NA_character_
      }
      list(
        key = index_row_related_key(row),
        title = title,
        repo = repo,
        doi = doi,
        in_registry = TRUE,
        href = href,
        label = paste0(
          if (identical(direction, "upstream")) "Upstream: " else "Downstream: ",
          display
        )
      )
    } else {
      doi_guess <- if (grepl("^10\\.", key)) normalize_doi(key) else ""
      href <- if (nzchar(doi_guess)) {
        paste0("https://doi.org/", doi_guess)
      } else {
        NA_character_
      }
      list(
        key = key,
        title = "",
        repo = "",
        doi = doi_guess,
        in_registry = FALSE,
        href = href,
        label = paste0(
          if (identical(direction, "upstream")) "Upstream: " else "Downstream: ",
          if (nzchar(doi_guess)) doi_guess else key
        )
      )
    }
  })
}

#' Related studies for one index row
#' @keywords internal
related_studies_for_index_row <- function(row, index = NULL) {
  if (is.null(index)) {
    index <- tryCatch(load_index(), error = function(e) NULL)
  }
  list(
    upstream = resolve_related_studies(
      index_row_field(row, "related_upstream", ""),
      direction = "upstream",
      index = index
    ),
    downstream = resolve_related_studies(
      index_row_field(row, "related_downstream", ""),
      direction = "downstream",
      index = index
    )
  )
}
