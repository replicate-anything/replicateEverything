#' Default Stata path globals for a study root
#'
#' Matches \code{code/helpers/init_study_paths.do} in folder-backed studies.
#' \code{maindir} is the study root (directory containing \code{replication.yml}).
#'
#' @param study_root Normalized absolute study root path.
#' @param result_dir Optional override for \code{result} (e.g. staging dir).
#' @return Named character vector of global values.
#' @keywords internal
default_stata_globals <- function(study_root, result_dir = NULL) {
  study_root <- normalize_path_slashes(study_root)
  result <- result_dir %||% file.path(study_root, "outputs", "staging")
  c(
    maindir = study_root,
    rawdir = file.path(study_root, "data", "raw"),
    processed = file.path(study_root, "outputs"),
    result = normalize_path_slashes(result)
  )
}

#' Whether a study root path is usable for on-disk code linking
#' @keywords internal
is_study_root_usable <- function(study_root) {
  if (is.null(study_root) || length(study_root) != 1L) {
    return(FALSE)
  }
  if (is.na(study_root) || !nzchar(study_root)) {
    return(FALSE)
  }
  dir.exists(study_root)
}

#' Merge default Stata globals with any parsed or cached values
#'
#' Shiny reactive state can strip names from character vectors; treat unnamed or
#' empty globals as missing and fall back to \code{default_stata_globals()}.
#' @keywords internal
normalize_stata_globals <- function(study_root, globals = NULL) {
  defaults <- if (is_study_root_usable(study_root)) {
    default_stata_globals(study_root)
  } else {
    character()
  }
  if (is.null(globals) || !length(globals)) {
    return(defaults)
  }
  if (is.list(globals)) {
    globals <- unlist(globals, use.names = TRUE)
  }
  if (!is.character(globals) || is.null(names(globals)) || !any(nzchar(names(globals)))) {
    return(defaults)
  }
  out <- defaults
  for (nm in names(globals)) {
    val <- globals[[nm]]
    if (nzchar(nm) && !is.null(val) && nzchar(val) && is_resolved_stata_global_value(val)) {
      out[[nm]] <- normalize_path_slashes(as.character(val))
    }
  }
  clamp_stata_path_globals_to_study(out, study_root)
}

#' Keep Stata path globals rooted in the study directory
#'
#' Code linking resolves \code{do} paths against \code{study_root}. If
#' \code{maindir} (or paths derived from it) point outside that root — e.g. a
#' materialized cache directory — links are marked \code{outside_root} and
#' rendered with strikethrough in Shiny.
#' @keywords internal
clamp_stata_path_globals_to_study <- function(globals, study_root) {
  if (!length(globals) || !is_study_root_usable(study_root)) {
    return(globals)
  }
  study_norm <- normalize_path_slashes(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  maindir <- globals[["maindir"]]
  if (is.null(maindir) || !nzchar(maindir)) {
    return(globals)
  }
  maindir_norm <- normalize_path_slashes(normalizePath(maindir, winslash = "/", mustWork = FALSE))
  if (path_within_root(maindir_norm, study_norm)) {
    return(globals)
  }
  result_dir <- globals[["result"]]
  clamped <- default_stata_globals(study_root, result_dir = result_dir)
  for (nm in c("maindir", "rawdir", "processed")) {
    globals[[nm]] <- clamped[[nm]]
  }
  globals
}

#' Normalize path separators to forward slashes
#' @keywords internal
normalize_path_slashes <- function(path) {
  gsub("\\\\", "/", path)
}

#' Whether a parsed Stata global value is a usable literal path
#'
#' Skips locals/macros such as \code{"`root'"} or \code{"\${maindir}/data/raw"}
#' that \code{init_study_paths.do} assigns at runtime.
#' @keywords internal
is_resolved_stata_global_value <- function(val) {
  if (is.null(val) || length(val) != 1L) {
    return(FALSE)
  }
  val <- as.character(val)
  if (!nzchar(val)) {
    return(FALSE)
  }
  if (grepl("`", val, fixed = TRUE)) {
    return(FALSE)
  }
  if (grepl("\\$\\{", val, perl = TRUE)) {
    return(FALSE)
  }
  if (grepl("\\$[A-Za-z_]", val, perl = TRUE)) {
    return(FALSE)
  }
  TRUE
}

#' Parse \code{global} assignments from Stata lines
#' @keywords internal
parse_stata_globals <- function(lines, existing = character()) {
  globals <- existing
  if (!length(lines)) {
    return(globals)
  }
  for (line in lines) {
    m <- regexec(
      '^\\s*global\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+"([^"]*)"',
      line,
      perl = TRUE
    )
    hit <- regmatches(line, m)[[1]]
    if (length(hit) >= 3L && is_resolved_stata_global_value(hit[[3]])) {
      globals[[hit[[2]]]] <- hit[[3]]
    }
  }
  globals
}

#' Strip Stata comments for parsing (returns parseable code only)
#' @keywords internal
strip_stata_comments <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  out <- character(length(lines))
  in_block <- FALSE
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (in_block) {
      end_pos <- regexpr("\\*/", line, fixed = TRUE)[[1]]
      if (end_pos > 0L) {
        line <- substr(line, end_pos + 2L, nchar(line))
        in_block <- FALSE
      } else {
        out[[i]] <- ""
        next
      }
    }
    while (TRUE) {
      start_pos <- regexpr("/\\*", line, fixed = TRUE)[[1]]
      if (start_pos <= 0L) {
        break
      }
      end_pos <- regexpr("\\*/", line, fixed = TRUE)[[1]]
      if (end_pos <= 0L) {
        line <- substr(line, 1L, start_pos - 1L)
        in_block <- TRUE
        break
      }
      line <- paste0(
        substr(line, 1L, start_pos - 1L),
        substr(line, end_pos + 2L, nchar(line))
      )
    }
    if (grepl("^\\s*\\*", line)) {
      out[[i]] <- ""
      next
    }
    slash <- regexpr("//", line, fixed = TRUE)[[1]]
    if (slash > 0L) {
      line <- substr(line, 1L, slash - 1L)
    }
    out[[i]] <- line
  }
  out
}

