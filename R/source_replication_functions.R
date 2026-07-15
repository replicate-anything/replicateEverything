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
#' Skips the self-run footer so top-level execution (data load + pipe) does not
#' run when the package sources the file. Also evaluates safe top-level constants
#' referenced by sourced helper functions.
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
