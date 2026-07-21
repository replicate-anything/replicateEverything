#' Retrieve replication code for a paper
#'
#' Returns a single script suitable for the Code tab in Shiny. For Stata
#' replications, the substantive analysis from \code{stata_source} is inlined
#' after a short setup section so the script can be copied and run. When
#' \code{stata_source} is omitted but the runner calls nested \code{do} files,
#' those paths are inferred automatically (setup helpers such as
#' \code{init_study_paths.do} are skipped). R replications return the analysis
#' script only; optional \code{format_*} helpers in separate files are labeled
#' and omitted for Stata.
#'
#' Scripts keep pure \code{make_*} / \code{format_*} definitions; the package
#' orchestrates load \eqn{\rightarrow}{->} make \eqn{\rightarrow}{->} format via
#' [run_replication()]. An optional footer guarded by
#' \code{if (sys.nframe() == 0L)} runs only when you Source the file in an IDE
#' (so loading definitions does not also execute). Use \code{mode = "run"} when
#' you want script text that also includes a final expression so
#' \code{eval(parse(text = ...))} can produce the object (set the working
#' directory to the study root).
#'
#' For package-backed studies, reads \code{inst/replication_code/*.R} from the
#' study package GitHub repo when the package is not installed (same idea as
#' reading \code{code/*.R} from the registry repo).
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (logical id).
#' @param language Optional \code{"R"} or \code{"stata"}.
#' @param style Display style: \code{"inline"} (default, inlines Stata sources for
#'   copy-paste) or \code{"source"} (raw runner only, for linked inspection in Shiny).
#' @param mode \code{"definitions"} (default) returns the stored script (function
#'   definitions; interactive footers stay gated). \code{"run"} returns definitions
#'   plus a final expression that loads yaml \code{data:}, calls \code{make_*},
#'   and pipes \code{format_*} when applicable (or ungates an interactive footer).
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return A character vector containing the lines of the replication script(s).
#'
#' @examples
#' \dontrun{
#' head(get_code("10.1177/00491241211036161", "fig_1"))
#' get_code("10.1017/S0003055403000534", "tab_1", language = "stata")
#' get_code("rep-template", "tab_1", mode = "run")
#' }
#'
#' @export
get_code <- function(
  doi,
  what,
  language = NULL,
  style = c("inline", "source"),
  mode = c("definitions", "run"),
  repo = NULL,
  folder = NULL
) {
  style <- match.arg(style)
  mode <- match.arg(mode)
  emit_get_code_usage_message()

  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    tryCatch(
      prepare_package_replication(pkg, meta, ctx),
      error = function(e) NULL
    )
    if (replication_package_usable(pkg)) {
      lines <- call_replication_package(pkg, "get_code", what)
      return(adjust_package_get_code_for_mode(lines, mode))
    }
    return(get_code_from_package_repo(meta, ctx, what, pkg, mode = mode))
  }

  rep <- find_replication_entry(meta, what, language = language)

  read_code_file <- function(path) {
    if (!is.null(ctx$local_root)) {
      local_code <- file.path(ctx$local_root, path)
      if (file.exists(local_code)) {
        return(readLines(local_code, warn = FALSE))
      }
    }

    # Code display should track GitHub main; the materialized study cache is for
    # runs (data files, Stata) and is not refreshed on every push.
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
          return(readLines(local_code, warn = FALSE))
        }
      }
    }
    code_url <- paste0(ctx$base_url, "/", path)
    read_lines_url(code_url)
  }

  if (is_stata_replication(rep, meta$paper)) {
    if (identical(style, "source")) {
      return(read_code_file(rep$code))
    }
    return(assemble_stata_display_code(rep, read_code_file))
  }

  lines <- read_code_file(rep$code)

  fmt_path <- format_script_path(rep)
  if (!is.null(fmt_path) && normalizePath(fmt_path, winslash = "/", mustWork = FALSE) !=
      normalizePath(rep$code, winslash = "/", mustWork = FALSE)) {
    fmt_lines <- read_code_file(fmt_path)
    if (length(fmt_lines)) {
      lines <- c(
        lines,
        "",
        "# --- Display formatting (optional; used by Shiny, not required to reproduce) ---",
        fmt_lines
      )
    }
  }

  if (identical(mode, "run")) {
    lines <- prepare_get_code_for_run(lines, rep)
  }
  lines
}

#' Usage tip printed by [get_code()] (any mode)
#' @keywords internal
emit_get_code_usage_message <- function() {
  if (isTRUE(getOption("replicateEverything.quiet_get_code", FALSE))) {
    return(invisible(NULL))
  }
  message(
    "get_code() returns script text. To produce the result object, use ",
    "run_replication(doi, what); or get_code(..., mode = \"run\") then eval() ",
    "from the study root; or Source the script at top level in the IDE to run ",
    "the manual footer block."
  )
  invisible(NULL)
}

