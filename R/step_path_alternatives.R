#' Path languages declared on a step (multi-language engine path)
#'
#' Prefer explicit yaml \code{languages:} on the step (the languages that
#' participate in this implementation path). When omitted, fall back to the
#' dispatch \code{engine:} plus a proprietary \code{requires_engine:} token
#' when present (so a Stata wrapper that shells to Mathematica still labels
#' honestly as Stata + Mathematica).
#'
#' @param step Step / replication entry (list).
#' @return Character vector of normalized language tokens (may be length 1+).
#' @keywords internal
step_path_languages <- function(step) {
  raw <- step$languages %||% NULL
  if (!is.null(raw) && length(raw) > 0L) {
    parts <- tolower(trimws(as.character(unlist(raw, use.names = FALSE))))
    parts <- parts[nzchar(parts)]
    parts <- vapply(parts, function(p) {
      if (p %in% c("py")) return("python")
      if (p %in% c("wolfram", "wolframscript")) return("mathematica")
      p
    }, character(1))
    parts <- unique(parts)
    if (length(parts) > 0L) {
      return(parts)
    }
  }

  eng <- tryCatch(
    replication_engine(step),
    error = function(e) {
      tolower(as.character(step$engine[[1]] %||% step$engine %||% "r"))
    }
  )
  eng <- tolower(as.character(eng[[1]] %||% "r"))
  if (eng %in% c("py")) eng <- "python"
  if (eng %in% c("wolfram", "wolframscript")) eng <- "mathematica"
  if (!nzchar(eng)) eng <- "r"

  req <- tryCatch(
    step_required_engine(step),
    error = function(e) NULL
  )
  req_tok <- ""
  if (!is.null(req) && nzchar(as.character(req))) {
    req_tok <- tolower(trimws(as.character(req[[1]] %||% req)))
    if (req_tok %in% c("wolfram", "wolframscript", "mathematica")) {
      req_tok <- "mathematica"
    }
  } else {
    raw_req <- tolower(as.character(
      step$requires_engine[[1]] %||% step$requires_engine %||% ""
    ))
    if (raw_req %in% c("mathematica", "wolfram", "wolframscript")) {
      req_tok <- "mathematica"
    } else if (nzchar(raw_req) && !raw_req %in% c("r", "stata", "python")) {
      req_tok <- raw_req
    }
  }

  out <- eng
  if (nzchar(req_tok) && !identical(req_tok, eng)) {
    out <- c(out, req_tok)
  }
  unique(out)
}

#' Display name for one language token
#' @keywords internal
language_display_name <- function(token) {
  tok <- tolower(trimws(as.character(token[[1]] %||% "")))
  switch(
    tok,
    r = "R",
    stata = "Stata",
    python = "Python",
    py = "Python",
    mathematica = "Mathematica",
    wolfram = "Mathematica",
    wolframscript = "Mathematica",
    matlab = "MATLAB",
    if (nzchar(tok)) {
      paste0(toupper(substr(tok, 1L, 1L)), substring(tok, 2L))
    } else {
      ""
    }
  )
}

#' Human path label from language tokens (e.g. \code{"Stata / R"})
#'
#' @param languages Character vector of language tokens.
#' @return Character scalar suitable for a Shiny path box.
#' @keywords internal
format_path_languages_label <- function(languages) {
  langs <- unique(tolower(trimws(as.character(languages %||% character(0)))))
  langs <- langs[nzchar(langs)]
  if (length(langs) == 0L) {
    return("")
  }
  paste(vapply(langs, language_display_name, character(1)), collapse = " / ")
}

#' Bracketed path-box label (e.g. \code{"[Stata / R]"})
#' @keywords internal
format_path_languages_box_label <- function(languages) {
  lab <- format_path_languages_label(languages)
  if (!nzchar(lab)) {
    return("")
  }
  paste0("[", lab, "]")
}