#' Strip R comments for parsing
#' @keywords internal
strip_r_comments <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  out <- character(length(lines))
  in_block <- FALSE
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (in_block) {
      end_pos <- regexpr("\\*/", line, fixed = TRUE)[[1]]
      if (end_pos > 0L) {
        line <- substr(line, end_pos + 2L, nchar(line))
        in_block <- FALSE
      } else {
        out[[i]] <- ""
        next
      }
    }
    while (TRUE) {
      start_pos <- regexpr("/\\*", line, fixed = TRUE)[[1]]
      if (start_pos <= 0L) {
        break
      }
      end_pos <- regexpr("\\*/", line, fixed = TRUE)[[1]]
      if (end_pos <= 0L) {
        line <- substr(line, 1L, start_pos - 1L)
        in_block <- TRUE
        break
      }
      line <- paste0(
        substr(line, 1L, start_pos - 1L),
        substr(line, end_pos + 2L, nchar(line))
      )
    }
    hash <- regexpr("#", line, fixed = TRUE)[[1]]
    if (hash > 0L) {
      line <- substr(line, 1L, hash - 1L)
    }
    out[[i]] <- line
  }
  out
}

stata_call_pattern <- paste0(
  "^\\s*",
  "(?:(?:quietly|capture|cap\\s+noi)\\s+)*",
  "(?:do|run|include)\\s+",
  "(?:(\"([^\"]+)\")|(\\S+))"
)

r_source_pattern <- "^\\s*(sys\\.)?source\\s*\\(\\s*[\"']([^\"']+)[\"']\\s*\\)"

