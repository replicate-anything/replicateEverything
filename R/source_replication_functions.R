#' Whether a top-level assignment RHS is a safe script constant
#'
#' Constants (e.g. \code{TAB_3_TREATMENT_TERMS <- c(...)}) must be evaluated
#' into \code{env} so helper functions defined in the same file can resolve them.
#' Data-loading or side-effect calls are skipped.
#' @keywords internal
is_safe_script_constant_rhs <- function(rhs) {
  if (is.symbol(rhs) || !is.call(rhs)) {
    return(TRUE)
  }
  fn <- rhs[[1]]
  fn_name <- if (is.name(fn)) {
    as.character(fn)
  } else if (is.character(fn)) {
    fn[[1]]
  } else {
    ""
  }
  if (fn_name %in% c("function", "source", "sys.source", "<-", "=")) {
    return(FALSE)
  }
  if (grepl("^(read|load|download|setwd|system|source|make_|generate_|render_|build_|write)", fn_name)) {
    return(FALSE)
  }
  if (length(rhs) >= 2L) {
    return(all(vapply(as.list(rhs)[-1L], is_safe_script_constant_rhs, logical(1L))))
  }
  TRUE
}

#' Load only function definitions from a replication script
#'
#' Skips top-level execution (data load + pipe / legacy interactive footers)
#' when the package sources the file. Also evaluates safe top-level constants
#' referenced by sourced helper functions. Authors only need pure
#' \code{make_*} / \code{format_*} definitions; [run_replication()] supplies
#' the execute recipe from \code{replication.yml}.
#'
#' @param path Path to an R script.
#' @param env Environment in which to define functions.
#' @param install_deps Logical. Passed to dependency retry helper.
#' @param visited Optional environment memoizing normalized paths already sourced.
#' @keywords internal
source_replication_functions <- function(path, env, install_deps = FALSE, visited = NULL) {
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  if (is.null(visited)) {
    visited <- new.env(parent = emptyenv())
  }
  if (exists(path, envir = visited, inherits = FALSE)) {
    return(invisible(env))
  }
  assign(path, TRUE, envir = visited)

  exprs <- parse(path, keep.source = FALSE)
  code_dir <- dirname(path)

  for (expr in exprs) {
    if (is.call(expr)) {
      fn <- expr[[1]]
      fn_name <- if (is.name(fn)) {
        as.character(fn)
      } else if (is.character(fn)) {
        fn[[1]]
      } else {
        ""
      }

      if (fn_name %in% c("library", "require", "requireNamespace")) {
        retry_with_missing_package(
          eval(expr, envir = globalenv()),
          install_missing = allow_dependency_install(install_deps)
        )
        next
      }

      if (identical(fn, quote(source)) && length(expr) >= 2L) {
        src_arg <- expr[[2]]
        if (is.character(src_arg)) {
          src_path <- if (!grepl("^[A-Za-z]:[/\\\\]|^/", src_arg)) {
            file.path(code_dir, src_arg)
          } else {
            src_arg
          }
          if (file.exists(src_path)) {
            source_replication_functions(
              src_path,
              env,
              install_deps = install_deps,
              visited = visited
            )
          }
        }
        next
      }
    }

    if (!is.call(expr) || !identical(expr[[1]], quote(`<-`)) || length(expr) < 3) {
      next
    }

    lhs <- as.character(expr[[2]])
    rhs <- expr[[3]]
    is_fn <- is.call(rhs) && identical(as.character(rhs[[1]]), "function")
    is_alias <- is.symbol(rhs) || (is.call(rhs) && identical(rhs[[1]], quote(`<-`)))
    is_generate <- grepl("^generate_(table|figure)$", lhs)
    is_format <- grepl("^format_", lhs)

    if (is_fn || (is_generate && is_alias) || (is_format && is_alias)) {
      retry_with_missing_package(
        eval(expr, envir = env),
        install_missing = allow_dependency_install(install_deps)
      )
    } else if (is.name(expr[[2]]) && is_safe_script_constant_rhs(rhs)) {
      retry_with_missing_package(
        eval(expr, envir = env),
        install_missing = allow_dependency_install(install_deps)
      )
    }
  }

  invisible(env)
}

