#' Replication engine for a single entry
#'
#' @param rep Replication entry from \code{replication.yml}.
#' @param paper_meta Optional paper-level metadata.
#' @return \code{"r"} or \code{"stata"}.
#' @keywords internal
replication_engine <- function(rep, paper_meta = NULL) {
  eng <- rep$engine %||% NULL
  if (!is.null(eng) && length(eng) > 0L) {
    value <- tolower(as.character(eng[[1]]))
    if (value %in% c("stata", "r")) {
      return(value)
    }
  }

  if (!is.null(paper_meta)) {
    lang <- paper_meta$language %||% NULL
    if (!is.null(lang) && length(lang) > 0L) {
      value <- tolower(as.character(lang[[1]]))
      if (value %in% c("stata", "r")) {
        return(value)
      }
    }
  }

  code <- as.character(rep$code %||% "")
  if (length(code) == 1L && grepl("\\.do$", code, ignore.case = TRUE)) {
    return("stata")
  }

  "r"
}

#' Whether a replication entry runs in Stata
#'
#' @param rep Replication entry from \code{replication.yml}.
#' @param paper_meta Optional paper-level metadata.
#' @return Logical.
#' @keywords internal
is_stata_replication <- function(rep, paper_meta = NULL) {
  identical(replication_engine(rep, paper_meta), "stata")
}

#' Build common Stata install paths for the current OS
#'
#' @return Character vector of candidate executable paths.
#' @keywords internal
stata_executable_candidates <- function() {
  path_bins <- c(
    Sys.which("stata-mp"),
    Sys.which("stata-se"),
    Sys.which("stata"),
    Sys.which("StataMP-64"),
    Sys.which("xstata-mp"),
    Sys.which("xstata")
  )

  windows_bins <- c(
    "C:/Program Files/Stata18/StataMP-64.exe",
    "C:/Program Files/Stata18/StataSE-64.exe",
    "C:/Program Files/Stata18/Stata-64.exe",
    "C:/Program Files/Stata17/StataMP-64.exe",
    "C:/Program Files/Stata17/StataSE-64.exe",
    "C:/Program Files/Stata17/Stata-64.exe",
    "C:/Program Files/Stata16/StataMP-64.exe",
    "C:/Program Files (x86)/Stata18/StataMP-64.exe",
    "C:/Program Files (x86)/Stata17/StataMP-64.exe"
  )

  linux_roots <- c(
    "/usr/local",
    "/opt",
    "/apps",
    "/software",
    Sys.getenv("STATA_HOME", unset = ""),
    Sys.getenv("STATA_PATH", unset = "")
  )
  linux_roots <- unique(linux_roots[nzchar(linux_roots)])
  linux_bins <- character(0)
  for (root in linux_roots) {
    for (ver in c("18", "17", "16", "15")) {
      base <- file.path(root, paste0("stata", ver))
      linux_bins <- c(
        linux_bins,
        file.path(base, "stata-mp"),
        file.path(base, "stata-se"),
        file.path(base, "stata")
      )
    }
    linux_bins <- c(
      linux_bins,
      file.path(root, "stata-mp"),
      file.path(root, "stata-se"),
      file.path(root, "stata")
    )
  }

  mac_bins <- c(
    "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp",
    "/Applications/Stata/StataSE.app/Contents/MacOS/stata-se",
    "/Applications/Stata/StataIC.app/Contents/MacOS/stata",
    "/Applications/StataNow/StataMP.app/Contents/MacOS/stata-mp"
  )

  if (.Platform$OS.type == "windows") {
    c(path_bins, windows_bins, linux_bins, mac_bins)
  } else if (grepl("darwin", R.version$os, ignore.case = TRUE)) {
    c(path_bins, mac_bins, linux_bins)
  } else {
    c(path_bins, linux_bins)
  }
}

