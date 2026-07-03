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

#' @keywords internal
stata_shell_do_path <- function(path) {
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (.Platform$OS.type != "windows" || !grepl(" ", path, fixed = TRUE)) {
    return(path)
  }
  short <- tryCatch(utils::shortPathName(path), error = function(e) NULL)
  if (!is.null(short) && nzchar(short)) {
    short <- gsub("\\", "/", short, fixed = TRUE)
    if (!grepl(" ", short, fixed = TRUE)) {
      return(short)
    }
  }
  path
}

#' Stata command-line arguments for non-interactive do-file execution
#'
#' Windows: \code{/e do file.do}. Unix/Linux/macOS: \code{-b file.do}.
#' Paths with spaces are shortened on Windows when possible.
#'
#' @param do_path Path to the do-file.
#' @return Character vector of arguments for \code{system2()}.
#' @keywords internal
stata_batch_args <- function(do_path) {
  path <- stata_shell_do_path(do_path)
  if (.Platform$OS.type == "windows") {
    return(c("/e", "do", path))
  }
  c("-b", path)
}

#' @keywords internal
stata_batch_log_name <- function(runner_path) {
  sub("\\.do$", ".log", basename(runner_path), ignore.case = TRUE)
}

#' @keywords internal
stata_stray_batch_log_paths <- function(dirs, log_name) {
  dirs <- unique(dirs[nzchar(dirs)])
  dirs <- dirs[dir.exists(dirs)]
  if (!length(dirs) || !nzchar(log_name)) {
    return(character(0))
  }
  unique(unlist(lapply(dirs, function(dir) {
    path <- file.path(dir, log_name)
    if (file.exists(path)) path else character(0)
  }), use.names = FALSE))
}

#' @keywords internal
relocate_stata_batch_log <- function(from, to) {
  if (!length(from) || !nzchar(from) || !file.exists(from)) {
    return(invisible(FALSE))
  }
  to <- normalizePath(to, winslash = "/", mustWork = FALSE)
  from <- normalizePath(from, winslash = "/", mustWork = FALSE)
  if (identical(from, to)) {
    return(invisible(TRUE))
  }
  dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(to)) {
    unlink(to)
  }
  moved <- file.rename(from, to)
  if (!isTRUE(moved)) {
    file.copy(from, to, overwrite = TRUE)
    unlink(from)
  }
  invisible(TRUE)
}

#' @keywords internal
cleanup_stata_stray_batch_logs <- function(dirs, log_name, keep = NULL) {
  keep <- keep %||% character(0)
  paths <- stata_stray_batch_log_paths(dirs, log_name)
  if (length(keep)) {
    keep <- normalizePath(keep, winslash = "/", mustWork = FALSE)
    paths <- paths[!normalizePath(paths, winslash = "/", mustWork = FALSE) %in% keep]
  }
  if (length(paths)) {
    unlink(paths)
  }
  invisible(paths)
}

#' Run a Stata do-file non-interactively
#'
#' @param do_path Path to the do-file.
#' @param workdir Working directory Stata should use.
#' @param timeout Seconds before aborting (best effort on Windows).
#' @param staging_dir Optional writable directory for \code{$result} output.
#' @return A \code{stata_run_result} list with log path and diagnostics.
#' @keywords internal
run_stata_do <- function(do_path, workdir, timeout = 900L, staging_dir = NULL) {
  stata <- find_stata_executable()
  if (is.null(stata)) {
    stop(
      "Stata executable not found. Install Stata or set ",
      "options(replicateEverything.stata_executable = '/path/to/StataMP-64.exe').",
      call. = FALSE
    )
  }

  do_path <- normalizePath(do_path, winslash = "/", mustWork = TRUE)
  workdir <- normalizePath(workdir, winslash = "/", mustWork = FALSE)

  run_dir <- stata_run_dir(workdir, staging_dir)
  runner <- file.path(
    run_dir,
    paste0("replicate_", gsub("[^a-zA-Z0-9._-]", "_", basename(do_path)))
  )
  do_in_do <- stata_path_in_do(do_path)
  wd_in_do <- stata_path_in_do(workdir)

  runner_lines <- c(
    "version 17",
    "clear all",
    "set more off, permanently",
    sprintf("local root \"%s\"", wd_in_do),
    "cd \"`root'\""
  )
  if (!is.null(staging_dir) && nzchar(staging_dir)) {
    staging_dir <- normalizePath(staging_dir, winslash = "/", mustWork = FALSE)
    dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
    staging_in_do <- stata_path_in_do(staging_dir)
    runner_lines <- c(
      runner_lines,
      sprintf("global REPLICATE_STATA_RESULT \"%s\"", staging_in_do),
      sprintf("cap mkdir \"%s\"", staging_in_do)
    )
  }
  runner_lines <- c(runner_lines, sprintf("do \"%s\"", do_in_do))

  writeLines(runner_lines, runner, useBytes = TRUE)

  log_name <- stata_batch_log_name(runner)
  log_path <- file.path(run_dir, log_name)
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    cleanup_stata_stray_batch_logs(
      c(workdir, old_wd),
      log_name,
      keep = if (file.exists(log_path)) log_path else character(0)
    )
    cleanup_stata_run_dir(run_dir)
  }, add = TRUE)

  cleanup_stata_stray_batch_logs(c(workdir, old_wd, run_dir), log_name, keep = log_path)
  if (file.exists(log_path)) {
    unlink(log_path)
  }

  batch_args <- stata_batch_args(runner)

  if (dir.exists(run_dir)) {
    setwd(run_dir)
  }

  status <- system2(
    stata,
    batch_args,
    wait = TRUE,
    stdout = "",
    stderr = ""
  )

  strays <- stata_stray_batch_log_paths(c(workdir, old_wd), log_name)
  if (length(strays) && !file.exists(log_path)) {
    relocate_stata_batch_log(strays[[1]], log_path)
  }
  cleanup_stata_stray_batch_logs(c(workdir, old_wd), log_name, keep = log_path)

  log_exists <- file.exists(log_path)
  stata_err <- if (log_exists) stata_log_error(log_path) else NULL

  result <- structure(
    list(
      log_path = log_path,
      exit_status = status,
      stata_executable = stata,
      batch_args = batch_args,
      do_path = do_path,
      workdir = workdir,
      staging_dir = staging_dir,
      log_exists = log_exists,
      log_tail = if (log_exists) stata_log_tail(log_path) else NULL,
      stata_error = stata_err,
      ran = TRUE
    ),
    class = "stata_run_result"
  )

  if (!is.null(stata_err)) {
    stop(
      stata_run_failed_message(result),
      call. = FALSE
    )
  }
  if (!identical(status, 0L) && !identical(status, 0)) {
    stop(
      stata_run_failed_message(result),
      call. = FALSE
    )
  }

  result
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

