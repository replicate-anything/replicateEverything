#' Whether a replication entry runs in Python
#'
#' @inheritParams is_stata_replication
#' @return Logical.
#' @keywords internal
is_python_replication <- function(rep, paper_meta = NULL) {
  identical(replication_engine(rep, paper_meta), "python")
}

#' Candidate Python executables
#'
#' @return Character vector of paths.
#' @keywords internal
python_executable_candidates <- function() {
  bins <- c(
    Sys.getenv("PYTHON", unset = ""),
    Sys.getenv("RETICULATE_PYTHON", unset = ""),
    unname(Sys.which(c("python3", "python", "py"))),
    "C:/Python312/python.exe",
    "C:/Python311/python.exe",
    "C:/Python310/python.exe",
    "/usr/bin/python3",
    "/usr/local/bin/python3"
  )
  bins <- unique(bins[nzchar(bins)])
  bins[file.exists(bins)]
}

#' Find a Python executable
#'
#' @return Character path.
#' @keywords internal
find_python_executable <- function() {
  candidates <- python_executable_candidates()
  if (length(candidates) == 0L) {
    stop(
      "Python not found. Install Python 3.10+ and ensure it is on PATH, ",
      "or set Sys.setenv(PYTHON = '/path/to/python').",
      call. = FALSE
    )
  }
  candidates[[1]]
}

#' Ensure Python is available
#'
#' @keywords internal
ensure_python_available <- function(rep = NULL) {
  invisible(find_python_executable())
}

