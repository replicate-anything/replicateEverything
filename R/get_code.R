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
#' For package-backed studies, reads \code{inst/replication_code/*.R} from the
#' study package GitHub repo when the package is not installed (same idea as
#' reading \code{code/*.R} from the registry repo).
#'
#' @param doi Character. DOI of the paper.
#' @param what Character. Replication identifier (logical id).
#' @param language Optional \code{"R"} or \code{"stata"}.
#' @param repo Optional repository slug.
#' @param folder Optional registry folder name from \code{index.csv}.
#' @return A character vector containing the lines of the replication script(s).
#'
#' @examples
#' \dontrun{
#' head(get_code("10.1177/00491241211036161", "fig_1"))
#' get_code("10.1017/S0003055403000534", "tab_1", language = "stata")
#' }
#'
#' @export
get_code <- function(doi, what, language = NULL, repo = NULL, folder = NULL) {
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  if (is_package_replication(meta)) {
    pkg <- as.character(meta$paper$package[[1]])
    tryCatch(
      prepare_package_replication(pkg, meta, ctx),
      error = function(e) NULL
    )
    if (replication_package_usable(pkg)) {
      return(call_replication_package(pkg, "get_code", what))
    }
    return(get_code_from_package_repo(meta, ctx, what, pkg))
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
  lines
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