#' Standard make_* function name for a replication id
#'
#' @param what Replication identifier.
#' @keywords internal
make_function_name <- function(what) {
  paste0("make_", gsub("[^a-zA-Z0-9_]", "_", what))
}

#' Whether script lines call make_<id>() outside its definition
#'
#' Detects optional top-level / footer calls. Not required for Live Run —
#' [run_replication()] loads definitions and calls \code{make_*} from yaml.
#'
#' @param lines Character vector of script lines.
#' @param what Replication identifier.
#' @return Logical scalar.
#' @keywords internal
script_has_make_call <- function(lines, what) {
  make_name <- make_function_name(what)
  if (!length(lines)) {
    return(FALSE)
  }
  keep <- !grepl(
    paste0("^\\s*", make_name, "\\s*<-\\s*function\\b"),
    lines
  )
  any(grepl(paste0("\\b", make_name, "\\s*\\("), lines[keep]))
}

#' Preamble notes for the Shiny Code tab (prep is upstream)
#' @keywords internal
replication_code_display_preamble <- function(rep, meta = NULL) {
  parents <- unique(as.character(unlist(rep$parents %||% list(), use.names = FALSE)))
  parents <- parents[nzchar(parents)]
  inputs <- character(0)
  if (exists("replication_data_paths", mode = "function", inherits = TRUE)) {
    inputs <- tryCatch(
      as.character(replication_data_paths(rep) %||% character(0)),
      error = function(e) character(0)
    )
  }
  if (!length(inputs)) {
    inputs <- unique(as.character(unlist(
      c(rep$inputs %||% list(), rep$data %||% list()),
      use.names = FALSE
    )))
  }
  inputs <- inputs[nzchar(inputs)]
  if (!length(parents) && !length(inputs)) {
    return(character(0))
  }
  c(
    "# --- Display path notes (added by replicateEverything) ---",
    "# Upstream prep/transform steps run first; see Data steps in Shiny.",
    if (length(parents)) {
      paste0("# parents: ", paste(parents, collapse = ", "))
    },
    if (length(inputs)) {
      paste0("# inputs: ", paste(inputs, collapse = ", "))
    },
    "# Live Run executes this step via replication.yml.",
    "#"
  )
}

#' Epilogue notes for R scripts that define make_* but never call it
#'
#' R-only: commented yaml-implied load \eqn{\rightarrow}{->} make \eqn{\rightarrow}{->}
#' format recipe. Stata/Python scripts omit this (no fake R call chains).
#' @keywords internal
replication_code_display_epilogue <- function(rep, lines, meta = NULL) {
  type <- as.character(rep$type %||% "")
  if (!type %in% c("table", "figure")) {
    return(character(0))
  }
  eng <- if (exists("replication_engine", mode = "function", inherits = TRUE)) {
    tryCatch(
      replication_engine(rep, meta$paper %||% NULL),
      error = function(e) "r"
    )
  } else {
    tolower(as.character(rep$engine %||% "r")[[1]])
  }
  if (!identical(eng, "r")) {
    return(character(0))
  }
  what <- as.character(rep$id[[1]] %||% rep$id)
  make_name <- make_function_name(what)
  format_rel <- as.character(rep$format[[1]] %||% rep$format %||% "")
  out <- character(0)
  if (!script_has_make_call(lines, what)) {
    recipe <- character(0)
    if (exists("yaml_implied_call_lines", mode = "function", inherits = TRUE)) {
      recipe <- tryCatch(
        yaml_implied_call_lines(rep, lines),
        error = function(e) character(0)
      )
    }
    out <- c(
      out,
      "",
      "# --- Execute via replication.yml (get_code mode=run) ---",
      if (length(recipe)) {
        paste0("# ", recipe)
      } else {
        c(
          paste0("# object <- ", make_name, "(data)  # data from yaml data:/inputs:"),
          if (nzchar(format_rel)) {
            paste0("# then format via ", format_rel)
          } else {
            paste0("# then format_", what, "(object) when a format step exists")
          }
        )
      }
    )
  } else if (nzchar(format_rel) && grepl("[/\\\\]|\\.R$", format_rel, ignore.case = TRUE)) {
    out <- c(
      out,
      "",
      paste0("# Format helper (yaml format:): ", format_rel)
    )
  }
  out
}

