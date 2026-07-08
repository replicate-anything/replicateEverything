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
  study_root <- resolve_study_folder_path(meta, ctx)
  if (is.null(study_root) || !nzchar(study_root) || !dir.exists(study_root)) {
    study_root <- tryCatch(
      ensure_study_folder_local(meta, ctx),
      error = function(e) NULL
    )
  }
  if (!is.null(study_root) && nzchar(study_root) && dir.exists(study_root)) {
    return(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

#' Map a PyPI dependency spec to its Python import name
#'
#' Strips version specifiers, extras, and environment markers, then applies a
#' small set of well-known name overrides (e.g. \code{scikit-learn} ->
#' \code{sklearn}). Defaults to the distribution name with hyphens converted to
#' underscores.
#'
#' @param dep Character dependency spec (e.g. \code{"pandas>=1.5"}).
#' @return Character import name (may be empty).
#' @keywords internal
python_dep_import_name <- function(dep) {
  base <- trimws(as.character(dep))
  base <- sub(";.*$", "", base)
  base <- sub("\\[.*\\]", "", base)
  base <- sub("[<>=!~ ].*$", "", base)
  base <- trimws(base)
  overrides <- c(
    "scikit-learn" = "sklearn",
    "scikit-image" = "skimage",
    "pillow" = "PIL",
    "opencv-python" = "cv2",
    "opencv-python-headless" = "cv2",
    "beautifulsoup4" = "bs4",
    "pyyaml" = "yaml",
    "python-dateutil" = "dateutil"
  )
  key <- tolower(base)
  if (key %in% names(overrides)) {
    return(unname(overrides[[key]]))
  }
  gsub("-", "_", base)
}

#' Dependencies not importable by the target Python
#'
#' Probes with \code{python -c "import ..."}. Tries all imports at once first
#' (fast path when everything is already installed); only when that fails does
#' it probe each dependency individually to identify the missing ones. This lets
#' callers skip \code{pip install} entirely when packages are already present --
#' avoiding redundant local installs and spurious failures on locked-down
#' servers that forbid \code{pip}.
#'
#' @param python Path to the Python executable.
#' @param deps Character vector of PyPI dependency specs.
#' @return Character subset of \code{deps} that are not importable.
#' @keywords internal
python_missing_dependencies <- function(python, deps) {
  deps <- unique(deps[nzchar(deps)])
  if (length(deps) == 0L) {
    return(character(0))
  }
  imports <- vapply(deps, python_dep_import_name, character(1))
  keep <- nzchar(imports)
  deps <- deps[keep]
  imports <- imports[keep]
  if (length(deps) == 0L) {
    return(character(0))
  }
  quote_type <- if (.Platform$OS.type == "windows") "cmd" else "sh"
  importable <- function(mods) {
    code <- paste0("import ", paste(mods, collapse = ", "))
    status <- tryCatch(
      system2(
        python,
        c("-c", shQuote(code, type = quote_type)),
        stdout = FALSE,
        stderr = FALSE
      ),
      error = function(e) 1L
    )
    identical(status, 0L)
  }
  if (importable(imports)) {
    return(character(0))
  }
  missing <- character(0)
  for (i in seq_along(deps)) {
    if (!importable(imports[i])) {
      missing <- c(missing, deps[i])
    }
  }
  missing
}

#' Run \code{pip} and return its exit status and output
#'
#' Uses \code{stdout/stderr = TRUE}, so the return value of \code{system2()} is
#' captured output; the exit code lives in its \code{"status"} attribute.
#'
#' @param python Path to the Python executable.
#' @param args Character vector of arguments following \code{-m pip}.
#' @return List with integer \code{status} and character \code{output}.
#' @keywords internal
pip_install <- function(python, args) {
  out <- suppressWarnings(
    system2(python, c("-m", "pip", args), stdout = TRUE, stderr = TRUE)
  )
  status <- attr(out, "status")
  list(
    status = if (is.null(status)) 0L else as.integer(status),
    output = as.character(out)
  )
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
  err_tail <- function(output) {
    if (length(output) == 0L) {
      return("")
    }
    paste0(":\n", paste(utils::tail(output, 15L), collapse = "\n"))
  }

  if (!is.null(req_path) && file.exists(req_path)) {
    message("Installing Python requirements from ", basename(req_path), " ...")
    res <- pip_install(
      python,
      c("install", "-q", "-r", shQuote(req_path, type = quote_type))
    )
    if (!identical(res$status, 0L)) {
      stop(
        "Failed to install Python requirements from ", req_path,
        err_tail(res$output),
        call. = FALSE
      )
    }
  }

  if (length(deps) > 0L) {
    missing <- python_missing_dependencies(python, deps)
    if (length(missing) == 0L) {
      message("Python dependencies already satisfied: ", paste(deps, collapse = ", "))
    } else {
      message("Installing Python dependencies: ", paste(missing, collapse = ", "))
      res <- pip_install(python, c("install", "-q", missing))
      if (!identical(res$status, 0L)) {
        still_missing <- python_missing_dependencies(python, missing)
        if (length(still_missing) > 0L) {
          stop(
            "Failed to install Python dependencies: ",
            paste(still_missing, collapse = ", "),
            err_tail(res$output),
            call. = FALSE
          )
        }
      }
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
  if (dir.exists(run_dir)) {
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(run_dir)
  }
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
  if (dir.exists(run_dir)) {
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    setwd(run_dir)
  }
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