#' Extract Stata file calls from code lines
#'
#' @param lines Character vector of code lines (may include comments).
#' @return Data frame with columns \code{line}, \code{command}, \code{path},
#'   \code{match_start}, \code{match_end}.
#' @keywords internal
extract_stata_file_calls <- function(lines) {
  if (!length(lines)) {
    return(empty_code_calls())
  }
  parse_lines <- strip_stata_comments(lines)
  rows <- list()
  for (i in seq_along(parse_lines)) {
    line <- parse_lines[[i]]
    if (!nzchar(trimws(line))) {
      next
    }
    m <- regexec(stata_call_pattern, line, perl = TRUE)[[1]]
    if (m[[1L]] <= 0L) {
      next
    }
    parts <- regmatches(line, list(m))[[1]]
    path <- if (length(parts) >= 4L && nzchar(parts[[4L]])) {
      parts[[4L]]
    } else if (length(parts) >= 3L && nzchar(parts[[3L]])) {
      parts[[3L]]
    } else {
      ""
    }
    if (!nzchar(path)) {
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      line = i,
      command = "do",
      path = path,
      match_start = m[[1L]],
      match_end = m[[1L]] + attr(m, "match.length")[[1L]] - 1L,
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) {
    return(empty_code_calls())
  }
  do.call(rbind, rows)
}

#' Extract R \code{source()} calls from code lines
#' @keywords internal
extract_r_source_calls <- function(lines) {
  if (!length(lines)) {
    return(empty_code_calls())
  }
  parse_lines <- strip_r_comments(lines)
  rows <- list()
  for (i in seq_along(parse_lines)) {
    line <- parse_lines[[i]]
    if (!nzchar(trimws(line))) {
      next
    }
    m <- regexec(r_source_pattern, line, perl = TRUE)[[1]]
    if (m[[1L]] <= 0L) {
      next
    }
    parts <- regmatches(line, list(m))[[1]]
    path <- if (length(parts) >= 3L) parts[[3L]] else ""
    command <- if (length(parts) >= 2L && identical(parts[[2L]], "sys.")) {
      "sys.source"
    } else {
      "source"
    }
    if (!nzchar(path)) {
      next
    }
    rows[[length(rows) + 1L]] <- data.frame(
      line = i,
      command = command,
      path = path,
      match_start = m[[1L]],
      match_end = m[[1L]] + attr(m, "match.length")[[1L]] - 1L,
      stringsAsFactors = FALSE
    )
  }
  if (!length(rows)) {
    return(empty_code_calls())
  }
  do.call(rbind, rows)
}

empty_code_calls <- function() {
  data.frame(
    line = integer(0),
    command = character(0),
    path = character(0),
    match_start = integer(0),
    match_end = integer(0),
    stringsAsFactors = FALSE
  )
}

#' Substitute Stata globals in a path string
#' @keywords internal
substitute_stata_globals <- function(path, globals) {
  path <- normalize_path_slashes(path)
  unresolved <- character(0)
  out <- path
  repeat {
    m <- regexpr("\\$\\{([A-Za-z_][A-Za-z0-9_]*)\\}", out, perl = TRUE)
    if (m[[1]] <= 0L) {
      break
    }
    name <- regmatches(out, m)
    name <- sub("^\\$\\{([^}]+)\\}$", "\\1", name, perl = TRUE)
    val <- globals[[name]]
    if (is.null(val) || !nzchar(val)) {
      unresolved <- c(unresolved, name)
      break
    }
    out <- sub("\\$\\{[^}]+\\}", val, out, perl = TRUE)
  }
  repeat {
    m <- regexpr("\\$([A-Za-z_][A-Za-z0-9_]*)", out, perl = TRUE)
    if (m[[1]] <= 0L) {
      break
    }
    name <- sub("^\\$", "", regmatches(out, m))
    val <- globals[[name]]
    if (is.null(val) || !nzchar(val)) {
      unresolved <- c(unresolved, name)
      break
    }
    out <- sub("\\$[A-Za-z_][A-Za-z0-9_]*", val, out, perl = TRUE)
  }
  list(path = out, unresolved = unique(unresolved))
}

#' Resolve a referenced code path within a study root
#'
#' @param path Raw path from a \code{do}/\code{source} call.
#' @param study_root Absolute study root directory.
#' @param globals Named character vector of Stata globals.
#' @param from_file Optional path of the file containing the call (for relative paths).
#' @param allowed_root Optional permitted root (defaults to \code{study_root}).
#' @return List with \code{status} (\code{ok}, \code{missing}, \code{unresolved},
#'   \code{outside_root}, \code{unreadable}), \code{resolved}, \code{display},
#'   \code{unresolved}.
#' @keywords internal
resolve_code_path <- function(
  path,
  study_root,
  globals = character(),
  from_file = NULL,
  allowed_root = study_root
) {
  if (!is_study_root_usable(study_root)) {
    return(list(
      status = "missing",
      resolved = NA_character_,
      display = path,
      unresolved = character(0)
    ))
  }
  globals <- normalize_stata_globals(study_root, globals)
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  allowed_root <- normalizePath(allowed_root, winslash = "/", mustWork = FALSE)
  allowed_norm <- normalize_path_slashes(allowed_root)
  raw <- path
  subbed <- if (length(globals)) {
    substitute_stata_globals(path, globals)
  } else {
    list(path = normalize_path_slashes(path), unresolved = character(0))
  }
  if (length(subbed$unresolved)) {
    return(list(
      status = "unresolved",
      resolved = NA_character_,
      display = raw,
      unresolved = subbed$unresolved
    ))
  }
  candidate <- normalize_path_slashes(subbed$path)
  if (!grepl("^[A-Za-z]:/", candidate) && grepl("^[A-Za-z]:", candidate)) {
    candidate <- sub("^([A-Za-z]:)", "\\1/", candidate)
  }
  if (!grepl("^/", candidate) && !grepl("^[A-Za-z]:/", candidate)) {
    # Study-root paths (e.g. code/helpers/init.do) resolve from maindir/study_root.
    # Caller-relative paths (../ or ./) resolve from the containing file's directory.
    base <- study_root
    maindir <- globals[["maindir"]]
    if (!is.null(maindir) && nzchar(maindir)) {
      maindir_norm <- normalize_path_slashes(normalizePath(maindir, winslash = "/", mustWork = FALSE))
      if (path_within_root(maindir_norm, allowed_norm)) {
        base <- maindir_norm
      }
    }
    if (
      !is.null(from_file) &&
        nzchar(from_file) &&
        (grepl("^\\.\\.", candidate) || grepl("^\\./", candidate))
    ) {
      caller_dir <- normalize_path_slashes(
        normalizePath(dirname(from_file), winslash = "/", mustWork = FALSE)
      )
      if (path_within_root(caller_dir, allowed_norm)) {
        base <- caller_dir
      }
    }
    candidate <- normalize_path_slashes(file.path(base, candidate))
  }
  candidate <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
  candidate <- normalize_path_slashes(candidate)
  if (!path_within_root(candidate, allowed_norm)) {
    return(list(
      status = "outside_root",
      resolved = candidate,
      display = raw,
      unresolved = character(0)
    ))
  }
  if (!file.exists(candidate)) {
    return(list(
      status = "missing",
      resolved = candidate,
      display = raw,
      unresolved = character(0)
    ))
  }
  if (!file.access(candidate, 4) == 0) {
    return(list(
      status = "unreadable",
      resolved = candidate,
      display = raw,
      unresolved = character(0)
    ))
  }
  rel <- tryCatch(
    normalize_path_slashes(
      sub(
        paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", allowed_norm)),
        "",
        candidate
      )
    ),
    error = function(e) basename(candidate)
  )
  if (grepl("^/", rel)) {
    rel <- sub("^/", "", rel)
  }
  list(
    status = "ok",
    resolved = candidate,
    display = if (nzchar(rel)) rel else basename(candidate),
    unresolved = character(0)
  )
}

#' @keywords internal
path_within_root <- function(path, root) {
  path <- normalize_path_slashes(normalizePath(path, winslash = "/", mustWork = FALSE))
  root <- normalize_path_slashes(normalizePath(root, winslash = "/", mustWork = FALSE))
  path == root || grepl(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root), "/"), path)
}