#' Locate a Stata executable
#'
#' Checks \code{getOption("replicateEverything.stata_executable")} first, then
#' common install paths (Windows, Linux, macOS) and \code{PATH}.
#'
#' @return Normalized path or \code{NULL}.
#' @export
find_stata_executable <- function() {
  opt <- getOption("replicateEverything.stata_executable", NULL)
  if (!is.null(opt) && nzchar(opt) && file.exists(opt)) {
    return(normalizePath(opt, winslash = "/", mustWork = FALSE))
  }

  candidates <- unique(stata_executable_candidates())
  candidates <- candidates[nzchar(candidates)]
  for (path in candidates) {
    if (file.exists(path)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' @keywords internal
stata_path_for_shell <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type == "windows") {
    gsub("/", "\\", path, fixed = TRUE)
  } else {
    path
  }
}

#' @keywords internal
stata_path_in_do <- function(path) {
  gsub("\\", "/", normalizePath(path, winslash = "/", mustWork = FALSE), fixed = TRUE)
}

#' Run a Stata do-file non-interactively
#'
#' @param do_path Path to the do-file.
#' @param workdir Working directory Stata should use.
#' @param timeout Seconds before aborting (best effort on Windows).
#' @keywords internal
run_stata_do <- function(do_path, workdir, timeout = 900L) {
  stata <- find_stata_executable()
  if (is.null(stata)) {
    stop(
      "Stata executable not found. Install Stata or set ",
      "options(replicateEverything.stata_executable = '/path/to/StataMP-64.exe').",
      call. = FALSE
    )
  }

  do_path <- normalizePath(do_path, winslash = "/", mustWork = TRUE)
  workdir <- normalizePath(workdir, winslash = "/", mustWork = TRUE)

  runner <- file.path(tempdir(), paste0("replicate_", gsub("[^a-zA-Z0-9._-]", "_", basename(do_path))))
  do_in_do <- stata_path_in_do(do_path)
  wd_in_do <- stata_path_in_do(workdir)

  writeLines(
    c(
      "version 17",
      "clear all",
      "set more off, permanently",
      sprintf("local root \"%s\"", wd_in_do),
      "cd \"`root'\"",
      sprintf("do \"%s\"", do_in_do)
    ),
    runner,
    useBytes = TRUE
  )

  log_path <- sub("\\.do$", ".log", runner, ignore.case = TRUE)
  if (file.exists(log_path)) {
    unlink(log_path)
  }

  status <- system2(
    stata,
    c("/e", "do", runner),
    wait = TRUE,
    stdout = "",
    stderr = ""
  )

  stata_err <- stata_log_error(log_path)
  if (!is.null(stata_err)) {
    stop("Stata error: ", stata_err, call. = FALSE)
  }
  if (!identical(status, 0L) && !identical(status, 0)) {
    stop("Stata exited with status ", status, call. = FALSE)
  }

  invisible(log_path)
}

#' @keywords internal
stata_log_error <- function(log_path) {
  if (!file.exists(log_path)) {
    return(NULL)
  }
  lines <- readLines(log_path, warn = FALSE, encoding = "UTF-8")
  err_idx <- grep("^r\\([0-9]+\\);", lines)
  if (length(err_idx) == 0L) {
    return(NULL)
  }
  start <- max(1L, err_idx[[1]] - 3L)
  end <- min(length(lines), err_idx[[1]] + 1L)
  paste(lines[start:end], collapse = "\n")
}

#' Extract the output file path from a Stata replication result
#'
#' Accepts a \code{stata_replication_result} list or a plain character path.
#'
#' @param object Stata result list or path to \code{.smcl}/image output.
#' @return Character path or \code{NULL}.
#' @export
stata_result_path <- function(object) {
  if (is.null(object)) {
    return(NULL)
  }
  if (is.character(object) && length(object) == 1L && nzchar(object)) {
    return(object)
  }
  if (is.list(object) && !is.data.frame(object)) {
    path <- object$output_path %||% object$smcl_path %||% NULL
    if (is.null(path)) {
      return(NULL)
    }
    if (length(path) > 1L) {
      path <- path[[1L]]
    }
    path <- as.character(path)
    if (nzchar(path)) {
      return(path)
    }
  }
  NULL
}

#' Normalize a Stata result for format functions
#'
#' @param object Stata result list, path, or replication envelope.
#' @return A \code{stata_replication_result} list when possible.
#' @keywords internal
normalize_stata_result_object <- function(object) {
  if (inherits(object, "stata_replication_result")) {
    return(object)
  }
  path <- stata_result_path(object)
  if (is.null(path)) {
    return(object)
  }
  structure(
    list(
      output_path = path,
      smcl_path = if (identical(stata_output_extension(path), "smcl")) {
        path
      } else {
        NULL
      }
    ),
    class = c("stata_replication_result", "list")
  )
}

#' Resolve Stata output path for a replication entry
#'
#' @param rep Replication entry.
#' @param study_root Study repository root.
#' @keywords internal
stata_output_path <- function(rep, study_root) {
  rel <- rep$output %||% rep$stata_output %||% NULL
  if (!is.null(rel) && length(rel) > 0L && nzchar(as.character(rel[[1]]))) {
    return(file.path(study_root, as.character(rel[[1]])))
  }
  file.path(study_root, "artifacts", "staging", paste0(rep$id, ".smcl"))
}

#' @keywords internal
stata_output_extension <- function(path) {
  tolower(tools::file_ext(path))
}

#' @keywords internal
stata_output_is_image <- function(path) {
  stata_output_extension(path) %in% c("png", "svg", "jpg", "jpeg")
}

#' Run a Stata-backed replication entry
#'
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param meta Optional parsed replication metadata for study resolution.
#' @return A \code{stata_replication_result} list.
#' @keywords internal
run_stata_replication <- function(rep, ctx, meta = NULL) {
  study_root <- ensure_study_folder_local(meta, ctx)
  if (is.null(study_root) || !dir.exists(study_root)) {
    stop(
      "Stata replication requires a local study folder. ",
      "Set options(replicateEverything.study_folders = list(<folder> = '/path/to/study')) ",
      "or ensure the study repo is reachable on GitHub.",
      call. = FALSE
    )
  }

  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  ctx$local_root <- study_root
  code_path <- resolve_registry_file(rep$code, ctx, meta = meta)
  staging <- file.path(study_root, "artifacts", "staging")
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)

  if (!is.null(rep$data)) {
    ensure_study_data_files(rep$data, study_root, meta, ctx)
  }

  run_stata_do(code_path, study_root)

  output_path <- stata_output_path(rep, study_root)
  if (!file.exists(output_path)) {
    stop(
      "Expected Stata output not found at ", output_path,
      ". Check replication.yml `output` path.",
      call. = FALSE
    )
  }

  output_path <- normalizePath(output_path, winslash = "/", mustWork = FALSE)

  structure(
    list(
      output_path = output_path,
      smcl_path = if (identical(stata_output_extension(output_path), "smcl")) {
        output_path
      } else {
        NULL
      },
      study_root = study_root,
      replication_id = rep$id
    ),
    class = c("stata_replication_result", "list")
  )
}