#' Whether script lines contain an interactive sys.nframe() footer
#' @keywords internal
has_nframe_footer <- function(lines) {
  if (!length(lines)) {
    return(FALSE)
  }
  any(grepl(
    "^\\s*if\\s*\\(\\s*sys\\.nframe\\s*\\(\\s*\\)\\s*==\\s*0",
    lines
  ))
}

#' Ungate interactive footer so eval(parse()) runs the call body
#' @keywords internal
ungate_nframe_footer <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  sub(
    "^(\\s*if\\s*\\()\\s*sys\\.nframe\\s*\\(\\s*\\)\\s*==\\s*0L?\\s*(\\))",
    "\\1TRUE\\2",
    lines,
    perl = TRUE
  )
}

#' Analysis function name defined in script lines (make_* or generate_*)
#' @keywords internal
detect_analysis_fn_name <- function(lines, what) {
  make_name <- make_function_name(what)
  if (any(grepl(paste0("^\\s*", make_name, "\\s*<-\\s*function\\b"), lines))) {
    return(make_name)
  }
  if (any(grepl("^\\s*generate_table\\s*<-\\s*function\\b", lines))) {
    return("generate_table")
  }
  if (any(grepl("^\\s*generate_figure\\s*<-\\s*function\\b", lines))) {
    return("generate_figure")
  }
  make_name
}

#' Format helper name from yaml or script definitions
#' @keywords internal
detect_format_fn_name <- function(rep, lines) {
  what <- as.character(rep$id[[1]] %||% rep$id)
  fmt_field <- as.character(rep$format[[1]] %||% rep$format %||% "")
  if (length(fmt_field) && nzchar(fmt_field[[1]])) {
    fmt_field <- fmt_field[[1]]
    if (!grepl("[/\\\\]|\\.R$", fmt_field, ignore.case = TRUE)) {
      return(fmt_field)
    }
  }
  candidate <- paste0("format_", gsub("[^a-zA-Z0-9_]", "_", what))
  if (any(grepl(paste0("^\\s*", candidate, "\\s*<-\\s*function\\b"), lines))) {
    return(candidate)
  }
  NULL
}

#' Suggest a load expression for a study-root-relative data path
#' @keywords internal
suggest_data_load_expr <- function(path) {
  path <- as.character(path[[1]])
  qpath <- encodeString(path, quote = "\"")
  ext <- tolower(tools::file_ext(path))
  if (identical(ext, "csv")) {
    return(paste0("utils::read.csv(", qpath, ", stringsAsFactors = FALSE)"))
  }
  if (identical(ext, "rds")) {
    return(paste0("readRDS(", qpath, ")"))
  }
  if (identical(ext, "dta")) {
    return(paste0("haven::read_dta(", qpath, ")"))
  }
  if (identical(ext, "sav")) {
    return(paste0("haven::read_sav(", qpath, ")"))
  }
  paste0(
    "stop(\"Load data from ", path,
    " (study root as working directory), then call the analysis function\")"
  )
}

#' Append a yaml-implied run expression when no interactive footer exists
#' @keywords internal
assemble_get_code_run_from_yaml <- function(rep, lines) {
  what <- as.character(rep$id[[1]] %||% rep$id)
  fn_name <- detect_analysis_fn_name(lines, what)
  data_paths <- replication_data_paths(rep)
  out <- c(
    "",
    "# --- run (from replication.yml; working directory = study root) ---"
  )
  if (!length(data_paths)) {
    call_line <- paste0(fn_name, "()")
  } else if (length(data_paths) == 1L) {
    out <- c(out, paste0("data <- ", suggest_data_load_expr(data_paths[[1]])))
    call_line <- paste0(fn_name, "(data)")
  } else {
    loads <- vapply(data_paths, suggest_data_load_expr, character(1))
    list_lines <- paste0("  ", loads)
    if (length(list_lines) > 1L) {
      list_lines[-length(list_lines)] <- paste0(list_lines[-length(list_lines)], ",")
    }
    out <- c(out, "data <- list(", list_lines, ")")
    call_line <- paste0(fn_name, "(data)")
  }

  fmt_fn <- detect_format_fn_name(rep, lines)
  if (!is.null(fmt_fn) && nzchar(fmt_fn)) {
    call_line <- paste0(call_line, " |> ", fmt_fn, "()")
  }
  c(out, call_line)
}