#' Resolve a Stata path (alias for \code{resolve_code_path})
#' @keywords internal
resolve_stata_path <- function(path, study_root, globals = character(), from_file = NULL) {
  resolve_code_path(path, study_root, globals = globals, from_file = from_file)
}

#' Relative path of an absolute file within a study root
#' @keywords internal
study_relative_path <- function(abs_path, study_root) {
  if (is.null(abs_path) || is.na(abs_path) || !nzchar(abs_path)) {
    return(NA_character_)
  }
  study_norm <- normalize_path_slashes(
    normalizePath(study_root, winslash = "/", mustWork = FALSE)
  )
  candidate <- normalize_path_slashes(
    normalizePath(abs_path, winslash = "/", mustWork = FALSE)
  )
  rel <- tryCatch(
    normalize_path_slashes(
      sub(
        paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", study_norm)),
        "",
        candidate
      )
    ),
    error = function(e) basename(candidate)
  )
  if (grepl("^/", rel)) {
    rel <- sub("^/", "", rel)
  }
  if (nzchar(rel)) rel else basename(candidate)
}

#' Code script paths declared in study replication metadata
#'
#' Collects runner \code{code:} paths and optional \code{format:} scripts from
#' every step in \code{replication.yml} (unified \code{steps:} or legacy blocks).
#'
#' @param meta Parsed replication metadata.
#' @return Character vector of study-relative code paths.
#' @keywords internal
study_replication_code_files <- function(meta) {
  steps <- normalize_study_steps(meta)
  code_paths <- character(0)
  for (step in steps) {
    code_val <- step$code %||% NULL
    if (!is.null(code_val) && nzchar(as.character(code_val[[1]]))) {
      code_paths <- c(code_paths, as.character(code_val[[1]]))
    }
    if (format_specified(step) && is.character(step$format)) {
      fmt <- as.character(step$format[[1]] %||% step$format)
      if (nzchar(fmt)) {
        code_paths <- c(code_paths, fmt)
      }
    }
  }
  unique(code_paths[nzchar(code_paths)])
}

#' Infer language for a study-relative code path
#' @keywords internal
code_path_language <- function(rel_path) {
  ext <- tolower(tools::file_ext(rel_path))
  if (ext %in% c("do", "ado", "mata")) {
    "stata"
  } else if (ext %in% c("r")) {
    "r"
  } else {
    NA_character_
  }
}

