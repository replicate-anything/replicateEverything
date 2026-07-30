#' Replication engine for a single entry
#'
#' @param rep Replication entry from \code{replication.yml}.
#' @param paper_meta Optional paper-level metadata.
#' @return \code{"r"}, \code{"stata"}, \code{"python"}, \code{"dataverse"}, or
#'   \code{"mathematica"} (system-tool engines used for missing-tool /
#'   incomplete-step display, e.g. an alternate-engine \code{group:} member
#'   that is never dispatched by \code{run_replication()}).
#' @keywords internal
replication_engine <- function(rep, paper_meta = NULL) {
  eng <- rep$engine %||% NULL
  if (!is.null(eng) && length(eng) > 0L) {
    value <- tolower(as.character(eng[[1]]))
    if (value %in% c("stata", "r", "python", "py", "dataverse")) {
      if (value %in% c("py")) return("python")
      return(value)
    }
    if (value %in% c("mathematica", "wolfram", "wolframscript")) {
      return("mathematica")
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

#' Whether a replication entry is a surgical Dataverse access step
#' @keywords internal
is_dataverse_replication <- function(rep, paper_meta = NULL) {
  identical(replication_engine(rep, paper_meta), "dataverse")
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

#' Human-readable label for a resolved Stata executable path
#'
#' Derives a short "Stata &lt;version&gt; &lt;edition&gt;" label from the
#' install path (e.g. \code{.../Stata17/StataMP-64.exe} -> \code{"Stata 17
#' MP"}), so check/install messages make it obvious at a glance whether they
#' resolved the same Stata. The raw path (always reported alongside) is the
#' ground truth for programmatic comparison.
#'
#' @param path Absolute path to a Stata executable, or \code{NULL}.
#' @return Character scalar, e.g. \code{"Stata 17 MP (C:/.../StataMP-64.exe)"}
#'   or \code{"(Stata not found)"}.
#' @keywords internal
stata_executable_label <- function(path) {
  if (is.null(path) || !length(path) || is.na(path[[1]]) || !nzchar(path[[1]])) {
    return("(Stata not found)")
  }
  path <- as.character(path[[1]])
  base <- basename(path)
  ver_match <- regmatches(path, regexpr("[Ss]tata[A-Za-z]*([0-9]{2})", path))
  ver <- if (length(ver_match) && nzchar(ver_match)) gsub("[^0-9]", "", ver_match) else ""
  edition <- if (grepl("mp", base, ignore.case = TRUE)) {
    "MP"
  } else if (grepl("se", base, ignore.case = TRUE)) {
    "SE"
  } else if (grepl("ic", base, ignore.case = TRUE)) {
    "IC"
  } else {
    ""
  }
  label <- trimws(paste("Stata", ver, edition))
  paste0(label, " (", path, ")")
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
#' Windows: \code{/q do file.do}. Unix/Linux/macOS: \code{-b -q file.do}.
#'
#' On Windows we deliberately avoid \code{/e} and \code{/b}. Those flags put
#' Stata into batch mode, which \emph{silently ignores} \code{shell} /
#' \code{winexec} ("request ignored because of batch mode"). That breaks any
#' study that shells out (Hahn LBD \code{shell Rscript}, Wolfram, etc.).
#' StataCorp's recommended workaround is a normal \code{do} launch with
#' \code{exit, clear STATA} at the end of the generated runner (see
#' \code{stata_runner_lines()}). \code{/q} suppresses the logo. The GUI is
#' kept off the desktop via processx \code{windows_hide} (and a best-effort
#' \code{window manage minimize} in the runner). Paths with spaces are
#' shortened on Windows when possible.
#'
#' @param do_path Path to the do-file.
#' @return Character vector of arguments for \code{system2()}.
#' @keywords internal
stata_batch_args <- function(do_path) {
  path <- stata_shell_do_path(do_path)
  if (.Platform$OS.type == "windows") {
    return(c("/q", "do", path))
  }
  c("-b", "-q", path)
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

#' Locate Rscript for Stata child PATH / REPLICATE_RSCRIPT injection
#'
#' Stata batch (Windows System PATH; Linux Shiny service accounts) often cannot
#' see the same Rscript as the parent R session. Prefer \code{Sys.which}, then
#' \code{R.home("bin")}.
#'
#' @return Absolute path (possibly empty).
#' @keywords internal
find_rscript_for_stata <- function() {
  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript) && .Platform$OS.type == "windows") {
    rscript <- Sys.which("Rscript.exe")
  }
  if (!nzchar(rscript)) {
    cand <- file.path(
      R.home("bin"),
      if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
    )
    if (file.exists(cand)) {
      rscript <- cand
    }
  }
  if (!nzchar(rscript)) {
    return("")
  }
  normalizePath(rscript, winslash = "/", mustWork = FALSE)
}

#' PATH / env overrides so Stata \code{shell Rscript} sees the parent R
#'
#' Applies on Windows and Unix (Linux Shiny hosts included). Returns
#' \code{list(system2 = ..., processx = ...)} or both \code{NULL}.
#'
#' @keywords internal
stata_rscript_path_env <- function() {
  rscript <- find_rscript_for_stata()
  if (!nzchar(rscript)) {
    return(list(system2 = NULL, processx = NULL))
  }
  rbin <- dirname(normalizePath(
    rscript,
    winslash = if (.Platform$OS.type == "windows") "\\" else "/",
    mustWork = FALSE
  ))
  sep <- if (.Platform$OS.type == "windows") ";" else ":"
  path_val <- paste0(rbin, sep, Sys.getenv("PATH", unset = ""))
  list(
    system2 = paste0("PATH=", path_val),
    processx = c(PATH = path_val)
  )
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
  # Windows: always hide the process. Combined with /q (no /e batch mode) and
  # exit, clear STATA in the generated runner, this keeps the GUI off the
  # desktop. Clicking a visible Stata window can still inject Break / r(1).
  # Prepend Rscript's directory to PATH on all platforms: Stata often sees a
  # thinner PATH than the parent R session (Windows System PATH; Linux Shiny
  # service accounts), so bare `shell Rscript` / `which Rscript` fails even
  # when the parent R session can find Rscript (Hahn LBD cost-curve).
  path_env <- stata_rscript_path_env()
  stata_env <- path_env$system2
  stata_env_processx <- path_env$processx
  use_timeout <- length(timeout) == 1L && !is.na(timeout) && timeout > 0L
  if (.Platform$OS.type == "windows" && !use_timeout) {
    sys_args <- list(
      command = stata,
      args = batch_args,
      wait = TRUE,
      stdout = "",
      stderr = "",
      invisible = TRUE
    )
    if (!is.null(stata_env)) {
      sys_args$env <- stata_env
    }
    return(do.call(system2, sys_args))
  }
  if (!use_timeout) {
    sys_args <- list(
      command = stata,
      args = batch_args,
      wait = TRUE,
      stdout = "",
      stderr = ""
    )
    if (!is.null(stata_env)) {
      sys_args$env <- stata_env
    }
    return(do.call(system2, sys_args))
  }
  if (requireNamespace("processx", quietly = TRUE)) {
    # Discard stdio (Stata /e already writes a .log). Piping to "|" without a
    # reader can fill the OS pipe buffer and stall Stata mid-command.
    # windows_hide: hide the GUI window. Never fall back to a visible process
    # — a visible / flashing taskbar entry invites cancel → --Break-- / r(1).
    proc_args <- list(
      command = stata,
      args = batch_args,
      stdout = NULL,
      stderr = NULL
    )
    if (.Platform$OS.type == "windows") {
      proc_args$windows_hide <- TRUE
    }
    if (!is.null(stata_env_processx)) {
      # Merge onto full inherited env so only PATH is overridden.
      full_env <- Sys.getenv()
      full_env[["PATH"]] <- stata_env_processx[["PATH"]]
      proc_args$env <- full_env
    }
    proc <- tryCatch(
      do.call(processx::process$new, proc_args),
      error = function(e) e
    )
    if (inherits(proc, "error")) {
      if (.Platform$OS.type == "windows") {
        # Keep the run hidden even if processx cannot set windows_hide
        # (never spawn a visible processx child — that invites Break dialogs).
        sys_args <- list(
          command = stata,
          args = batch_args,
          wait = TRUE,
          stdout = "",
          stderr = "",
          invisible = TRUE
        )
        if (!is.null(stata_env)) {
          sys_args$env <- stata_env
        }
        return(as.integer(do.call(system2, sys_args)))
      }
      sys_args <- list(
        command = stata,
        args = batch_args,
        wait = TRUE,
        stdout = "",
        stderr = ""
      )
      if (!is.null(stata_env)) {
        sys_args$env <- stata_env
      }
      return(as.integer(do.call(system2, sys_args)))
    }
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
  # Fallback without processx: no kill-on-timeout, but still hide on Windows.
  if (.Platform$OS.type == "windows") {
    sys_args <- list(
      command = stata,
      args = batch_args,
      wait = TRUE,
      stdout = "",
      stderr = "",
      invisible = TRUE
    )
    if (!is.null(stata_env)) {
      sys_args$env <- stata_env
    }
    return(do.call(system2, sys_args))
  }
  sys_args <- list(
    command = stata,
    args = batch_args,
    wait = TRUE,
    stdout = "",
    stderr = ""
  )
  if (!is.null(stata_env)) {
    sys_args$env <- stata_env
  }
  do.call(system2, sys_args)
}

#' VBScript that runs a command via hidden cmd.exe (Windows Stata $S_SHELL)
#'
#' Stata for Windows opens a visible console on every \code{shell}/\code{!}.
#' Setting global \code{S_SHELL} to \code{wscript //nologo //B <this.vbs>}
#' routes those calls through a wait + window-style-0 cmd, so focus is not
#' stolen. The script accepts an optional leading \code{/c} (cmd-style).
#'
#' @keywords internal
stata_windows_hidden_shell_vbs_lines <- function() {
  c(
    "Option Explicit",
    "Dim sh, cmd, i, a",
    "Set sh = CreateObject(\"WScript.Shell\")",
    "cmd = \"\"",
    "For i = 0 To WScript.Arguments.Count - 1",
    "  a = WScript.Arguments(i)",
    "  If Not (i = 0 And (a = \"/c\" Or a = \"/C\")) Then",
    "    If InStr(a, \" \") > 0 Or InStr(a, \"\"\"\") > 0 Then",
    "      a = \"\"\"\" & Replace(a, \"\"\"\", \"\"\"\"\"\"\") & \"\"\"\"",
    "    End If",
    "    If Len(cmd) > 0 Then cmd = cmd & \" \"",
    "    cmd = cmd & a",
    "  End If",
    "Next",
    "If Len(cmd) = 0 Then WScript.Quit 0",
    "WScript.Quit sh.Run(\"cmd.exe /c \" & cmd, 0, True)"
  )
}

#' Build the do-file lines for the package's generated Stata batch runner
#'
#' Always wraps the actual step do-file in \code{capture noisily do ...}
#' (never a bare \code{do ...}). On Windows, an uncaught runtime error during
#' a batch run (\code{/e do ...}) - anywhere in the step's do-file or in any
#' do-file it calls, however deeply nested - otherwise pops a modal "<file>.do
#' has been interrupted. Would you like the batch job to continue?" dialog
#' that blocks headless/unattended runs indefinitely (confirmed on Stata
#' 10-19; happens with both \code{/e} and \code{/b} - \code{/e} only
#' suppresses the separate "job finished, click OK" dialog on success).
#' \code{capture} around the outermost \code{do} absorbs an uncaught error in
#' that do-file (and in nested \code{do}s that abort into it) so the batch
#' process is not left in an "interrupted" state. \code{noisily} keeps the
#' usual output and the \code{r(###);} line in the log so
#' \code{stata_log_error()} still detects the failure.
#'
#' The preamble also forces non-interactive preferences that author code
#' sometimes re-enables: \code{set more off} and \code{pause off}. The study
#' \code{do} is run under \code{nobreak} so a Break keypress cannot abort the
#' batch job with \code{r(1)}. We intentionally do \emph{not} set
#' \code{varabbrev off}: many deposited scripts rely on Stata's default
#' abbreviation matching. Studies may still wrap their own nested \code{do}
#' calls in \code{capture noisily} as defense in depth.
#'
#' @param do_in_do Do-file path already escaped/formatted for use inside a
#'   Stata do-file (see \code{stata_path_in_do()}).
#' @param wd_in_do Working directory, same formatting.
#' @param staging_dir Optional writable directory for \code{$result} output.
#' @param hidden_shell_vbs Optional Windows path to
#'   [stata_windows_hidden_shell_vbs_lines()] script for \code{$S_SHELL}.
#' @param rscript_path Optional absolute Rscript path for
#'   \code{$REPLICATE_RSCRIPT} (Hahn LBD and similar Stata to R shells).
#' @return Character vector of do-file lines.
#' @keywords internal
stata_runner_lines <- function(do_in_do, wd_in_do, staging_dir = NULL,
                               log_in_do = NULL, hidden_shell_vbs = NULL,
                               rscript_path = NULL) {
  runner_lines <- c(
    "version 17",
    "clear all",
    "* Non-interactive batch preamble (must survive author clear/set more on)",
    "set more off, permanently",
    "pause off",
    "set linesize 255",
    "cap set scrollbufsize 2000000",
    "cap set netmsg off"
  )
  # Windows non-/e launch: keep the GUI out of the way (processx also hides).
  # Route `shell` through a hidden-cmd VBScript via $S_SHELL so child
  # CMD/Rscript consoles do not flash and steal focus (Hahn LBD shells many
  # Rscript calls). Linux/macOS keep the default shell unchanged.
  if (.Platform$OS.type == "windows") {
    runner_lines <- c(runner_lines, "cap window manage minimize")
    if (!is.null(hidden_shell_vbs) && nzchar(hidden_shell_vbs)) {
      vbs_in_do <- stata_path_in_do(hidden_shell_vbs)
      runner_lines <- c(
        runner_lines,
        paste0(
          "global S_SHELL `\"wscript //nologo //B \"",
          vbs_in_do,
          "\"\"'"
        )
      )
    } else {
      runner_lines <- c(
        runner_lines,
        "global S_SHELL \"powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden\""
      )
    }
  }
  # Without Windows /e, Stata does not auto-write a batch .log; open one
  # explicitly when the caller supplies a path (same basename as the runner).
  if (!is.null(log_in_do) && nzchar(log_in_do)) {
    runner_lines <- c(
      runner_lines,
      sprintf("cap log close _all"),
      sprintf("log using \"%s\", replace text", log_in_do)
    )
  }
  runner_lines <- c(
    runner_lines,
    sprintf("local root \"%s\"", wd_in_do),
    "cd \"`root'\""
  )
  if (!is.null(rscript_path) && nzchar(rscript_path)) {
    rscript_in_do <- stata_path_in_do(rscript_path)
    runner_lines <- c(
      runner_lines,
      sprintf("global REPLICATE_RSCRIPT \"%s\"", rscript_in_do)
    )
  }
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
  runner_lines <- c(
    runner_lines,
    "* Re-assert before the study script in case a prior step left more on",
    "set more off, permanently",
    "pause off",
    # nobreak: ignore Break during the nested do so a stray focus/click does
    # not surface r(1) / continue dialogs. Preserve the nested do's return
    # code and re-raise it: otherwise Windows `exit, clear STATA` below would
    # report process exit 0 even when the step failed (silent missing sinks).
    sprintf("capture noisily nobreak do \"%s\"", do_in_do),
    "local REPLICATE_STEP_RC = _rc",
    "if `REPLICATE_STEP_RC' != 0 {",
    "    display as error \"replicateEverything: step do-file ended with error r(\" `REPLICATE_STEP_RC' \");  see log above for the failing command.\"",
    "}"
  )
  # Windows: must exit explicitly because we do not use /e (needed so shell
  # works). clear STATA skips save prompts. Re-raise the nested do's return
  # code so processx / system2 see a non-zero status when the step failed.
  if (.Platform$OS.type == "windows") {
    runner_lines <- c(
      runner_lines,
      "cap log close _all",
      "exit `REPLICATE_STEP_RC', clear STATA"
    )
  } else {
    runner_lines <- c(
      runner_lines,
      "cap log close _all",
      "exit `REPLICATE_STEP_RC'"
    )
  }
  runner_lines
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

  log_name <- stata_batch_log_name(runner)
  log_path <- file.path(run_dir, log_name)
  # On Windows (no /e auto-log), the runner opens this path via log using.
  log_in_do <- if (.Platform$OS.type == "windows") {
    stata_path_in_do(normalizePath(log_path, winslash = "/", mustWork = FALSE))
  } else {
    NULL
  }
  hidden_shell_vbs <- NULL
  if (.Platform$OS.type == "windows") {
    hidden_shell_vbs <- file.path(run_dir, "re_hidden_shell.vbs")
    writeLines(
      stata_windows_hidden_shell_vbs_lines(),
      hidden_shell_vbs,
      useBytes = TRUE
    )
  }
  rscript_path <- find_rscript_for_stata()
  runner_lines <- stata_runner_lines(
    do_in_do,
    wd_in_do,
    staging_dir = staging_dir,
    log_in_do = log_in_do,
    hidden_shell_vbs = hidden_shell_vbs,
    rscript_path = if (nzchar(rscript_path)) rscript_path else NULL
  )

  writeLines(runner_lines, runner, useBytes = TRUE)
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

  # Windows/NTFS can report a stale (smaller) file size for a brief window
  # right after the tracked Stata child process exits - observed concretely
  # when a nested do-file (e.g. wrapper/metafile.do) opens its own named
  # `log using ...' that Stata's own /e batch log stream does not resume
  # from until end-of-session flush: readLines() immediately after
  # run_stata_system2() returns can see only a few KB of a multi-MB log,
  # silently truncating stata_log_error()/stata_log_tail() output and
  # producing a misleading "Stata error" excerpt from stale/incomplete
  # content instead of the real (later) failure. Wait for the log file's
  # size to stop growing before reading it.
  wait_for_stata_log_flush(log_path)

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

#' Wait for a just-written Stata batch log to stop growing on disk
#'
#' Polls the file size a few times with a short pause. If the Stata child
#' process has fully exited (which \code{run_stata_system2()} already
#' waited for), a stable size for 2 consecutive checks means the OS has
#' finished flushing writes and it is safe to \code{readLines()}.
#' @keywords internal
wait_for_stata_log_flush <- function(log_path, max_checks = 10L, interval = 0.3) {
  if (!file.exists(log_path)) {
    return(invisible(FALSE))
  }
  prev_size <- -1
  for (i in seq_len(max_checks)) {
    size <- suppressWarnings(file.info(log_path)$size)
    if (!is.na(size) && identical(size, prev_size)) {
      return(invisible(TRUE))
    }
    prev_size <- size
    Sys.sleep(interval)
  }
  invisible(FALSE)
}

#' Wait briefly for a declared Stata output file to appear or refresh
#'
#' Some Windows / Dropbox-backed outputs (notably workbook files) can land a
#' fraction of a second after the Stata process exits cleanly. Poll the
#' declared output path for a short period before treating the run as a hard
#' failure.
#' @keywords internal
wait_for_stata_output_flush <- function(path, before_tokens = NULL,
                                        max_checks = 10L, interval = 0.3) {
  if (is.null(path) || !length(path) || !nzchar(path[[1L]])) {
    return(invisible(FALSE))
  }
  path <- as.character(path[[1L]])
  for (i in seq_len(max_checks)) {
    if (file.exists(path) && stata_output_is_fresh(path, before_tokens)) {
      return(invisible(TRUE))
    }
    Sys.sleep(interval)
  }
  invisible(file.exists(path) && stata_output_is_fresh(path, before_tokens))
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

#' Relay per-package \code{REPLICATE_DEP_STATUS:} lines from an install log
#'
#' [stata_deps_install_lines_from_packages()] prints one
#' \code{REPLICATE_DEP_STATUS: ...} line per declared package (already
#' present / installed) so the install can report success/failure without
#' the caller having to open the Stata batch log by hand.
#'
#' @param log_path Path to a Stata batch log written by the install runner.
#' @return Character vector of status lines (without the marker prefix), or
#'   \code{character(0)} when the log has none (e.g. custom install script).
#' @keywords internal
stata_install_status_lines <- function(log_path) {
  if (is.null(log_path) || !nzchar(log_path) || !file.exists(log_path)) {
    return(character(0))
  }
  lines <- tryCatch(
    readLines(log_path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) character(0)
  )
  hits <- grep("^REPLICATE_DEP_STATUS: ", lines, value = TRUE)
  trimws(sub("^REPLICATE_DEP_STATUS: ", "", hits))
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
      "  Maintainer: install_dependencies(<doi>) or run the install script once on this machine."
    )
  } else if (length(pkgs)) {
    lines <- c(
      lines,
      paste0("  Declared stata_packages: ", paste(pkgs, collapse = ", ")),
      "  Maintainer: install_dependencies(<doi>) installs SSC packages from this list."
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
  # SSC labutil ships labmask/labcombine/…, not a labutil.ado
  if (identical(pkg, "labutil")) {
    return("labmask")
  }
  pkg
}

#' Presence-probe spec for a declared SSC package name
#'
#' Most SSC packages install a runnable ado command that \code{which} can
#' probe directly. A few ship no command at all - notably \code{moremata},
#' which is a pure Mata function library (\code{lmoremata.mlib} + help
#' files, no \code{moremata.ado}). \code{which moremata} therefore always
#' returns "command not found" (\code{r(111)}) even when the package is
#' correctly installed via \code{ssc install moremata}, which is exactly
#' what makes the auto-generated dependency probe report a false
#' "missing" for otherwise-installed packages. For those, probe the
#' installed library/help file directly with \code{findfile} instead.
#'
#' @param pkg Declared package name from \code{stata_packages:}.
#' @return List with \code{kind} (\code{"command"} or \code{"file"}) and
#'   \code{target} (command name, or filename to \code{findfile}).
#' @keywords internal
stata_package_probe_spec <- function(pkg) {
  # Packages that ship no runnable ado command of their own name - probe an
  # installed file instead (checked via `findfile`, which searches the
  # resolved Stata's ado path exactly like `which` does for commands).
  file_probes <- c(
    moremata = "lmoremata.mlib"
  )
  if (pkg %in% names(file_probes)) {
    return(list(kind = "file", target = unname(file_probes[[pkg]])))
  }
  list(kind = "command", target = stata_probe_command(pkg))
}

#' Stata do-file line(s) that test presence of a declared package
#'
#' @inheritParams stata_package_probe_spec
#' @return Character scalar: a single \code{cap which ...} or
#'   \code{cap findfile ...} line.
#' @keywords internal
stata_package_probe_line <- function(pkg) {
  spec <- stata_package_probe_spec(pkg)
  if (identical(spec$kind, "file")) {
    return(sprintf("cap findfile %s", spec$target))
  }
  sprintf("cap which %s", spec$target)
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
    # `cap ... ssc install` throughout (not bare): a network hiccup or SSC
    # outage must not leave Stata "interrupted" - see stata_runner_lines().
    "if _rc cap noisily ssc install ftools, replace",
    "cap noisily ftools, compile",
    "cap mata: mata mlib index",
    'di as txt "Installing reghdfe from SSC..."',
    "cap which reghdfe",
    "if _rc cap noisily ssc install reghdfe, replace",
    'di as txt "Installing require from SSC (reghdfe 6.x dependency)..."',
    "cap which require",
    "if _rc cap noisily ssc install require, replace",
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
    lines <- c(
      lines,
      stata_package_probe_line(pkg),
      "if _rc {",
      sprintf('    di as txt "REPLICATE_DEP_STATUS: installing %s from SSC..."', pkg),
      # `capture noisily` (not bare `ssc install`): a network hiccup or SSC
      # outage here must not leave Stata "interrupted" and popping the
      # Windows batch-continue dialog - see stata_runner_lines() above for
      # the full explanation. Still visible/logged via `noisily`.
      sprintf("    capture noisily ssc install %s, replace", pkg),
      sprintf('    di as txt "REPLICATE_DEP_STATUS: installed %s from SSC"', pkg),
      "}",
      "else {",
      sprintf('    di as txt "REPLICATE_DEP_STATUS: %s already present"', pkg),
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

#' Build a Stata probe from \code{stata_packages:}, with exit-code attribution
#'
#' Uses \code{which} (or \code{findfile} for file-only packages; see
#' [stata_package_probe_spec()]) plus \code{help} (and reghdfe runtime checks
#' when needed). Each check exits with a distinct code so a failing probe run
#' can be attributed back to the exact package that failed, instead of
#' blaming every declared package (see [stata_dependencies_satisfied()]).
#'
#' @param packages Character vector of ado command names.
#' @return List with \code{lines} (character vector of Stata commands) and
#'   \code{code_map} (named character vector: exit code as name, package
#'   name as value).
#' @keywords internal
stata_deps_probe_plan_from_packages <- function(packages) {
  packages <- unique(as.character(packages[nzchar(packages)]))
  code_map <- character(0)
  if (length(packages) == 0L) {
    return(list(lines = character(0), code_map = code_map))
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
    code_map[["10"]] <- "ftools"
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
    code_map[["11"]] <- "reghdfe"
    code_map[["16"]] <- "require"
    code_map[["12"]] <- "reghdfe"
    code_map[["15"]] <- "reghdfe"
  }
  other <- packages[!packages %in% c("ftools", "reghdfe", "require")]
  for (i in seq_along(other)) {
    pkg <- other[[i]]
    code <- 20L + i
    lines <- c(
      lines,
      stata_package_probe_line(pkg),
      sprintf("if _rc exit %d", code)
    )
    code_map[[as.character(code)]] <- pkg
  }
  list(lines = c(lines, "exit 0"), code_map = code_map)
}

#' Build a Stata probe from \code{stata_packages:}
#'
#' @inheritParams stata_deps_probe_plan_from_packages
#' @return Character vector of Stata commands.
#' @keywords internal
stata_deps_probe_lines_from_packages <- function(packages) {
  stata_deps_probe_plan_from_packages(packages)$lines
}

#' Exit-code -> package name map for [stata_deps_probe_lines_from_packages()]
#' @inheritParams stata_deps_probe_plan_from_packages
#' @return Named character vector (exit code as name, package as value).
#' @keywords internal
stata_deps_probe_code_map <- function(packages) {
  stata_deps_probe_plan_from_packages(packages)$code_map
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

#' Exit code that made a generated Stata probe fail, if attributable
#'
#' \code{stata_runner_lines()} always prints
#' \code{"...ended with error r(<code>);..."} when the wrapped do-file
#' aborts, and Stata itself echoes a bare \code{r(<code>);} line for the
#' underlying \code{exit <code>}. Either is enough to recover the first
#' failing exit code from the run's error text.
#'
#' @param text Character scalar (e.g. \code{conditionMessage()} of the error
#'   thrown by \code{run_stata_do()}, which includes the Stata error/log
#'   tail).
#' @return Character scalar exit code, or \code{NA_character_} if none found.
#' @keywords internal
stata_probe_failure_code <- function(text) {
  if (is.null(text) || !length(text) || !nzchar(text[[1]])) {
    return(NA_character_)
  }
  m <- regmatches(text, regexpr("r\\(([0-9]+)\\)", text))
  if (!length(m) || !nzchar(m)) {
    return(NA_character_)
  }
  gsub("[^0-9]", "", m)
}

#' Whether required Stata SSC packages load without running install scripts
#'
#' Uses the study's \code{stata_deps_probe} script when declared; otherwise a
#' generic \code{which}-only probe from \code{stata_packages}. Returns
#' \code{NA} when neither is configured (caller should run install scripts or
#' skip per policy).
#'
#' The returned logical carries diagnostic attributes so callers can report
#' precisely *which* Stata was used and *which* package(s) actually failed,
#' instead of blaming every declared package for one broken probe (the
#' \code{moremata} bug): \code{stata_executable} (path), \code{stata_label}
#' (human-readable), and \code{missing} (character vector - the specific
#' package attributed to the failure when derivable, else all declared
#' packages as a conservative fallback).
#'
#' @inheritParams run_stata_do
#' @param meta Parsed replication metadata.
#' @return \code{TRUE}, \code{FALSE}, or \code{NA} (no probe configured), with
#'   \code{stata_executable} / \code{stata_label} / \code{missing} attributes.
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
  stata_label <- stata_executable_label(stata)
  with_diag <- function(x, missing = character(0)) {
    attr(x, "stata_executable") <- stata
    attr(x, "stata_label") <- stata_label
    attr(x, "missing") <- missing
    x
  }

  if (is.null(stata)) {
    return(with_diag(
      FALSE,
      missing = if (length(packages)) packages else "Stata executable"
    ))
  }

  workdir <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  run_dir <- stata_run_dir(workdir, staging_dir)

  run_probe <- function(do_path) {
    # Must go through run_stata_do on Windows: without /e, a bare
    # `Stata /q do probe.do` leaves the GUI running after `exit 0` (do-file
    # exit only), so the probe hangs until stata_deps_probe_timeout and
    # every package looks "missing".
    tryCatch(
      run_stata_do(
        do_path,
        workdir = workdir,
        timeout = timeout,
        staging_dir = staging_dir
      ),
      error = function(e) {
        if (grepl("did not finish within", conditionMessage(e), fixed = TRUE)) {
          stop(conditionMessage(e), call. = FALSE)
        }
        e
      }
    )
  }

  if (length(probe_scripts) > 0L) {
    results <- lapply(probe_scripts, run_probe)
    ok <- all(vapply(results, function(r) !inherits(r, "error"), logical(1)))
    # Custom stata_deps_probe scripts are free-form user do-files; we cannot
    # attribute a failure to one specific package, so fall back to a generic
    # "probe failed" marker rather than guessing.
    return(with_diag(ok, missing = if (ok) character(0) else "Stata packages (probe failed)"))
  }

  runner <- file.path(run_dir, "replicate_stata_deps_probe.do")
  plan <- stata_deps_probe_plan_from_packages(packages)
  writeLines(plan$lines, runner, useBytes = TRUE)
  on.exit(cleanup_stata_run_dir(run_dir), add = TRUE)
  res <- run_probe(runner)
  if (!inherits(res, "error")) {
    return(with_diag(TRUE, missing = character(0)))
  }

  code <- stata_probe_failure_code(conditionMessage(res))
  attributed <- if (!is.na(code) && code %in% names(plan$code_map)) {
    unname(plan$code_map[[code]])
  } else {
    NA_character_
  }
  # A generated probe short-circuits (`exit`) at the first failing package,
  # so only that one is *known* to be missing; report just it when
  # attributable instead of blaming every declared package.
  with_diag(FALSE, missing = if (!is.na(attributed)) attributed else packages)
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
  stata_label <- stata_executable_label(stata)

  probe_label <- stata_deps_probe_label(study_root, meta = meta)
  pkgs <- stata_deps_package_names(meta, study_root = study_root)
  probe_scripts <- stata_deps_probe_scripts(study_root, meta = meta)

  if (length(probe_scripts) == 0L && length(pkgs) == 0L) {
    return(invisible(TRUE))
  }

  # Always report which Stata this check is talking to, so a check vs.
  # install mismatch (e.g. two Stata versions installed) is visible rather
  # than assumed.
  message("Checking Stata dependencies using: ", stata_label)
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
    message("Stata dependencies OK (", stata_label, ")")
    return(invisible(TRUE))
  }

  attributed_missing <- attr(satisfied, "missing", exact = TRUE)
  scripts <- stata_deps_install_scripts(study_root, meta = meta, rep = rep)
  stop(
    "Stata dependencies are not satisfied on this machine.\n",
    "Stata: ", stata_label, "\n",
    "Probe: ", probe_label, "\n",
    if (length(pkgs)) {
      paste0("Declared stata_packages: ", paste(pkgs, collapse = ", "), "\n")
    } else {
      ""
    },
    if (length(attributed_missing)) {
      paste0("Missing (probe-attributed): ", paste(attributed_missing, collapse = ", "), "\n")
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
  stata_label <- stata_executable_label(find_stata_executable())
  message("Installing Stata dependencies using: ", stata_label)
  for (script in scripts) {
    replicate_progress(paste0("Installing Stata dependencies via ", basename(script), " ..."))
    message("Installing Stata dependencies via ", basename(script), " ...")
    run_result <- run_stata_do(
      script,
      study_root,
      staging_dir = staging_dir,
      timeout = install_timeout,
      hint_context = list(study_root = study_root, meta = meta)
    )
    status_lines <- stata_install_status_lines(run_result$log_path %||% NULL)
    if (length(status_lines)) {
      message("  ", paste(status_lines, collapse = "\n  "))
    }
  }

  # Validate on the spot: re-run the same presence probe immediately after
  # install and report per-package pass/fail, so "install finished" cannot
  # silently lie when the probe (or install) is still broken for a package
  # (e.g. wrong presence check, network hiccup, ado reindex needed).
  post_check <- tryCatch(
    stata_dependencies_satisfied(
      study_root,
      staging_dir = staging_dir,
      meta = meta,
      timeout = as.integer(
        getOption("replicateEverything.stata_deps_probe_timeout", 120L)[1]
      )
    ),
    error = function(e) {
      message("Post-install validation could not run: ", conditionMessage(e))
      NA
    }
  )
  if (isTRUE(post_check)) {
    message(
      "Post-install validation OK (", stata_label, "): ",
      if (length(targets$packages)) {
        paste0("all declared packages found (", paste(targets$packages, collapse = ", "), ")")
      } else {
        "probe passed"
      }
    )
    mark_stata_deps_installed(deps_key)
    return(invisible(TRUE))
  }
  if (isFALSE(post_check)) {
    still_missing <- attr(post_check, "missing", exact = TRUE) %||% targets$packages
    warning(
      "Stata dependency install finished, but post-install validation still ",
      "reports missing package(s) using ", stata_label, ": ",
      paste(still_missing, collapse = ", "), ". ",
      "This usually means the install and the check are using different ",
      "Stata installs, the ado database needs a `mata: mata mlib index` / ",
      "Stata restart, or the presence probe for one of these packages is ",
      "wrong (e.g. a Mata-only library like moremata has no runnable ",
      "command of its own name).",
      call. = FALSE
    )
    # Do not mark as installed: a later replication attempt in this session
    # should retry rather than trust a "finished" that didn't actually work.
    return(invisible(FALSE))
  }
  # NA: no probe configured to validate against (e.g. custom install script
  # with no stata_packages: / stata_deps_probe: declared) - nothing to
  # contradict "finished", so keep prior behavior.
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
  if (isTRUE(getOption("replicateEverything.debug_keep_run_dir", FALSE))) {
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

#' Snapshot identity of declared Stata output candidates before a run
#'
#' Used so a successful-looking Stata exit cannot silently reuse a stale
#' pre-existing output when the do-file never rewrote it (e.g. an unclosed
#' \code{/*} block comment swallowed the script).
#'
#' @keywords internal
stata_output_mtime_snapshot <- function(rep, study_root, staging_dir = NULL) {
  rels <- step_output_rel_candidates(rep)
  if (length(rels) == 0L) {
    rels <- paste0("outputs/staging/", rep$id, ".smcl")
  }
  paths <- unique(c(
    file.path(study_root, rels),
    if (!is.null(staging_dir) && nzchar(staging_dir)) {
      file.path(staging_dir, basename(rels))
    } else {
      character(0)
    }
  ))
  tokens <- lapply(paths, stata_output_file_token)
  stats::setNames(tokens, paths)
}

#' @keywords internal
stata_output_file_token <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(NULL)
  }
  info <- file.info(path)
  list(
    mtime = as.numeric(info$mtime),
    size = as.numeric(info$size)
  )
}

#' @keywords internal
stata_output_snapshot_token <- function(path, before_tokens) {
  if (is.null(before_tokens) || !length(before_tokens)) {
    return(NULL)
  }
  path_key <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (path_key %in% names(before_tokens)) {
    return(before_tokens[[path_key]])
  }
  if (path %in% names(before_tokens)) {
    return(before_tokens[[path]])
  }
  for (nm in names(before_tokens)) {
    nm_norm <- tryCatch(
      normalizePath(nm, winslash = "/", mustWork = FALSE),
      error = function(e) nm
    )
    if (identical(nm_norm, path_key)) {
      return(before_tokens[[nm]])
    }
  }
  NULL
}

#' @keywords internal
stata_output_is_fresh <- function(path, before_tokens) {
  after <- stata_output_file_token(path)
  if (is.null(after)) {
    return(FALSE)
  }
  before <- stata_output_snapshot_token(path, before_tokens)
  if (is.null(before)) {
    return(TRUE)
  }
  !identical(before$mtime, after$mtime) || !identical(before$size, after$size)
}

#' Resolve Stata output path after a run
#'
#' @param rep Replication entry.
#' @param study_root Study repository root.
#' @param staging_dir Optional writable staging directory.
#' @param before_mtimes Optional snapshot from
#'   \code{stata_output_mtime_snapshot()}; when supplied, only files that are
#'   new or whose mtime/size changed count as the run's output.
#' @keywords internal
resolve_stata_output_after_run <- function(rep, study_root, staging_dir = NULL,
                                           before_mtimes = NULL) {
  rels <- step_output_rel_candidates(rep)
  if (length(rels) == 0L) {
    rels <- paste0("outputs/staging/", rep$id, ".smcl")
  }
  for (rel in rels) {
    primary <- file.path(study_root, rel)
    if (stata_output_is_fresh(primary, before_mtimes)) {
      return(normalizePath(primary, winslash = "/", mustWork = FALSE))
    }
    if (!is.null(staging_dir) && nzchar(staging_dir)) {
      candidate <- file.path(staging_dir, basename(rel))
      if (stata_output_is_fresh(candidate, before_mtimes)) {
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

  data_paths <- replication_data_paths(rep)
  if (length(data_paths)) {
    ensure_study_data_files(data_paths, study_root, meta, ctx)
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

  before_mtimes <- stata_output_mtime_snapshot(rep, study_root, staging_dir = staging_dir)

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
      before_mtimes <- stata_output_mtime_snapshot(rep, study_root, staging_dir = staging_dir)
      stata_run <- tryCatch(
        run_replication_do(),
        error = function(e) e
      )
    }
  }

  if (inherits(stata_run, "error")) {
    stop(stata_run)
  }

  output_path <- resolve_stata_output_after_run(
    rep,
    study_root,
    staging_dir = staging_dir,
    before_mtimes = before_mtimes
  )
  if (!file.exists(output_path) || !stata_output_is_fresh(output_path, before_mtimes)) {
    wait_for_stata_output_flush(output_path, before_tokens = before_mtimes)
  }
  if (!file.exists(output_path) || !stata_output_is_fresh(output_path, before_mtimes)) {
    stop(
      paste0(
        stata_output_missing_message(output_path, study_root, stata_run, staging_dir = staging_dir),
        if (file.exists(output_path)) {
          paste0(
            "\nNote: ", output_path,
            " exists but was not updated by this Stata run ",
            "(possible silent no-op, e.g. an unclosed /* block comment in the do-file)."
          )
        } else {
          ""
        }
      ),
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