#' Make R get_code lines runnable under eval(parse())
#' @keywords internal
prepare_get_code_for_run <- function(lines, rep) {
  if (has_nframe_footer(lines)) {
    return(ungate_nframe_footer(lines))
  }
  what <- as.character(rep$id[[1]] %||% rep$id)
  # Top-level make_*() call already present (unguarded script)
  if (isTRUE(script_has_make_call(lines, what))) {
    return(lines)
  }
  c(lines, assemble_get_code_run_from_yaml(rep, lines))
}

#' Trim or keep package-repo get_code run section by mode
#' @keywords internal
adjust_package_get_code_for_mode <- function(lines, mode) {
  mode <- match.arg(mode, c("definitions", "run"))
  if (identical(mode, "run") || !length(lines)) {
    return(lines)
  }
  idx <- which(grepl("^\\s*# --- run \\(from replication\\.yml\\) ---\\s*$", lines))
  if (!length(idx)) {
    return(lines)
  }
  cut_at <- idx[[1]]
  if (cut_at > 1L && !nzchar(trimws(lines[[cut_at - 1L]]))) {
    cut_at <- cut_at - 1L
  }
  lines[seq_len(cut_at - 1L)]
}

#' @keywords internal
stata_code_banner <- function(title) {
  bar <- paste(rep("=", 60L), collapse = "")
  c(paste0("* ", bar), paste0("* ", title), paste0("* ", bar))
}

#' @keywords internal
extract_stata_do_paths <- function(lines) {
  if (!length(lines)) {
    return(character())
  }
  matched <- regmatches(
    lines,
    regexec('^\\s*(?:quietly\\s+)?do\\s+"([^"]+)"', lines, perl = TRUE)
  )
  vapply(matched, function(m) if (length(m) >= 2L) m[[2L]] else "", character(1L))
}

#' @keywords internal
normalize_stata_source_path <- function(path) {
  path <- gsub("\\\\", "/", path)
  path <- sub("^\\$\\{maindir\\}/", "", path)
  sub("^\\./", "", path)
}

#' @keywords internal
is_stata_setup_do_path <- function(path) {
  base <- basename(path)
  grepl("init_study_paths|init_paths|^init_", base, ignore.case = TRUE) ||
    grepl("/helpers/init", path, ignore.case = TRUE) ||
    grepl("setup_analysis|setup_paths", base, ignore.case = TRUE)
}

#' Infer substantive Stata scripts from nested \code{do} calls in a runner.
#' @keywords internal
infer_stata_source_paths <- function(wrapper_lines) {
  paths <- extract_stata_do_paths(wrapper_lines)
  paths <- paths[nzchar(paths)]
  paths <- vapply(paths, normalize_stata_source_path, character(1L))
  paths <- paths[!vapply(paths, is_stata_setup_do_path, logical(1L))]
  unique(paths)
}

#' @keywords internal
drop_nested_stata_do_calls <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  keep <- !grepl('^\\s*(quietly\\s+)?do\\s+"', lines, ignore.case = TRUE)
  lines[keep]
}

#' @keywords internal
drop_stata_log_directives <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  keep <- !grepl("^\\s*(capture\\s+)?log\\s+(using|close)", lines, ignore.case = TRUE)
  keep <- keep & !grepl("^\\s*cd\\s+", lines, ignore.case = TRUE)
  lines[keep]
}

#' @keywords internal
assemble_stata_display_code <- function(rep, read_code_file) {
  wrapper_raw <- read_code_file(rep$code)

  stata_paths <- rep$stata_source %||% rep$stata_sources %||% NULL
  stata_paths <- as.character(unlist(stata_paths, use.names = FALSE))
  stata_paths <- stata_paths[nzchar(stata_paths)]
  if (!length(stata_paths)) {
    stata_paths <- infer_stata_source_paths(wrapper_raw)
  }

  wrapper <- drop_nested_stata_do_calls(wrapper_raw)

  if (!length(stata_paths)) {
    return(c(
      stata_code_banner("STATA REPLICATION — setup and runner"),
      wrapper
    ))
  }

  source_label <- stata_paths[[1]]
  source_lines <- read_code_file(stata_paths[[1]])
  source_lines <- drop_stata_log_directives(source_lines)

  out <- c(
    stata_code_banner("STATA REPLICATION — setup (edit maindir if needed)"),
    wrapper,
    "",
    stata_code_banner(paste0("ANALYSIS — ", source_label)),
    source_lines
  )

  if (length(stata_paths) > 1L) {
    for (extra in stata_paths[-1L]) {
      extra_lines <- read_code_file(extra)
      extra_lines <- drop_stata_log_directives(extra_lines)
      out <- c(
        out,
        "",
        stata_code_banner(paste0("ANALYSIS — ", extra)),
        extra_lines
      )
    }
  }

  out
}