#' Ensure Stata is available for a replication entry
#'
#' @param rep Replication entry.
#' @keywords internal
ensure_stata_available <- function(rep) {
  if (is.null(find_stata_executable())) {
    stop(
      "Replication ", rep$id, " requires Stata. ",
      "Install Stata or set options(replicateEverything.stata_executable = ...).",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Convert a Stata SMCL file to HTML for display
#'
#' Uses Stata's \code{translate} command when available; otherwise wraps raw
#' SMCL in a monospace block.
#'
#' @param smcl_path Path to an \code{.smcl} file.
#' @return Character scalar containing HTML.
#' @export
smcl_to_html <- function(smcl_path) {
  if (!file.exists(smcl_path)) {
    stop("SMCL file not found: ", smcl_path, call. = FALSE)
  }

  txt_path <- sub("\\.smcl$", ".txt", smcl_path, ignore.case = TRUE)
  if (file.exists(txt_path)) {
    unlink(txt_path)
  }

  translated <- tryCatch(
    {
      runner <- file.path(tempdir(), "translate_smcl.do")
      smcl_win <- stata_path_for_shell(smcl_path)
      txt_win <- stata_path_for_shell(txt_path)
      writeLines(
        sprintf('translate "%s" "%s", replace', smcl_win, txt_win),
        runner,
        useBytes = TRUE
      )
      run_stata_do(runner, dirname(smcl_path))
      file.exists(txt_path)
    },
    error = function(e) FALSE
  )

  if (isTRUE(translated)) {
    text <- paste(readLines(txt_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    text <- htmltools::htmlEscape(text)
    return(paste0('<pre class="stata-output replication-table">', text, "</pre>"))
  }

  raw <- paste(readLines(smcl_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  raw <- htmltools::htmlEscape(raw)
  paste0('<pre class="stata-output replication-table">', raw, "</pre>")
}

#' Code language for display (Shiny / get_code)
#'
#' @param rep Replication entry.
#' @param paper_meta Optional paper metadata.
#' @return \code{"stata"} or \code{"r"}.
#' @keywords internal
replication_code_language <- function(rep, paper_meta = NULL) {
  if (identical(replication_engine(rep, paper_meta), "stata")) {
    return("stata")
  }
  "r"
}

#' Code language for a replication (for Shiny syntax highlighting)
#'
#' @inheritParams render_replication
#' @return \code{"stata"} or \code{"r"}.
#' @export
replication_code_language_for <- function(doi, what, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  rep <- find_replication_entry(meta, what)
  replication_code_language(rep, meta$paper)
}
