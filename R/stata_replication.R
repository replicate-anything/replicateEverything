#' Replication engine for a single entry
#'
#' @param rep Replication entry from \code{replication.yml}.
#' @param paper_meta Optional paper-level metadata.
#' @return \code{"r"}, \code{"stata"}, or \code{"python"}.
#' @keywords internal
replication_engine <- function(rep, paper_meta = NULL) {
  eng <- rep$engine %||% NULL
  if (!is.null(eng) && length(eng) > 0L) {
    value <- tolower(as.character(eng[[1]]))
    if (value %in% c("stata", "r", "python", "py")) {
      if (value %in% c("py")) return("python")
      return(value)
    }
  }

  if (!is.null(paper_meta)) {
    lang <- paper_meta$language %||% NULL
    if (!is.null(lang) && length(lang) > 0L) {
      value <- tolower(as.character(lang[[1]]))
      if (value %in% c("stata", "r", "python", "py")) {
        if (value %in% c("py")) return("python")
        return(value)
      }
    }
  }

  code <- as.character(rep$code %||% "")
  if (length(code) == 1L) {
    if (grepl("\\.do$", code, ignore.case = TRUE)) {
      return("stata")
    }
    if (grepl("\\.(py|ipynb)$", code, ignore.case = TRUE)) {
      return("python")
    }
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
#' Checks \code{STATA} / \code{REPLICATE_STATA_EXECUTABLE} environment variables
#' (set in \code{~/.Renviron}), then
#' \code{getOption("replicateEverything.stata_executable")}, then
#' common install paths (Windows, Linux, macOS) and \code{PATH}.
#'
#' @return Normalized path or \code{NULL}.
#' @keywords internal
find_stata_executable <- function() {
  for (env_var in c("STATA", "REPLICATE_STATA_EXECUTABLE", "STATA_EXECUTABLE")) {
    env <- Sys.getenv(env_var, unset = "")
    if (nzchar(env) && file.exists(env)) {
      return(normalizePath(env, winslash = "/", mustWork = FALSE))
    }
  }

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

#' Run Stata in batch mode with an optional timeout
#'
#' Uses \pkg{processx} when available so overdue runs can be killed and the R
#' session (e.g. Shiny) can continue. Without \pkg{processx}, runs block with no
#' timeout (legacy behaviour).
#'
#' @param stata Path to Stata executable.
#' @param batch_args Character vector of batch arguments.
#' @param timeout Seconds; \code{0} or negative means no limit.
#' @return Integer exit status (0 = success).
#' @keywords internal
run_stata_system2 <- function(stata, batch_args, timeout = 900L) {
  timeout <- as.integer(timeout[1])
  if (length(timeout) != 1L || is.na(timeout) || timeout <= 0L) {
    return(system2(stata, batch_args, wait = TRUE, stdout = "", stderr = ""))
  }
  if (requireNamespace("processx", quietly = TRUE)) {
    proc <- processx::process$new(
      stata,
      batch_args,
      stdout = "|",
      stderr = "|"
    )
    proc$wait(timeout = timeout * 1000)
    if (proc$is_alive()) {
      proc$kill()
      stop(
        "Stata did not finish within ", timeout,
        " seconds. The run was stopped so your session can continue. ",
        "Increase options(replicateEverything.stata_timeout = <seconds>) or ",
        "options(replicateEverything.stata_deps_probe_timeout = <seconds>).",
        call. = FALSE
      )
    }
    status <- proc$get_exit_status()
    return(if (is.null(status)) 1L else as.integer(status))
  }
  system2(stata, batch_args, wait = TRUE, stdout = "", stderr = "")
}

#' Run a Stata do-file non-interactively
#'
#' @param do_path Path to the do-file.
#' @param workdir Working directory Stata should use.
#' @param timeout Seconds before aborting (best effort on Windows).
#' @param staging_dir Optional writable directory for \code{$result} output.
#' @return A \code{stata_run_result} list with log path and diagnostics.
#' @keywords internal
run_stata_do <- function(do_path, workdir, timeout = 900L, staging_dir = NULL,
                         hint_context = NULL) {
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

  status <- run_stata_system2(
    stata,
    batch_args,
    timeout = getOption("replicateEverything.stata_timeout", timeout)
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
      stata_run_failed_message(result, hint_context = hint_context),
      call. = FALSE
    )
  }
  if (!identical(status, 0L) && !identical(status, 0)) {
    stop(
      stata_run_failed_message(result, hint_context = hint_context),
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
  strip_ansi_escapes(paste(lines[start:end], collapse = "\n"))
}

#' @keywords internal
stata_log_tail <- function(log_path, n = 40L) {
  if (!file.exists(log_path)) {
    return(NULL)
  }
  lines <- readLines(log_path, warn = FALSE, encoding = "UTF-8")
  if (length(lines) <= n) {
    return(strip_ansi_escapes(paste(lines, collapse = "\n")))
  }
  strip_ansi_escapes(paste(lines[(length(lines) - n + 1L):length(lines)], collapse = "\n"))
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

#' Path relative to a study root for user-facing messages
#' @keywords internal
stata_study_relative_path <- function(study_root, path) {
  if (is.null(path) || !nzchar(path)) {
    return(path)
  }
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  path <- normalizePath(path, winslash = "/", mustWork = FALSE)
  prefix <- paste0(study_root, "/")
  if (startsWith(path, prefix)) {
    return(sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", study_root), "/?"), "", path))
  }
  basename(path)
}

#' Study-specific Stata dependency guidance from replication.yml
#' @keywords internal
stata_study_dependency_guidance <- function(study_root, meta = NULL) {
  scripts <- stata_deps_install_scripts(study_root, meta = meta)
  probe <- stata_deps_probe_scripts(study_root, meta = meta)
  pkgs <- stata_deps_package_names(meta)
  lines <- character(0)
  if (length(scripts)) {
    rel <- vapply(scripts, function(p) {
      stata_study_relative_path(study_root, p)
    }, character(1))
    lines <- c(
      lines,
      paste0("  Run study install script(s): ", paste(rel, collapse = ", "))
    )
    lines <- c(
      lines,
      "  Maintainer: install_study_dependencies(<doi>) or run the install script once on this machine."
    )
  } else if (length(pkgs)) {
    lines <- c(
      lines,
      paste0("  Declared stata_packages: ", paste(pkgs, collapse = ", ")),
      "  Maintainer: install_study_dependencies(<doi>) installs SSC packages from this list."
    )
  }
  if (length(probe)) {
    rel <- vapply(probe, function(p) {
      stata_study_relative_path(study_root, p)
    }, character(1))
    lines <- c(lines, paste0("  Custom dependency probe: ", paste(rel, collapse = ", ")))
  } else if (length(pkgs)) {
    lines <- c(
      lines,
      "  Probe: auto-generated from stata_packages (which + help; reghdfe stack checks when listed)."
    )
  }
  if (length(lines) == 0L) {
    lines <- c(
      "  Add stata_packages: [reghdfe, estout, ...] to replication.yml",
      "  (see inst/ai/skills/folder_replication.md). Custom .do scripts are optional."
    )
  }
  paste0(
    "Study Stata dependencies (replication.yml):\n",
    paste(lines, collapse = "\n"),
    "\n"
  )
}

#' @keywords internal
stata_dependency_hint <- function(text, study_root = NULL, meta = NULL) {
  if (is.null(text) || !nzchar(text)) {
    return("")
  }
  if (!stata_log_suggests_missing_dependency(text)) {
    return("")
  }
  if (!is.null(study_root) && nzchar(study_root)) {
    return(stata_study_dependency_guidance(study_root, meta = meta))
  }
  paste0(
    "Missing Stata package suspected. Declare stata_dependencies / stata_deps_probe ",
    "in the study replication.yml (see inst/ai/skills/folder_replication.md).\n"
  )
}

#' Whether a Stata log suggests a missing user-written package
#' @keywords internal
stata_log_suggests_missing_dependency <- function(log_text) {
  if (is.null(log_text) || !nzchar(log_text)) {
    return(FALSE)
  }
  grepl(
    "install from SSC|install from GitHub|install it:|require package|unrecognized command|command .* not found",
    log_text,
    ignore.case = TRUE
  ) ||
    grepl("r\\(9\\);", log_text) ||
    grepl("r\\(199\\);", log_text) ||
    grepl("r\\(111\\);", log_text)
}

#' Resolve Stata dependency install scripts for a study
#'
#' Looks for \code{code/helpers/install_stata_deps.do} and optional
#' \code{stata_dependencies} entries in replication metadata.
#'
#' @param study_root Local study repository root.
#' @param meta Optional parsed replication metadata.
#' @param rep Optional replication entry.
#' @keywords internal
stata_deps_install_scripts <- function(study_root, meta = NULL, rep = NULL) {
  collect_yaml_scripts <- function(items) {
    if (is.null(items) || length(items) == 0L) {
      return(character(0))
    }
    vals <- unlist(items, use.names = FALSE)
    vals <- as.character(vals)
    vals <- vals[nzchar(vals)]
    paths <- lapply(vals, function(rel) {
      if (grepl("[/\\\\]", rel) || grepl("\\.do$", rel, ignore.case = TRUE)) {
        path <- file.path(study_root, rel)
        if (file.exists(path)) {
          return(normalizePath(path, winslash = "/", mustWork = FALSE))
        }
      }
      character(0)
    })
    unlist(paths, use.names = FALSE)
  }

  scripts <- character(0)
  if (!is.null(meta)) {
    scripts <- c(scripts, collect_yaml_scripts(meta$paper$stata_dependencies %||% NULL))
    scripts <- c(scripts, collect_yaml_scripts(meta$stata_dependencies %||% NULL))
  }
  if (!is.null(rep)) {
    scripts <- c(scripts, collect_yaml_scripts(rep$stata_dependencies %||% NULL))
  }
  scripts <- unique(scripts[nzchar(scripts)])
  if (length(scripts) > 0L) {
    return(scripts)
  }

  packages <- stata_deps_package_names(meta, study_root = study_root)
  if (length(packages) > 0L) {
    return(character(0))
  }

  default_script <- file.path(study_root, "code", "helpers", "install_stata_deps.do")
  if (file.exists(default_script)) {
    return(default_script)
  }
  character(0)
}

#' Resolve optional Stata dependency probe script paths from study metadata
#'
#' Studies may declare \code{stata_deps_probe: code/helpers/probe_stata_deps.do}
#' in \code{replication.yml}. The probe must exit 0 when dependencies are
#' satisfied and non-zero otherwise (check only — no network install).
#'
#' @inheritParams stata_deps_install_scripts
#' @return Character vector of absolute paths to probe \code{.do} files.
#' @keywords internal
stata_deps_probe_scripts <- function(study_root, meta = NULL) {
  if (!is.null(study_root) && nzchar(study_root) && dir.exists(study_root)) {
    meta <- complete_folder_study_meta(meta %||% list(), study_root)
  }
  collect <- function(items) {
    if (is.null(items) || length(items) == 0L) {
      return(character(0))
    }
    vals <- unlist(items, use.names = FALSE)
    vals <- as.character(vals)
    vals <- vals[nzchar(vals)]
    paths <- lapply(vals, function(rel) {
      if (grepl("[/\\\\]", rel) || grepl("\\.do$", rel, ignore.case = TRUE)) {
        path <- file.path(study_root, rel)
        if (file.exists(path)) {
          return(normalizePath(path, winslash = "/", mustWork = FALSE))
        }
      }
      character(0)
    })
    unlist(paths, use.names = FALSE)
  }

  scripts <- character(0)
  if (!is.null(meta)) {
    scripts <- c(scripts, collect(meta$stata_deps_probe %||% NULL))
    scripts <- c(scripts, collect(meta$paper$stata_deps_probe %||% NULL))
  }
  unique(scripts[nzchar(scripts)])
}

#' Stata SSC package names declared for a generic dependency probe
#'
#' Optional \code{stata_packages:} list in \code{replication.yml}. Used when no
#' \code{stata_deps_probe} script is declared; checks \code{which <pkg>} only.
#'
#' @param meta Parsed replication metadata.
#' @return Character vector of package names.
#' @keywords internal
stata_deps_package_names <- function(meta = NULL, study_root = NULL) {
  if (!is.null(study_root) && nzchar(study_root) && dir.exists(study_root)) {
    meta <- complete_folder_study_meta(meta %||% list(), study_root)
  }
  if (is.null(meta)) {
    return(character(0))
  }
  pkgs <- c(
    unlist(meta$stata_packages %||% list(), use.names = FALSE),
    unlist(meta$paper$stata_packages %||% list(), use.names = FALSE)
  )
  pkgs <- unique(na.omit(as.character(pkgs)))
  pkgs <- pkgs[nzchar(pkgs)]
  pkgs[!grepl("\\.do$", pkgs, ignore.case = TRUE)]
}

#' Stata ado command to probe for a declared package name
#'
#' \code{estout} installs \code{eststo} / \code{esttab}; probe the runnable command.
#'
#' @param pkg Declared package name from \code{stata_packages:}.
#' @keywords internal
stata_probe_command <- function(pkg) {
  if (identical(pkg, "estout")) {
    return("eststo")
  }
  pkg
}

#' Stata install lines for the SSC \code{ftools} + \code{reghdfe} stack
#'
#' Current SSC \code{reghdfe} (6.x) requires the \code{require} package. Refreshes
#' broken partial installs on shared servers.
#'
#' @keywords internal
stata_reghdfe_stack_install_lines <- function() {
  c(
    "* SSC ftools + reghdfe 6.x (+ require)",
    "local refresh 0",
    "cap which reghdfe",
    "if !_rc {",
    "    cap which require",
    "    if _rc local refresh 1",
    "    if !`refresh' {",
    "        cap noi reghdfe",
    "        if _rc == 9 local refresh 1",
    "        if !`refresh' {",
    "            cap help reghdfe",
    "            if _rc local refresh 1",
    "        }",
    "    }",
    "}",
    "if `refresh' {",
    '    di as txt "Refreshing SSC ftools/reghdfe/require stack..."',
    "    cap ado uninstall reghdfe",
    "    cap ado uninstall ftools",
    "    cap ado uninstall require",
    "}",
    'di as txt "Installing ftools from SSC..."',
    "cap which ftools",
    "if _rc ssc install ftools, replace",
    "cap noisily ftools, compile",
    "cap mata: mata mlib index",
    'di as txt "Installing reghdfe from SSC..."',
    "cap which reghdfe",
    "if _rc ssc install reghdfe, replace",
    'di as txt "Installing require from SSC (reghdfe 6.x dependency)..."',
    "cap which require",
    "if _rc ssc install require, replace",
    "cap help reghdfe",
    "if _rc {",
    '    di as err "reghdfe failed to load after SSC install."',
    "    exit 498",
    "}"
  )
}

#' Build a Stata install script from \code{stata_packages:}
#'
#' @param packages Character vector of SSC ado names.
#' @return Character vector of Stata commands.
#' @keywords internal
stata_deps_install_lines_from_packages <- function(packages) {
  packages <- unique(as.character(packages[nzchar(packages)]))
  if (length(packages) == 0L) {
    return(character(0))
  }
  lines <- c(
    "* Auto-generated by replicateEverything from replication.yml stata_packages:",
    paste0("* ", paste(packages, collapse = ", ")),
    "version 17",
    "set more off, permanently",
    "cap set netmsg off"
  )
  needs_reghdfe <- "reghdfe" %in% packages
  if (needs_reghdfe) {
    lines <- c(lines, stata_reghdfe_stack_install_lines())
  }
  for (pkg in packages) {
    if (needs_reghdfe && pkg %in% c("ftools", "reghdfe", "require")) {
      next
    }
    cmd <- stata_probe_command(pkg)
    lines <- c(
      lines,
      sprintf("cap which %s", cmd),
      "if _rc {",
      sprintf('    di as txt "Installing %s from SSC..."', pkg),
      sprintf("    ssc install %s, replace", pkg),
      "}"
    )
  }
  if ("estout" %in% packages) {
    lines <- c(
      lines,
      "cap which eststo",
      "if _rc {",
      '    di as err "eststo not found after estout install."',
      "    exit 498",
      "}"
    )
  }
  lines
}

#' Build a Stata probe from \code{stata_packages:}
#'
#' Uses \code{which} plus \code{help} (and reghdfe runtime checks when needed).
#'
#' @param packages Character vector of ado command names.
#' @return Character vector of Stata commands.
#' @keywords internal
stata_deps_probe_lines_from_packages <- function(packages) {
  packages <- unique(as.character(packages[nzchar(packages)]))
  if (length(packages) == 0L) {
    return(character(0))
  }
  lines <- c(
    "* Auto-generated probe from replication.yml stata_packages:",
    "version 17",
    "set more off, permanently"
  )
  if ("ftools" %in% packages || "reghdfe" %in% packages) {
    lines <- c(
      lines,
      "cap which ftools",
      "if _rc exit 10"
    )
  }
  if ("reghdfe" %in% packages) {
    lines <- c(
      lines,
      "cap which reghdfe",
      "if _rc exit 11",
      "cap which require",
      "if _rc exit 16",
      "cap noi reghdfe",
      "if _rc == 9 exit 12",
      "if _rc != 0 & _rc != 301 exit 15",
      "cap help reghdfe",
      "if _rc exit 12"
    )
  }
  other <- packages[!packages %in% c("ftools", "reghdfe", "require")]
  for (i in seq_along(other)) {
    pkg <- other[[i]]
    cmd <- stata_probe_command(pkg)
    lines <- c(
      lines,
      sprintf("cap which %s", cmd),
      sprintf("if _rc exit %d", 20L + i)
    )
  }
  c(lines, "exit 0")
}

#' Resolve Stata install scripts or generated install from \code{stata_packages:}
#'
#' @inheritParams stata_deps_install_scripts
#' @param staging_dir Optional staging directory for generated runner files.
#' @return List with \code{scripts}, \code{generated}, and optional \code{run_dir}.
#' @keywords internal
stata_deps_install_targets <- function(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL
) {
  scripts <- stata_deps_install_scripts(study_root, meta = meta, rep = rep)
  if (length(scripts) > 0L) {
    return(list(
      scripts = scripts,
      generated = FALSE,
      run_dir = NULL,
      packages = character(0)
    ))
  }
  packages <- stata_deps_package_names(meta, study_root = study_root)
  if (length(packages) == 0L) {
    return(list(
      scripts = character(0),
      generated = FALSE,
      run_dir = NULL,
      packages = character(0)
    ))
  }
  workdir <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  run_dir <- stata_run_dir(workdir, staging_dir)
  runner <- file.path(run_dir, "replicate_stata_deps_install.do")
  writeLines(
    stata_deps_install_lines_from_packages(packages),
    runner,
    useBytes = TRUE
  )
  list(
    scripts = runner,
    generated = TRUE,
    run_dir = run_dir,
    packages = packages
  )
}

#' Label for progress messages describing the configured Stata dependency probe
#'
#' @inheritParams stata_deps_probe_scripts
#' @return Short character description.
#' @keywords internal
stata_deps_probe_label <- function(study_root, meta = NULL) {
  scripts <- stata_deps_probe_scripts(study_root, meta = meta)
  if (length(scripts) > 0L) {
    return(paste(basename(scripts), collapse = ", "))
  }
  pkgs <- stata_deps_package_names(meta)
  if (length(pkgs) > 0L) {
    return(paste(pkgs, collapse = ", "))
  }
  "not configured"
}

#' Whether required Stata SSC packages load without running install scripts
#'
#' Uses the study's \code{stata_deps_probe} script when declared; otherwise a
#' generic \code{which}-only probe from \code{stata_packages}. Returns
#' \code{NA} when neither is configured (caller should run install scripts or
#' skip per policy).
#'
#' @inheritParams run_stata_do
#' @param meta Parsed replication metadata.
#' @return \code{TRUE}, \code{FALSE}, or \code{NA} (no probe configured).
#' @keywords internal
stata_dependencies_satisfied <- function(
  study_root,
  staging_dir = NULL,
  timeout = 120L,
  meta = NULL
) {
  probe_scripts <- stata_deps_probe_scripts(study_root, meta = meta)
  packages <- stata_deps_package_names(meta)

  if (length(probe_scripts) == 0L && length(packages) == 0L) {
    return(NA)
  }

  stata <- find_stata_executable()
  if (is.null(stata)) {
    return(FALSE)
  }

  workdir <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  run_dir <- stata_run_dir(workdir, staging_dir)

  run_probe <- function(do_path) {
    old_wd <- getwd()
    on.exit(setwd(old_wd), add = TRUE)
    if (dir.exists(run_dir)) {
      setwd(run_dir)
    }
    status <- tryCatch(
      run_stata_system2(
        stata,
        stata_batch_args(do_path),
        timeout = timeout
      ),
      error = function(e) {
        if (grepl("did not finish within", conditionMessage(e), fixed = TRUE)) {
          stop(conditionMessage(e), call. = FALSE)
        }
        return(1L)
      }
    )
    identical(status, 0L) || identical(status, 0)
  }

  if (length(probe_scripts) > 0L) {
    results <- vapply(probe_scripts, function(script) {
      run_probe(script)
    }, logical(1))
    return(all(results))
  }

  runner <- file.path(run_dir, "replicate_stata_deps_probe.do")
  writeLines(stata_deps_probe_lines_from_packages(packages), runner, useBytes = TRUE)
  on.exit(cleanup_stata_run_dir(run_dir), add = TRUE)
  run_probe(runner)
}

#' Whether study Stata install scripts may run (maintainer / build only)
#'
#' Live Run and Shiny probe dependencies only. Set
#' \code{options(replicateEverything.install_stata_deps = TRUE)} to allow
#' \code{install_stata_deps.do} (e.g. \code{build_study_outputs(install_deps = TRUE)}).
#' @keywords internal
stata_install_scripts_enabled <- function() {
  isTRUE(getOption("replicateEverything.install_stata_deps", FALSE))
}

#' Verify Stata dependencies via study yaml probe (no install)
#'
#' @inheritParams install_stata_dependencies
#' @return Invisibly \code{TRUE} when satisfied.
#' @keywords internal
verify_stata_dependencies <- function(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL
) {
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  meta <- complete_folder_study_meta(meta, study_root)

  stata <- find_stata_executable()
  if (is.null(stata)) {
    stop(
      "Stata executable not found. Install Stata or set ",
      "options(replicateEverything.stata_executable = '/path/to/StataMP-64.exe').",
      call. = FALSE
    )
  }

  probe_label <- stata_deps_probe_label(study_root, meta = meta)
  pkgs <- stata_deps_package_names(meta, study_root = study_root)
  probe_scripts <- stata_deps_probe_scripts(study_root, meta = meta)

  if (length(probe_scripts) == 0L && length(pkgs) == 0L) {
    return(invisible(TRUE))
  }

  replicate_progress(paste0("Checking Stata dependencies (", probe_label, ")..."))
  satisfied <- tryCatch(
    stata_dependencies_satisfied(
      study_root,
      staging_dir = staging_dir,
      meta = meta,
      timeout = as.integer(
        getOption("replicateEverything.stata_deps_probe_timeout", 120L)[1]
      )
    ),
    error = function(e) {
      message(conditionMessage(e))
      FALSE
    }
  )

  if (isTRUE(satisfied)) {
    replicate_progress("Stata dependencies OK")
    return(invisible(TRUE))
  }

  scripts <- stata_deps_install_scripts(study_root, meta = meta, rep = rep)
  stop(
    "Stata dependencies are not satisfied on this machine.\n",
    "Probe: ", probe_label, "\n",
    if (length(pkgs)) {
      paste0("Declared stata_packages: ", paste(pkgs, collapse = ", "), "\n")
    } else {
      ""
    },
    if (length(scripts)) {
      paste0(
        "Maintainers: run install script(s) once (not on every replication): ",
        paste(basename(scripts), collapse = ", "),
        "\n"
      )
    } else {
      ""
    },
    "\n",
    maintainer_dependency_hint(),
    call. = FALSE
  )
}

#' Run Stata SSC / dependency install scripts for a study (maintainer builds only)
#'
#' @inheritParams run_stata_replication
#' @param install_deps When \code{FALSE}, returns immediately.
#' @keywords internal
install_stata_dependencies <- function(
  study_root,
  staging_dir = NULL,
  meta = NULL,
  rep = NULL,
  install_deps = FALSE,
  force = FALSE
) {
  if (!isTRUE(install_deps)) {
    return(invisible(FALSE))
  }

  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  meta <- complete_folder_study_meta(meta, study_root)

  # Live replication: probe only — never mutate the host Stata installation.
  if (!isTRUE(force) && !stata_install_scripts_enabled()) {
    return(verify_stata_dependencies(
      study_root,
      staging_dir = staging_dir,
      meta = meta,
      rep = rep
    ))
  }

  if (!stata_install_scripts_enabled()) {
    return(invisible(FALSE))
  }
  targets <- stata_deps_install_targets(
    study_root,
    staging_dir = staging_dir,
    meta = meta,
    rep = rep
  )
  scripts <- targets$scripts
  if (length(scripts) == 0L) {
    return(invisible(FALSE))
  }
  deps_key <- if (isTRUE(targets$generated) && length(targets$packages) > 0L) {
    paste0(
      normalizePath(study_root, winslash = "/", mustWork = FALSE),
      "::packages:",
      paste(sort(targets$packages), collapse = ",")
    )
  } else {
    paste0(
      normalizePath(study_root, winslash = "/", mustWork = FALSE),
      "::",
      paste(sort(basename(scripts)), collapse = ",")
    )
  }
  # A single live Run installs deps before the prep step and again before the
  # table; and re-running the study's install script is expensive (it may
  # recompile / reinstall SSC packages over the network every time). Once the
  # scripts have run successfully in this session, skip them unless forced
  # (e.g. a missing-dependency retry).
  if (!isTRUE(force) && stata_deps_installed_this_session(deps_key)) {
    return(invisible(FALSE))
  }

  if (!isTRUE(force)) {
    satisfied <- tryCatch(
      verify_stata_dependencies(
        study_root,
        staging_dir = staging_dir,
        meta = meta,
        rep = rep
      ),
      error = function(e) e
    )
    if (!inherits(satisfied, "error")) {
      deps_key <- paste0(
        normalizePath(study_root, winslash = "/", mustWork = FALSE),
        "::",
        paste(sort(basename(scripts)), collapse = ",")
      )
      mark_stata_deps_installed(deps_key)
      return(invisible(FALSE))
    }
    replicate_progress("Stata dependency probe failed — running maintainer install...")
    label <- if (isTRUE(targets$generated)) {
      paste0("stata_packages: ", paste(targets$packages, collapse = ", "))
    } else {
      paste(basename(scripts), collapse = ", ")
    }
    message(
      "Stata dependency probe did not pass — running maintainer install: ",
      label, " ..."
    )
  }

  install_timeout <- as.integer(
    getOption("replicateEverything.stata_deps_install_timeout", 600L)[1]
  )
  for (script in scripts) {
    replicate_progress(paste0("Installing Stata dependencies via ", basename(script), " ..."))
    message("Installing Stata dependencies via ", basename(script), " ...")
    run_stata_do(
      script,
      study_root,
      staging_dir = staging_dir,
      timeout = install_timeout,
      hint_context = list(study_root = study_root, meta = meta)
    )
  }
  mark_stata_deps_installed(deps_key)
  invisible(TRUE)
}

# Session-scoped record of study dependency scripts already run, so repeated
# replications of one study do not re-run the (potentially slow) install.
.stata_deps_installed <- new.env(parent = emptyenv())

#' Whether a study's Stata dependency scripts already ran this session
#'
#' @param deps_key Character key identifying the study + its install scripts.
#' @return Logical scalar.
#' @keywords internal
stata_deps_installed_this_session <- function(deps_key) {
  isTRUE(.stata_deps_installed[[deps_key]])
}

#' Record that a study's Stata dependency scripts ran successfully
#'
#' @param deps_key Character key identifying the study + its install scripts.
#' @return Invisibly \code{NULL}.
#' @keywords internal
mark_stata_deps_installed <- function(deps_key) {
  assign(deps_key, TRUE, envir = .stata_deps_installed)
  invisible(NULL)
}

stata_run_failed_message <- function(run, hint_context = NULL) {
  log_text <- paste(
    run$stata_error %||% "",
    run$log_tail %||% "",
    sep = "\n"
  )
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
    },
    stata_dependency_hint(
      log_text,
      study_root = hint_context$study_root %||% run$workdir %||% NULL,
      meta = hint_context$meta %||% NULL
    )
  )
}

#' @keywords internal
stata_output_missing_message <- function(output_path, study_root, run, staging_dir = NULL) {
  expected_name <- basename(output_path)
  staging_candidates <- character(0)
  if (!is.null(staging_dir) && nzchar(staging_dir)) {
    staging_candidates <- c(
      file.path(staging_dir, expected_name),
      file.path(study_root, "outputs", "staging", expected_name)
    )
  }
  legacy_candidates <- character(0)
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
    describe_directory(file.path(study_root, "outputs", "staging"), "Study staging"),
    if (!is.null(staging_dir) && nzchar(staging_dir)) {
      paste0("\n", describe_directory(staging_dir, "Writable staging"))
    } else {
      ""
    }
  )
}

#' Writable staging directory for Stata output
#'
#' Uses \code{<study>/outputs/staging} when the study folder is writable;
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
    candidate <- file.path(study_root, "outputs", "staging")
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
#' repos are not littered with \code{outputs/staging/.run} and paths with
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
  rels <- step_output_rel_candidates(rep)
  if (length(rels) == 0L) {
    rels <- paste0("outputs/staging/", rep$id, ".smcl")
  }
  for (rel in rels) {
    primary <- file.path(study_root, rel)
    if (file.exists(primary)) {
      return(normalizePath(primary, winslash = "/", mustWork = FALSE))
    }
    if (!is.null(staging_dir) && nzchar(staging_dir)) {
      candidate <- file.path(staging_dir, basename(rel))
      if (file.exists(candidate)) {
        return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
      }
    }
  }
  file.path(study_root, rels[[1]])
}

#' Extract the output file path from a Stata replication result
#'
#' Accepts a \code{stata_replication_result} list or a plain character path.
#'
#' @param object Stata result list or path to \code{.smcl}/image output.
#' @return Character path or \code{NULL}.
#' @keywords internal
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
  rels <- step_output_rel_candidates(rep)
  if (length(rels) == 0L) {
    rel <- rep$output %||% rep$stata_output %||% NULL
    if (!is.null(rel) && length(rel) > 0L && nzchar(as.character(rel[[1]]))) {
      return(file.path(study_root, as.character(rel[[1]])))
    }
    return(file.path(study_root, "outputs", "staging", paste0(rep$id, ".smcl")))
  }
  file.path(study_root, rels[[1]])
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
#' @param install_deps When \code{TRUE}, run study Stata dependency install scripts
#'   before the replication and retry once after package-missing failures.
#' @return A \code{stata_replication_result} list.
#' @keywords internal
run_stata_replication <- function(rep, ctx, meta = NULL, install_deps = FALSE) {
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
  meta <- complete_folder_study_meta(meta, study_root)
  ctx$local_root <- study_root
  code_path <- resolve_registry_file(rep$code, ctx, meta = meta)
  staging_dir <- writable_stata_staging_dir(meta, ctx, study_root = study_root)

  if (!is.null(rep$data)) {
    ensure_study_data_files(rep$data, study_root, meta, ctx)
  }

  install_stata_dependencies(
    study_root,
    staging_dir = staging_dir,
    meta = meta,
    rep = rep,
    install_deps = install_deps
  )

  hint_context <- list(study_root = study_root, meta = meta)
  run_replication_do <- function() {
    run_stata_do(
      code_path,
      study_root,
      staging_dir = staging_dir,
      hint_context = hint_context
    )
  }

  stata_run <- tryCatch(
    run_replication_do(),
    error = function(e) e
  )

  if (inherits(stata_run, "error") && isTRUE(install_deps) && stata_install_scripts_enabled()) {
    err_text <- conditionMessage(stata_run)
    if (stata_log_suggests_missing_dependency(err_text)) {
      message("Retrying after Stata dependency install ...")
      install_stata_dependencies(
        study_root,
        staging_dir = staging_dir,
        meta = meta,
        rep = rep,
        install_deps = TRUE,
        force = TRUE
      )
      stata_run <- tryCatch(
        run_replication_do(),
        error = function(e) e
      )
    }
  }

  if (inherits(stata_run, "error")) {
    stop(stata_run)
  }

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
#' @keywords internal
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
  eng <- replication_engine(rep, paper_meta)
  if (identical(eng, "stata")) {
    return("stata")
  }
  if (identical(eng, "python")) {
    return("python")
  }
  "r"
}

#' Code language for a replication (for Shiny syntax highlighting)
#'
#' @inheritParams render_replication
#' @return \code{"stata"} or \code{"r"}.
#' @keywords internal
replication_code_language_for <- function(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL
) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  rep <- find_replication_entry(meta, what, language = language)
  replication_code_language(rep, meta$paper)
}