#' Format a human-readable code-link validation error
#' @keywords internal
format_code_link_issue_message <- function(
  caller_rel,
  line,
  command,
  raw_path,
  resolved,
  study_root
) {
  suffix <- if (identical(resolved$status, "unresolved")) {
    paste0(
      " → unresolved Stata macro: ",
      paste(resolved$unresolved, collapse = ", ")
    )
  } else if (!is.na(resolved$resolved %||% NA_character_) && nzchar(resolved$resolved)) {
    paste0(
      " → expected ",
      study_relative_path(resolved$resolved, study_root)
    )
  } else if (identical(resolved$status, "outside_root")) {
    " → path outside study root"
  } else {
    ""
  }
  sprintf(
    "In %s line %d: cannot resolve %s('%s')%s",
    caller_rel,
    line,
    command,
    raw_path,
    suffix
  )
}

#' Collect broken code file references in a folder-backed study
#'
#' Walks every replication script declared in \code{replication.yml}, parses
#' \code{source()}, \code{sys.source()}, and Stata \code{do}/\code{run}/\code{include}
#' calls, and follows resolvable links recursively. Uses the same path resolution
#' rules as the Shiny code viewer (\code{\link{resolve_code_path}}).
#'
#' @param study_root Absolute study root directory.
#' @param meta Parsed replication metadata.
#' @return Data frame with columns \code{caller}, \code{line}, \code{command},
#'   \code{path}, \code{status}, \code{message}.
#' @keywords internal
collect_code_link_issues <- function(study_root, meta) {
  if (!is_study_root_usable(study_root)) {
    return(empty_code_link_issues())
  }
  entry_paths <- study_replication_code_files(meta)
  if (!length(entry_paths)) {
    return(empty_code_link_issues())
  }

  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  globals <- default_stata_globals(study_root)
  issues <- list()
  queue <- entry_paths
  seen <- character(0)

  while (length(queue) > 0L) {
    rel <- normalize_path_slashes(queue[[1L]])
    queue <- queue[-1L]
    if (rel %in% seen) {
      next
    }
    seen <- c(seen, rel)

    language <- code_path_language(rel)
    if (is.na(language)) {
      next
    }

    abs_path <- file.path(study_root, rel)
    if (!file.exists(abs_path)) {
      next
    }

    lines <- tryCatch(
      readLines(abs_path, warn = FALSE, encoding = "UTF-8"),
      error = function(e) character(0)
    )
    if (!length(lines)) {
      next
    }

    if (identical(language, "stata")) {
      globals <- parse_stata_globals(lines, globals)
      calls <- extract_stata_file_calls(lines)
    } else {
      calls <- extract_r_source_calls(lines)
    }
    if (!nrow(calls)) {
      next
    }

    for (k in seq_len(nrow(calls))) {
      resolved <- resolve_code_path(
        calls$path[[k]],
        study_root = study_root,
        globals = globals,
        from_file = abs_path
      )
      if (identical(resolved$status, "ok")) {
        child <- normalize_path_slashes(resolved$display)
        if (nzchar(child) && !child %in% seen) {
          queue <- c(queue, child)
        }
        next
      }
      issues[[length(issues) + 1L]] <- data.frame(
        caller = rel,
        line = calls$line[[k]],
        command = calls$command[[k]],
        path = calls$path[[k]],
        status = resolved$status,
        message = format_code_link_issue_message(
          rel,
          calls$line[[k]],
          calls$command[[k]],
          calls$path[[k]],
          resolved,
          study_root
        ),
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(issues)) {
    return(empty_code_link_issues())
  }
  do.call(rbind, issues)
}

empty_code_link_issues <- function() {
  data.frame(
    caller = character(0),
    line = integer(0),
    command = character(0),
    path = character(0),
    status = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )
}

#' Validate resolvable code file links in a folder-backed study
#'
#' Returns checklist rows suitable for \code{\link{bind_check_results}}.
#' Called from \code{\link{check_folder_replication}} before registry submission.
#'
#' @param study_root Absolute study root directory.
#' @param meta Parsed replication metadata.
#' @return Data frame of checklist results (\code{check}, \code{passed}, \code{message}).
#' @keywords internal
check_code_links <- function(study_root, meta) {
  issues <- collect_code_link_issues(study_root, meta)
  entry_count <- length(study_replication_code_files(meta))
  if (nrow(issues) == 0L) {
    return(check_result(
      "code_links",
      TRUE,
      if (entry_count > 0L) {
        paste0("All code file links resolve (", entry_count, " scripts checked)")
      } else {
        "No replication code scripts declared"
      }
    ))
  }
  rows <- lapply(seq_len(nrow(issues)), function(i) {
    issue <- issues[i, , drop = FALSE]
    check_result(
      paste0("code_link_", gsub("[^a-zA-Z0-9._-]", "_", issue$caller)),
      FALSE,
      issue$message
    )
  })
  do.call(bind_check_results, c(list(check_result("code_links", FALSE, paste(nrow(issues), "broken link(s)"))), rows))
}

#' Escape HTML special characters
#' @keywords internal
escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

#' Diagnostic context for a code link resolution attempt
#' @keywords internal
code_link_diagnostics <- function(
  resolved,
  study_root,
  globals = character(),
  allowed_root = study_root
) {
  study_root_norm <- if (is_study_root_usable(study_root)) {
    normalize_path_slashes(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  } else {
    NA_character_
  }
  allowed_root_norm <- if (!is.null(allowed_root) && nzchar(allowed_root)) {
    normalize_path_slashes(normalizePath(allowed_root, winslash = "/", mustWork = FALSE))
  } else {
    study_root_norm
  }
  maindir <- globals[["maindir"]] %||% NA_character_
  if (!is.na(maindir) && nzchar(maindir)) {
    maindir <- normalize_path_slashes(normalizePath(maindir, winslash = "/", mustWork = FALSE))
  }
  list(
    status = resolved$status %||% "unknown",
    resolved_path = resolved$resolved %||% NA_character_,
    study_root = study_root_norm,
    allowed_root = allowed_root_norm,
    maindir = maindir,
    unresolved = resolved$unresolved %||% character(0)
  )
}

#' Human-readable tooltip for a failed code link
#' @keywords internal
format_code_link_diagnostic_title <- function(diag) {
  status_label <- switch(
    diag$status,
    missing = "File not found",
    unresolved = "Unresolved Stata macro",
    outside_root = "Path outside allowed root",
    unreadable = "File not readable",
    paste0("Status: ", diag$status)
  )
  lines <- c(
    status_label,
    if (!is.na(diag$resolved_path) && nzchar(diag$resolved_path)) {
      paste0("Resolved path: ", diag$resolved_path)
    },
    if (!is.na(diag$study_root) && nzchar(diag$study_root)) {
      paste0("study_root: ", diag$study_root)
    },
    if (!is.na(diag$allowed_root) && nzchar(diag$allowed_root)) {
      paste0("allowed_root: ", diag$allowed_root)
    },
    if (!is.na(diag$maindir) && nzchar(diag$maindir)) {
      paste0("maindir: ", diag$maindir)
    },
    if (length(diag$unresolved)) {
      paste0("Unresolved macros: ", paste(diag$unresolved, collapse = ", "))
    }
  )
  lines <- lines[nzchar(lines)]
  paste(lines, collapse = "\n")
}

#' Render code lines with clickable file links for Shiny
#'
#' @param lines Character vector of code lines.
#' @param language \code{"stata"} or \code{"r"}.
#' @param study_root Study root directory.
#' @param source_path Relative path of the file within the study (for relative resolution).
#' @param globals Named Stata globals.
#' @return List with \code{html}, \code{links} (JSON-ready list), \code{lines}.
#' @keywords internal
render_code_html_with_links <- function(
  lines,
  language = c("stata", "r"),
  study_root,
  source_path = NULL,
  globals = NULL
) {
  language <- match.arg(language)
  if (!is_study_root_usable(study_root)) {
    return(list(
      html = escape_html(paste(lines, collapse = "\n")),
      links = list(),
      lines = lines
    ))
  }
  globals <- normalize_stata_globals(study_root, globals)
  allowed_root <- study_root
  calls <- if (identical(language, "stata")) {
    extract_stata_file_calls(lines)
  } else {
    extract_r_source_calls(lines)
  }
  from_file <- if (!is.null(source_path) && nzchar(source_path)) {
    file.path(study_root, source_path)
  } else {
    NULL
  }

  link_meta <- list()
  line_html <- vapply(seq_along(lines), function(i) {
    line <- lines[[i]]
    line_calls <- calls[calls$line == i, , drop = FALSE]
    if (!nrow(line_calls)) {
      return(escape_html(line))
    }
    pieces <- character(0)
    cursor <- 1L
    for (j in seq_len(nrow(line_calls))) {
      call <- line_calls[j, , drop = FALSE]
      start <- call$match_start
      end <- call$match_end
      if (start > cursor) {
        pieces <- c(pieces, escape_html(substr(line, cursor, start - 1L)))
      }
      chunk <- substr(line, start, end)
      resolved <- resolve_code_path(
        call$path,
        study_root = study_root,
        globals = globals,
        from_file = from_file
      )
      link_id <- paste0("L", i, "_", j)
      diag <- code_link_diagnostics(
        resolved,
        study_root = study_root,
        globals = globals,
        allowed_root = allowed_root
      )
      link_meta[[link_id]] <<- c(
        list(
          id = link_id,
          line = i,
          path = call$path,
          resolved = resolved$resolved %||% NA_character_,
          display = resolved$display,
          status = resolved$status,
          unresolved = resolved$unresolved,
          diagnostics = diag
        )
      )
      cls <- paste0("code-file-link code-file-link--", resolved$status)
      title <- if (identical(resolved$status, "ok")) {
        resolved$display
      } else {
        format_code_link_diagnostic_title(diag)
      }
      path_html <- escape_html(chunk)
      data_rel <- if (identical(resolved$status, "ok")) {
        sprintf(" data-rel-path=\"%s\"", escape_html(resolved$display))
      } else {
        ""
      }
      link_anchor <- sprintf(
        "<a href=\"#\" class=\"%s\" data-link-id=\"%s\"%s title=\"%s\">%s</a>",
        cls,
        link_id,
        data_rel,
        escape_html(title),
        path_html
      )
      if (!identical(resolved$status, "ok")) {
        link_anchor <- paste0(
          link_anchor,
          sprintf(
            "<span class=\"code-link-diagnostic\" title=\"%s\" aria-label=\"%s\"> [!]</span>",
            escape_html(title),
            escape_html(format_code_link_diagnostic_title(diag))
          )
        )
      }
      pieces <- c(pieces, link_anchor)
      cursor <- end + 1L
    }
    if (cursor <= nchar(line)) {
      pieces <- c(pieces, escape_html(substr(line, cursor, nchar(line))))
    }
    paste0(pieces, collapse = "")
  }, character(1L))

  rows <- paste0(
    "<div class=\"code-line\">",
    "<span class=\"code-ln\">",
    seq_along(lines),
    "</span>",
    "<span class=\"code-lc\">",
    line_html,
    "</span>",
    "</div>",
    collapse = ""
  )

  list(
    html = rows,
    links = link_meta,
    lines = lines
  )
}

#' Build a code dependency graph from an entry script
#'
#' Parses \code{do}/\code{source} calls recursively. Cached paths are not re-read.
#'
#' @param entry_path Relative path within study root.
#' @param study_root Absolute study root.
#' @param language \code{"stata"} or \code{"r"}.
#' @param read_fn Function(path) -> lines; defaults to \code{readLines}.
#' @param cache Optional environment for memoization.
#' @return List with \code{nodes} (path -> lines), \code{edges} (from -> to paths),
#'   \code{globals}.
#' @keywords internal
build_code_file_graph <- function(
  entry_path,
  study_root,
  language = c("stata", "r"),
  read_fn = NULL,
  cache = NULL
) {
  language <- match.arg(language)
  if (is.null(read_fn)) {
    read_fn <- function(rel) {
      readLines(file.path(study_root, rel), warn = FALSE, encoding = "UTF-8")
    }
  }
  if (is.null(cache)) {
    cache <- new.env(parent = emptyenv())
  }
  globals <- default_stata_globals(study_root)
  nodes <- list()
  edges <- list()
  queue <- normalize_path_slashes(entry_path)
  seen <- character(0)

  while (length(queue) > 0L) {
    rel <- queue[[1L]]
    queue <- queue[-1L]
    if (rel %in% seen) {
      next
    }
    seen <- c(seen, rel)
    cache_key <- rel
    lines <- if (exists(cache_key, envir = cache, inherits = FALSE)) {
      get(cache_key, envir = cache)
    } else {
      path <- file.path(study_root, rel)
      if (!file.exists(path)) {
        NULL
      } else {
        ln <- read_fn(rel)
        assign(cache_key, ln, envir = cache)
        ln
      }
    }
    nodes[[rel]] <- lines
    if (is.null(lines)) {
      next
    }
    if (identical(language, "stata")) {
      globals <- parse_stata_globals(lines, globals)
      calls <- extract_stata_file_calls(lines)
    } else {
      calls <- extract_r_source_calls(lines)
    }
    if (!nrow(calls)) {
      next
    }
    child_paths <- character(0)
    for (k in seq_len(nrow(calls))) {
      resolved <- resolve_code_path(
        calls$path[[k]],
        study_root = study_root,
        globals = globals,
        from_file = file.path(study_root, rel)
      )
      if (identical(resolved$status, "ok")) {
        child_paths <- c(child_paths, resolved$display)
      }
    }
    child_paths <- unique(child_paths[nzchar(child_paths)])
    edges[[rel]] <- child_paths
    for (child in child_paths) {
      if (!child %in% seen) {
        queue <- c(queue, child)
      }
    }
  }

  list(nodes = nodes, edges = edges, globals = globals)
}

#' Read raw replication runner code (no inlining)
#'
#' @inheritParams get_code
#' @return Character vector of lines from the runner script.
#' @keywords internal
read_replication_source_code <- function(doi, what, language = NULL, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  rep <- find_replication_entry(meta, what, language = language)
  read_fn <- study_code_reader(ctx, meta)
  read_fn(rep$code)
}

#' @keywords internal
study_code_reader <- function(ctx, meta) {
  function(path) {
    if (!is.null(ctx$local_root)) {
      local_code <- file.path(ctx$local_root, path)
      if (file.exists(local_code)) {
        return(readLines(local_code, warn = FALSE, encoding = "UTF-8"))
      }
    }
    if (
      isTRUE(ctx$is_folder_study) &&
        !is.null(ctx$base_url) &&
        grepl("raw\\.githubusercontent\\.com", ctx$base_url, fixed = TRUE)
    ) {
      remote_lines <- tryCatch(
        read_lines_url(paste0(ctx$base_url, path)),
        error = function(e) NULL
      )
      if (length(remote_lines)) {
        return(remote_lines)
      }
    }
    if (is.null(ctx$local_root) && !is.null(meta)) {
      study_root <- ensure_study_folder_local(meta, ctx)
      if (!is.null(study_root)) {
        local_code <- file.path(study_root, path)
        if (file.exists(local_code)) {
          return(readLines(local_code, warn = FALSE, encoding = "UTF-8"))
        }
      }
    }
    read_lines_url(paste0(ctx$base_url, "/", path))
  }
}

#' Resolve study root for code inspection
#' @keywords internal
resolve_study_code_root <- function(doi, repo = NULL, folder = NULL) {
  ctx <- paper_context(doi, repo = repo, folder = folder)
  root <- ctx$local_root
  if (!is.null(root) && dir.exists(root)) {
    return(normalizePath(root, winslash = "/", mustWork = FALSE))
  }
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ensure_study_folder_local(meta, ctx)
}

#' Prepare code viewer state for Shiny
#'
#' @return List suitable for serializing to the client.
#' @keywords internal
prepare_code_viewer_state <- function(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  rep <- find_replication_entry(meta, what, language = language)
  study_root <- resolve_study_code_root(doi, repo = repo, folder = folder)
  code_lang <- replication_code_language_for(doi, what, language = language, repo = repo, folder = folder)
  entry <- as.character(rep$code)
  read_fn <- study_code_reader(ctx, meta)
  graph <- if (!is.null(study_root) && dir.exists(study_root)) {
    tryCatch(
      build_code_file_graph(
        entry,
        study_root,
        language = if (identical(code_lang, "stata")) "stata" else "r",
        read_fn = function(rel) read_fn(rel)
      ),
      error = function(e) list(nodes = list(), edges = list(), globals = default_stata_globals(study_root))
    )
  } else {
    list(nodes = list(), edges = list(), globals = character(0))
  }
  lines <- tryCatch(read_fn(entry), error = function(e) character(0))
  rendered <- if (length(lines) && is_study_root_usable(study_root)) {
    render_code_html_with_links(
      lines,
      language = if (identical(code_lang, "stata")) "stata" else "r",
      study_root = study_root,
      source_path = entry,
      globals = normalize_stata_globals(study_root, graph$globals)
    )
  } else {
    list(html = escape_html(paste(lines, collapse = "\n")), links = list(), lines = lines)
  }
  list(
    doi = doi,
    what = what,
    language = code_lang,
    study_root = study_root %||% NA_character_,
    entry_path = entry,
    current_path = entry,
    graph = graph,
    rendered = rendered,
    breadcrumb = entry
  )
}

#' Render a linked code file for the Shiny code viewer
#' @keywords internal
render_linked_code_file <- function(
  rel_path,
  study_root,
  language = c("stata", "r"),
  read_fn = NULL,
  globals = NULL
) {
  language <- match.arg(language)
  if (is.null(read_fn)) {
    read_fn <- function(rel) readLines(file.path(study_root, rel), warn = FALSE, encoding = "UTF-8")
  }
  lines <- read_fn(rel_path)
  globals <- if (identical(language, "stata")) {
    globals <- normalize_stata_globals(study_root, globals)
    parse_stata_globals(lines, globals)
  } else {
    globals
  }
  render_code_html_with_links(
    lines,
    language = language,
    study_root = study_root,
    source_path = rel_path,
    globals = globals
  )
}