#' @keywords internal
stata_log_tail <- function(log_path, n = 40L) {
  if (!file.exists(log_path)) {
    return(NULL)
  }
  lines <- readLines(log_path, warn = FALSE, encoding = "UTF-8")
  if (length(lines) <= n) {
    return(paste(lines, collapse = "\n"))
  }
  paste(lines[(length(lines) - n + 1L):length(lines)], collapse = "\n")
}

#' @keywords internal
describe_directory <- function(path, label = "Directory") {
  if (is.null(path) || !nzchar(path) || !dir.exists(path)) {
    return(paste0(label, ": (missing) ", path))
  }
  entries <- tryCatch(
    list.files(path, all.files = FALSE),
    error = function(e) character(0)
  )
  paste0(
    label, ": ", normalizePath(path, winslash = "/", mustWork = FALSE), "\n",
    if (length(entries)) {
      paste0("  ", paste(entries, collapse = "\n  "))
    } else {
      "  (empty)"
    }
  )
}

#' @keywords internal
stata_run_failed_message <- function(run) {
  paste0(
    "Stata replication failed.\n",
    "Stata ran: ", if (isTRUE(run$ran)) "yes" else "no", "\n",
    "Executable: ", run$stata_executable %||% "(unknown)", "\n",
    if (!is.null(run$batch_args)) {
      paste0("Invocation: ", paste(run$batch_args, collapse = " "), "\n")
    } else {
      ""
    },
    "Exit status: ", run$exit_status %||% "(unknown)", "\n",
    "Do-file: ", run$do_path %||% "(unknown)", "\n",
    "Working directory: ", run$workdir %||% "(unknown)", "\n",
    if (!is.null(run$staging_dir) && nzchar(run$staging_dir)) {
      paste0("Staging directory: ", run$staging_dir, "\n")
    } else {
      ""
    },
    "Log file: ", run$log_path %||% "(unknown)", "\n",
    "Log exists: ", if (isTRUE(run$log_exists)) "yes" else "no", "\n",
    if (!is.null(run$stata_error)) {
      paste0("Stata error:\n", run$stata_error, "\n")
    } else {
      ""
    },
    if (!is.null(run$log_tail) && nzchar(run$log_tail)) {
      paste0("Log tail:\n", run$log_tail, "\n")
    } else {
      ""
    }
  )
}