#' Working directory for a Python replication run
#'
#' @inheritParams stata_run_dir
#' @keywords internal
python_run_dir <- function(rep, ctx, meta = NULL) {
  study_root <- resolve_study_folder_path(ctx, meta = meta)
  if (!is.null(study_root) && nzchar(study_root) && dir.exists(study_root)) {
    return(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

#' Ensure Python pip dependencies for a replication entry
#'
#' Installs packages listed under entry-level \code{dependencies} (engine
#' \code{python} only) or a \code{requirements} file path when
#' \code{install_missing = TRUE}.
#'
#' @keywords internal
ensure_python_dependencies <- function(
  replication_meta,
  paper_meta = NULL,
  ctx = NULL,
  meta = NULL,
  install_missing = FALSE
) {
  if (!identical(replication_engine(replication_meta, paper_meta), "python")) {
    return(invisible(TRUE))
  }

  req_rel <- replication_meta$requirements %||% NULL
  req_path <- NULL
  if (!is.null(req_rel) && nzchar(as.character(req_rel))) {
    if (!is.null(ctx)) {
      req_path <- resolve_registry_file(as.character(req_rel), ctx, meta = meta)
    } else {
      req_path <- as.character(req_rel)
    }
  }

  deps <- character(0)
  if (!is.null(replication_meta$dependencies)) {
    deps <- c(deps, unlist(replication_meta$dependencies, use.names = FALSE))
  }
  deps <- unique(na.omit(as.character(deps)))
  deps <- deps[nzchar(deps)]

  if (length(deps) == 0 && (is.null(req_path) || !file.exists(req_path))) {
    return(invisible(TRUE))
  }

  if (!isTRUE(install_missing)) {
    return(invisible(TRUE))
  }

  python <- find_python_executable()
  quote_type <- if (.Platform$OS.type == "windows") "cmd" else "sh"

  if (!is.null(req_path) && file.exists(req_path)) {
    message("Installing Python requirements from ", basename(req_path), " ...")
    status <- system2(
      python,
      c("-m", "pip", "install", "-q", "-r", shQuote(req_path, type = quote_type)),
      stdout = TRUE,
      stderr = TRUE
    )
    if (!identical(status, 0L)) {
      stop(
        "Failed to install Python requirements from ", req_path,
        call. = FALSE
      )
    }
  }

  if (length(deps) > 0L) {
    message("Installing Python dependencies: ", paste(deps, collapse = ", "))
    status <- system2(
      python,
      c("-m", "pip", "install", "-q", deps),
      stdout = TRUE,
      stderr = TRUE
    )
    if (!identical(status, 0L)) {
      stop(
        "Failed to install Python dependencies: ",
        paste(deps, collapse = ", "),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

#' Execute a Python script or notebook
#'
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param meta Parsed metadata.
#' @param install_deps When \code{TRUE}, install pip dependencies before running.
#' @keywords internal
run_python_replication <- function(rep, ctx, meta = NULL, install_deps = FALSE) {
  ensure_python_dependencies(
    rep,
    paper_meta = meta$paper %||% NULL,
    ctx = ctx,
    meta = meta,
    install_missing = install_deps
  )
  python <- find_python_executable()
  code_rel <- as.character(rep$code %||% "")
  if (!nzchar(code_rel)) {
    stop("Python replication ", rep$id, " is missing a code path.", call. = FALSE)
  }
  code_path <- resolve_registry_file(code_rel, ctx, meta = meta)
  if (!file.exists(code_path)) {
    stop("Python code not found: ", code_path, call. = FALSE)
  }

  run_dir <- python_run_dir(rep, ctx, meta = meta)
  out_path <- rep$output %||% rep$artifact %||% NULL
  if (!is.null(out_path) && nzchar(as.character(out_path))) {
    out_path <- resolve_registry_file(as.character(out_path), ctx, meta = meta, local_only = TRUE)
    dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
    Sys.setenv(REPLICATE_PYTHON_OUTPUT = out_path)
  } else {
    Sys.setenv(REPLICATE_PYTHON_OUTPUT = "")
  }

  ext <- tolower(tools::file_ext(code_path))
  log_path <- file.path(
    run_dir,
    "artifacts",
    "staging",
    paste0(as.character(rep$id), "_python.log")
  )
  dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)

  status <- if (ext == "ipynb") {
    run_python_notebook(python, code_path, run_dir, log_path)
  } else {
    run_python_script(python, code_path, run_dir, log_path)
  }

  if (!identical(status, 0L)) {
    log_tail <- if (file.exists(log_path)) {
      paste(tail(readLines(log_path, warn = FALSE), 20L), collapse = "\n")
    } else {
      ""
    }
    stop(
      "Python replication failed for ", rep$id,
      if (nzchar(log_tail)) paste0(":\n", log_tail) else ".",
      call. = FALSE
    )
  }

  result_path <- Sys.getenv("REPLICATE_PYTHON_OUTPUT", unset = "")
  if (nzchar(result_path) && file.exists(result_path)) {
    ext_out <- tolower(tools::file_ext(result_path))
    if (ext_out %in% c("png", "jpg", "jpeg", "gif", "svg", "pdf")) {
      return(structure(
        list(output_path = result_path, type = "image"),
        class = "python_replication_result"
      ))
    }
    if (ext_out %in% c("csv")) {
      return(structure(
        list(
          output_path = result_path,
          preview = utils::read.csv(result_path, nrows = 6L, stringsAsFactors = FALSE)
        ),
        class = "python_replication_result"
      ))
    }
    return(structure(list(output_path = result_path), class = "python_replication_result"))
  }

  log_body <- if (file.exists(log_path)) {
    paste(readLines(log_path, warn = FALSE), collapse = "\n")
  } else {
    "Python replication completed."
  }
  structure(
    list(output_path = log_path, text = log_body),
    class = "python_replication_result"
  )
}

#' @keywords internal
run_python_script <- function(python, script_path, run_dir, log_path) {
  script_path <- normalizePath(script_path, winslash = "/", mustWork = TRUE)
  quote_type <- if (.Platform$OS.type == "windows") "cmd" else "sh"
  old_root <- Sys.getenv("REPLICATE_STUDY_ROOT", unset = NA)
  on.exit({
    if (is.na(old_root)) {
      Sys.unsetenv("REPLICATE_STUDY_ROOT")
    } else {
      Sys.setenv(REPLICATE_STUDY_ROOT = old_root)
    }
  }, add = TRUE)
  Sys.setenv(REPLICATE_STUDY_ROOT = run_dir)
  system2(
    python,
    args = shQuote(script_path, type = quote_type),
    stdout = log_path,
    stderr = log_path,
    wait = TRUE
  )
}

#' @keywords internal
run_python_notebook <- function(python, notebook_path, run_dir, log_path) {
  out_nb <- file.path(
    dirname(notebook_path),
    paste0(tools::file_path_sans_ext(basename(notebook_path)), "_executed.ipynb")
  )
  args <- c(
    "-m", "jupyter", "nbconvert",
    "--execute",
    "--to", "notebook",
    "--output", shQuote(basename(out_nb)),
    "--output-dir", shQuote(dirname(notebook_path)),
    shQuote(normalizePath(notebook_path, winslash = "/", mustWork = TRUE))
  )
  old_root <- Sys.getenv("REPLICATE_STUDY_ROOT", unset = NA)
  on.exit({
    if (is.na(old_root)) {
      Sys.unsetenv("REPLICATE_STUDY_ROOT")
    } else {
      Sys.setenv(REPLICATE_STUDY_ROOT = old_root)
    }
  }, add = TRUE)
  Sys.setenv(REPLICATE_STUDY_ROOT = run_dir)
  status <- system2(
    python,
    args,
    stdout = log_path,
    stderr = log_path,
    wait = TRUE
  )
  if (!identical(status, 0L)) {
    return(status)
  }
  0L
}

#' Code language for Python entries
#'
#' @keywords internal
replication_code_language_python <- function() {
  "python"
}