#' Whether a group of sibling entries should use language-path boxes
#'
#' Path boxes are used when siblings share a \code{group:} and either:
#' \itemize{
#'   \item any sibling declares multi-language \code{languages:} (length >= 2), or
#'   \item two or more siblings share the same dispatch \code{engine:} (so classic
#'     one-slot-per-engine toggles cannot distinguish them).
#' }
#' Classic bilingual R vs Stata tables (different engines, single-language each)
#' keep the icon-pill UI.
#'
#' @param entries List of sibling step entries (same \code{group:}).
#' @return Logical.
#' @keywords internal
group_uses_path_boxes <- function(entries) {
  if (is.null(entries) || length(entries) < 2L) {
    return(FALSE)
  }
  has_multi_lang <- any(vapply(entries, function(x) {
    raw <- x$languages %||% NULL
    if (is.null(raw) || length(raw) == 0L) {
      return(FALSE)
    }
    length(unique(tolower(trimws(as.character(unlist(raw, use.names = FALSE)))))) >= 2L
  }, logical(1)))
  if (isTRUE(has_multi_lang)) {
    return(TRUE)
  }
  engines <- vapply(entries, function(x) {
    tryCatch(replication_engine(x), error = function(e) {
      tolower(as.character(x$engine[[1]] %||% x$engine %||% "r"))
    })
  }, character(1))
  length(unique(engines)) < length(engines)
}

#' Whether an entry matches a language / path selector
#'
#' Matches when \code{language} appears in the entry's path
#' [step_path_languages()], or when the dispatch engine matches (classic
#' bilingual groups).
#'
#' @keywords internal
entry_matches_path_language <- function(entry, language, paper_meta = NULL) {
  if (is.null(language) || !nzchar(as.character(language[[1]] %||% ""))) {
    return(TRUE)
  }
  lang <- tolower(trimws(as.character(language[[1]])))
  if (lang %in% c("py")) lang <- "python"
  if (lang %in% c("wolfram", "wolframscript")) lang <- "mathematica"

  path_langs <- step_path_languages(entry)
  if (lang %in% path_langs) {
    return(TRUE)
  }
  replication_engine_matches_language(
    replication_engine(entry, paper_meta),
    lang
  )
}

#' Prefer a runnable path, then one whose languages include R
#' @keywords internal
default_path_selector_language <- function(entries, paper_meta = NULL) {
  if (is.null(entries) || !length(entries)) {
    return("r")
  }
  runnable <- entries[!vapply(entries, function(x) {
    isTRUE(x$incomplete %||% FALSE)
  }, logical(1))]
  pool <- if (length(runnable) > 0L) runnable else entries

  for (e in pool) {
    langs <- step_path_languages(e)
    if ("r" %in% langs) {
      return("r")
    }
  }
  for (e in pool) {
    langs <- step_path_languages(e)
    if ("python" %in% langs) {
      return("python")
    }
  }
  for (e in pool) {
    langs <- step_path_languages(e)
    if ("stata" %in% langs && !"mathematica" %in% langs) {
      return(path_selector_language(e, entries))
    }
  }
  path_selector_language(pool[[1]], entries)
}

#' Selector language that uniquely identifies one path among siblings
#'
#' Prefers a language token that appears in this entry's path languages but not
#' in every sibling (so \code{"r"} vs \code{"mathematica"} for Stata+R /
#' Stata+Mathematica pairs). Falls back to the dispatch engine.
#'
#' @keywords internal
path_selector_language <- function(entry, siblings = list()) {
  langs <- step_path_languages(entry)
  if (length(langs) == 0L) {
    return(tryCatch(replication_engine(entry), error = function(e) "r"))
  }
  if (length(siblings) >= 2L) {
    for (tok in langs) {
      appears_elsewhere <- any(vapply(siblings, function(sib) {
        if (identical(as.character(sib$id), as.character(entry$id))) {
          return(FALSE)
        }
        tok %in% step_path_languages(sib)
      }, logical(1)))
      if (!appears_elsewhere) {
        return(tok)
      }
    }
  }
  # Prefer non-stata token when the path is multi-language (secondary kernel).
  if (length(langs) > 1L) {
    secondary <- setdiff(langs, "stata")
    if (length(secondary) > 0L) {
      return(secondary[[1]])
    }
  }
  langs[[1]]
}