#' @keywords internal
stata_output_missing_message <- function(output_path, study_root, run, staging_dir = NULL) {
  expected_name <- basename(output_path)
  staging_candidates <- character(0)
  if (!is.null(staging_dir) && nzchar(staging_dir)) {
    staging_candidates <- c(
      file.path(staging_dir, expected_name),
      file.path(study_root, "artifacts", "staging", expected_name)
    )
  }
  paste0(
    "Expected Stata output not found.\n",
    "Expected file: ", output_path, "\n",
    "Stata ran: ", if (isTRUE(run$ran)) "yes" else "no", "\n",
    "Executable: ", run$stata_executable %||% "(unknown)", "\n",
    if (!is.null(run$batch_args)) {
      paste0("Invocation: ", paste(run$batch_args, collapse = " "), "\n")
    } else {
      ""
    },
    "Exit status: ", run$exit_status %||% "(unknown)", "\n",
    "Do-file: ", run$do_path %||% "(unknown)", "\n",
    "Study folder (code): ", study_root, "\n",
    if (!is.null(run$staging_dir) && nzchar(run$staging_dir)) {
      paste0("Staging directory: ", run$staging_dir, "\n")
    } else {
      ""
    },
    "Log file: ", run$log_path %||% "(unknown)", "\n",
    "Log exists: ", if (isTRUE(run$log_exists)) "yes" else "no", "\n",
    if (length(staging_candidates)) {
      paste0(
        "Also checked:\n",
        paste0("  - ", staging_candidates, collapse = "\n"),
        "\n"
      )
    } else {
      ""
    },
    if (!is.null(run$stata_error)) {
      paste0("Stata error:\n", run$stata_error, "\n")
    } else {
      ""
    },
    if (!is.null(run$log_tail) && nzchar(run$log_tail)) {
      paste0("Log tail:\n", run$log_tail, "\n")
    } else {
      ""
    },
    describe_directory(file.path(study_root, "artifacts", "staging"), "Study staging"),
    if (!is.null(staging_dir) && nzchar(staging_dir)) {
      paste0("\n", describe_directory(staging_dir, "Writable staging"))
    } else {
      ""
    }
  )
}

#' Writable staging directory for Stata output
#'
#' Uses \code{<study>/artifacts/staging} when the study folder is writable;
#' otherwise falls back to \code{<study_data_root>/staging/<study>} (Shiny server).
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param study_root Optional local study repository root.
#' @return Normalized path.
#' @keywords internal
writable_stata_staging_dir <- function(meta, ctx = NULL, study_root = NULL) {
  if (is.null(study_root) && !is.null(ctx$local_root)) {
    study_root <- ctx$local_root
  }
  if (!is.null(study_root) && nzchar(study_root)) {
    candidate <- file.path(study_root, "artifacts", "staging")
    if (staging_dir_is_writable(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    }
  }

  study_name <- study_data_folder_name(meta, ctx)
  dir <- file.path(study_data_root(ctx), "staging", study_name)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(dir, winslash = "/", mustWork = FALSE)
}

#' @keywords internal
staging_dir_is_writable <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    return(FALSE)
  }
  probe <- file.path(path, ".write_test")
  ok <- tryCatch(
    {
      writeLines("ok", probe)
      unlink(probe)
      TRUE
    },
    error = function(e) FALSE
  )
  isTRUE(ok)
}

#' Directory for ephemeral Stata runner scripts and batch logs
#'
#' Runners and Stata batch logs live under the R session temp directory so study
#' repos are not littered with \code{artifacts/staging/.run} and paths with
#' spaces do not break the Stata command line.
#'
#' @param workdir Study repository root.
#' @param staging_dir Writable staging directory for replication output.
#' @keywords internal
stata_run_dir <- function(workdir, staging_dir = NULL) {
  base <- file.path(tempdir(), "replicateEverything-stata")
  dir.create(base, recursive = TRUE, showWarnings = FALSE)
  run_parent <- tempfile(pattern = "run", tmpdir = base)
  if (!dir.create(run_parent, showWarnings = FALSE) || !dir.exists(run_parent)) {
    stop("Could not create Stata run directory: ", run_parent, call. = FALSE)
  }
  run_dir <- file.path(run_parent, ".run")
  if (!dir.create(run_dir, recursive = TRUE, showWarnings = FALSE) || !dir.exists(run_dir)) {
    stop("Could not create Stata run directory: ", run_dir, call. = FALSE)
  }
  run_dir
}

#' @keywords internal
cleanup_stata_run_dir <- function(run_dir) {
  if (is.null(run_dir) || !nzchar(run_dir)) {
    return(invisible(FALSE))
  }
  run_parent <- dirname(run_dir)
  staging_root <- dirname(run_parent)
  if (
    dir.exists(run_parent) &&
    grepl("replicateEverything-stata", staging_root, fixed = TRUE)
  ) {
    unlink(run_parent, recursive = TRUE)
  }
  invisible(TRUE)
}

#' Resolve Stata output path after a run
#'
#' @param rep Replication entry.
#' @param study_root Study repository root.
#' @param staging_dir Optional writable staging directory.
#' @keywords internal
resolve_stata_output_after_run <- function(rep, study_root, staging_dir = NULL) {
  primary <- stata_output_path(rep, study_root)
  if (file.exists(primary)) {
    return(normalizePath(primary, winslash = "/", mustWork = FALSE))
  }
  if (!is.null(staging_dir) && nzchar(staging_dir)) {
    candidate <- file.path(staging_dir, basename(primary))
    if (file.exists(candidate)) {
      return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    }
  }
  primary
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
  staging_dir <- writable_stata_staging_dir(meta, ctx, study_root = study_root)

  if (!is.null(rep$data)) {
    ensure_study_data_files(rep$data, study_root, meta, ctx)
  }

  stata_run <- run_stata_do(code_path, study_root, staging_dir = staging_dir)

  output_path <- resolve_stata_output_after_run(rep, study_root, staging_dir = staging_dir)
  if (!file.exists(output_path)) {
    stop(
      stata_output_missing_message(output_path, study_root, stata_run, staging_dir = staging_dir),
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