#' Annotate entry-script lines for the Shiny Code tab
#' @keywords internal
annotate_replication_code_for_display <- function(lines, rep, meta = NULL) {
  c(
    replication_code_display_preamble(rep, meta = meta),
    lines,
    replication_code_display_epilogue(rep, lines, meta = meta)
  )
}

#' Checklist: R table/figure scripts define make_<id>()
#'
#' Footers / top-level calls are optional; yaml + [run_replication()] execute.
#' @keywords internal
check_replication_script_entries <- function(study_root, meta) {
  reps <- if (exists("folder_display_replications", mode = "function", inherits = TRUE)) {
    tryCatch(folder_display_replications(meta), error = function(e) NULL)
  } else {
    NULL
  }
  if (is.null(reps) || !length(reps)) {
    reps <- tryCatch(collect_study_step_entries(meta), error = function(e) list())
  }
  if (!length(reps)) {
    return(check_result("script_entries", TRUE, "No replications to check"))
  }
  rows <- list()
  for (rep in reps) {
    type <- as.character(rep$type %||% "")
    if (!type %in% c("table", "figure")) {
      next
    }
    eng <- tolower(as.character(rep$engine %||% "r"))
    code_rel <- as.character(rep$code[[1]] %||% rep$code %||% "")
    if (!nzchar(code_rel) || !grepl("\\.R$", code_rel, ignore.case = TRUE)) {
      next
    }
    if (!eng %in% c("r", "")) {
      next
    }
    rid <- as.character(rep$id[[1]] %||% rep$id)
    code_path <- file.path(study_root, code_rel)
    if (!file.exists(code_path)) {
      next
    }
    lines <- readLines(code_path, warn = FALSE, encoding = "UTF-8")
    make_name <- make_function_name(rid)
    has_def <- any(grepl(paste0("^\\s*", make_name, "\\s*<-\\s*function\\b"), lines))
    ok <- has_def
    msg <- if (!has_def) {
      paste0(code_rel, ": missing ", make_name, "()")
    } else {
      paste0(code_rel, ": ", make_name, "() defined (execute via replication.yml)")
    }
    rows[[length(rows) + 1L]] <- check_result(
      paste0("script_entry_", rid),
      ok,
      msg
    )
  }
  if (!length(rows)) {
    return(check_result("script_entries", TRUE, "No R table/figure scripts to check"))
  }
  do.call(bind_check_results, rows)
}

#' Resolve the analysis function from a sourced replication script
#'
#' @param env Environment containing sourced definitions.
#' @param what Replication identifier.
#' @param type Replication type (\code{figure} or \code{table}).
#' @keywords internal
get_analysis_function <- function(env, what, type) {
  make_name <- make_function_name(what)
  if (exists(make_name, envir = env, inherits = FALSE)) {
    return(get(make_name, envir = env, inherits = FALSE))
  }

  gen_name <- if (identical(type, "figure")) "generate_figure" else "generate_table"
  if (exists(gen_name, envir = env, inherits = FALSE)) {
    return(get(gen_name, envir = env, inherits = FALSE))
  }

  stop(
    "Replication script must define ", make_name, "() or ", gen_name, "().",
    call. = FALSE
  )
}