#' Sidebar keys for Data steps in yaml / DAG declaration order
#'
#' Returns unique \code{group:} (or \code{id} when ungrouped) keys for
#' transform/prep steps, preserving first-appearance order in \code{reps}.
#' Multi-path siblings that share a \code{group:} collapse to one key so the
#' Shiny sidebar does not list the claim twice. Used to interleave promoted
#' path-group transforms with ordinary prep rows instead of rendering
#' multi-path groups first.
#'
#' @param reps List of replication / step entries (yaml order).
#' @return Character vector of sidebar keys.
#' @keywords internal
replication_sidebar_data_order <- function(reps) {
  if (is.null(reps) || !length(reps)) {
    return(character(0))
  }
  keys <- character(0)
  for (x in reps) {
    if (!is.list(x)) {
      next
    }
    type <- tolower(as.character(x$type %||% ""))
    if (!type %in% c("step", "prep", "pipeline", "transform")) {
      next
    }
    grp <- as.character(x$group[[1]] %||% x$group %||% "")
    id <- as.character(x$id[[1]] %||% x$id %||% "")
    key <- if (nzchar(grp)) grp else id
    if (!nzchar(key)) {
      next
    }
    if (!key %in% keys) {
      keys <- c(keys, key)
    }
  }
  keys
}

#' Pick a path entry from a sibling list by selector language
#' @keywords internal
pick_path_entry <- function(entries, selector = NULL) {
  if (is.null(entries) || !length(entries)) {
    return(NULL)
  }
  group_entry_for_path_selector(
    list(entries = I(list(entries))),
    selector %||% default_path_selector_language(entries)
  )
}

#' Resolve the selected path entry within a grouped row
#'
#' @param row Grouped replication data.frame row (with \code{entries}).
#' @param selector Language / path selector (e.g. \code{"r"}, \code{"mathematica"}).
#' @return Matching entry list, or \code{NULL}.
#' @keywords internal
group_entry_for_path_selector <- function(row, selector) {
  ents <- row$entries
  if (is.null(ents)) {
    return(NULL)
  }
  ents <- ents[[1]]
  if (is.null(ents) || !length(ents)) {
    return(NULL)
  }
  sel <- tolower(trimws(as.character(selector[[1]] %||% "")))
  if (sel %in% c("py")) sel <- "python"
  if (sel %in% c("wolfram", "wolframscript")) sel <- "mathematica"

  pick_from <- function(matches) {
    if (length(matches) == 0L) {
      return(NULL)
    }
    if (length(matches) == 1L) {
      return(matches[[1]])
    }
    exact <- matches[vapply(matches, function(x) {
      identical(path_selector_language(x, ents), sel)
    }, logical(1))]
    if (length(exact) >= 1L) {
      return(exact[[1]])
    }
    runnable <- matches[!vapply(matches, function(x) {
      isTRUE(x$incomplete %||% FALSE)
    }, logical(1))]
    if (length(runnable) >= 1L) {
      return(runnable[[1]])
    }
    matches[[1]]
  }

  if (nzchar(sel)) {
    matches <- ents[vapply(ents, function(x) {
      entry_matches_path_language(x, sel)
    }, logical(1))]
    hit <- pick_from(matches)
    if (!is.null(hit)) {
      return(hit)
    }
    # Classic bilingual fallback: match dispatch engine only.
    eng_matches <- ents[vapply(ents, function(x) {
      identical(replication_engine(x), sel)
    }, logical(1))]
    hit <- pick_from(eng_matches)
    if (!is.null(hit)) {
      return(hit)
    }
  }

  default_sel <- default_path_selector_language(ents)
  matches <- ents[vapply(ents, function(x) {
    entry_matches_path_language(x, default_sel)
  }, logical(1))]
  hit <- pick_from(matches)
  if (!is.null(hit)) {
    return(hit)
  }
  ents[[1]]
}
