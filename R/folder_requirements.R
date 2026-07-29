#' Resolve a folder-backed study repository root
#'
#' @param location Local study path or GitHub address (`org/repo` or URL).
#' @return Normalized path to study repo root (contains `replication.yml`).
#' @keywords internal
resolve_study_location <- function(location) {
  if (length(location) != 1L || is.na(location) || !nzchar(trimws(location))) {
    stop("location must be a non-empty path or GitHub address.", call. = FALSE)
  }
  loc <- trimws(location)
  if (dir.exists(loc) && file.exists(file.path(loc, "replication.yml"))) {
    return(normalizePath(loc, winslash = "/", mustWork = FALSE))
  }
  alias_root <- try_resolve_study_by_common_alias(loc)
  if (!is.null(alias_root)) {
    return(alias_root)
  }
  if (looks_like_doi_location(loc)) {
    folder <- study_folder_from_doi(loc)
    stop(
      "Could not find a local study folder for DOI ", loc, ".\n",
      "Expected sibling folder ", folder, " under the monorepo root.\n",
      "Call configure_local_monorepo(\"path/to/replicate_everything\") once per session,\n",
      "or pass the study path: check_replication(\".../", folder, "\")",
      call. = FALSE
    )
  }
  slug <- parse_github_slug(loc)
  if (is.null(slug)) {
    stop(
      "Could not resolve study location: ", loc,
      ". Provide a directory containing replication.yml or a GitHub URL/slug (org/repo).",
      study_location_input_hints(loc),
      call. = FALSE
    )
  }
  tmp <- file.path(
    tempdir(),
    paste0("re_add_folder_", gsub("[^a-zA-Z0-9._-]", "_", slug))
  )
  if (dir.exists(tmp)) {
    unlink(tmp, recursive = TRUE, force = TRUE)
  }
  git <- Sys.which("git")
  if (!nzchar(git)) {
    stop(
      "Git is required to clone ", slug,
      ". Clone the repository locally and pass the study path.",
      call. = FALSE
    )
  }
  status <- system2(
    git,
    c("clone", "--depth", "1", sprintf("https://github.com/%s.git", slug), tmp),
    stdout = FALSE,
    stderr = FALSE
  )
  if (!identical(status, 0L) || !file.exists(file.path(tmp, "replication.yml"))) {
    stop(study_location_clone_failure_message(slug, loc), call. = FALSE)
  }
  normalizePath(tmp, winslash = "/", mustWork = FALSE)
}

#' Read replication yaml from a folder-backed study tree
#' @keywords internal
read_study_replication_yaml <- function(study_root) {
  path <- file.path(study_root, "replication.yml")
  if (!file.exists(path)) {
    return(NULL)
  }
  yaml::read_yaml(path)
}

#' Build the lightweight registry stub yaml list from folder study metadata
#' @keywords internal
registry_stub_from_folder_meta <- function(meta, study_folder = NULL, study_root = NULL) {
  paper <- meta$paper
  study_repo <- if (!is.null(study_root)) {
    infer_study_repo_slug(study_root, meta)
  } else {
    as.character((meta$repo %||% paper$study_repo)[[1]])
  }
  if (is.null(study_repo) || !nzchar(study_repo)) {
    stop("Could not infer study repo slug; set repo or paper.study_repo in replication.yml", call. = FALSE)
  }
  source_repositories <- paper_source_repositories(paper = paper)
  source_repository <- if (!length(source_repositories)) {
    NULL
  } else if (length(source_repositories) == 1L) {
    source_repositories[[1L]]
  } else {
    as.list(source_repositories)
  }
  stub_paper <- list(
    doi = paper$doi,
    study_handle = paper$study_handle %||% paper$handle %||% NULL,
    title = paper$title,
    journal = paper$journal %||% NULL,
    year = paper$year %||% NULL,
    authors = paper$authors %||% NULL,
    abstract = paper$abstract %||% NULL,
    study_url = paper$study_url %||% NULL,
    article_url = paper$article_url %||% paper$landing_url %||% paper$publisher_url %||% NULL,
    source_repository = source_repository,
    related = paper$related %||% NULL,
    extends = paper$extends %||% meta$extends %||% NULL,
    materials = "folder",
    study_repo = study_repo,
    study_ref = as.character((paper$study_ref %||% "main")[[1]])
  )
  if (!is.null(study_folder) && nzchar(study_folder)) {
    stub_paper$study_folder <- study_folder
  }
  stub_paper <- stub_paper[!vapply(stub_paper, is.null, logical(1))]
  c(
    list(paper = stub_paper, repo = study_repo),
    registry_stub_summary_fields(meta)
  )
}

#' Maintainer, collections, languages, and notes copied into registry study stubs
#' @keywords internal
registry_stub_summary_fields <- function(meta) {
  out <- list()
  maintainer <- meta$maintainer %||% list()
  maintainer_name <- as.character(maintainer$name %||% maintainer$Name %||% "")
  maintainer_email <- as.character(maintainer$email %||% maintainer$Email %||% "")
  if (nzchar(maintainer_name) || nzchar(maintainer_email)) {
    maintainer_out <- list(
      name = if (nzchar(maintainer_name)) maintainer_name else NULL,
      email = if (nzchar(maintainer_email)) maintainer_email else NULL
    )
    maintainer_out <- maintainer_out[!vapply(maintainer_out, is.null, logical(1))]
    if (length(maintainer_out) > 0L) {
      out$maintainer <- maintainer_out
    }
  }
  collections <- meta$collections %||% meta$paper$collections %||% character(0)
  collections <- unique(na.omit(as.character(unlist(collections, use.names = FALSE))))
  collections <- collections[nzchar(collections)]
  if (length(collections) > 0L) {
    out$collections <- as.list(collections)
  }
  languages <- study_declared_languages(meta)
  if (length(languages) > 0L) {
    out$languages <- as.list(languages)
  }
  # Studies-tab padlock / hammer signals — baked at sync so Shiny never fetches
  # study yaml just to paint the list.
  gaps <- tryCatch(
    study_gap_flags_from_entries(meta),
    error = function(e) list(data_unavailable = FALSE, missing_engine = FALSE)
  )
  langs_lower <- tolower(as.character(languages))
  if (any(langs_lower %in% c("mathematica", "wolfram", "wolframscript"))) {
    gaps$missing_engine <- TRUE
  }
  if (isTRUE(gaps$data_unavailable) || isTRUE(gaps$missing_engine)) {
    out$notes <- list(
      data_unavailable = isTRUE(gaps$data_unavailable),
      missing_engine = isTRUE(gaps$missing_engine)
    )
  }
  out
}

#' Options for running replications against a local folder-backed study
#' @keywords internal
folder_study_run_options <- function(study_root, meta, registry_root = NULL) {
  paper <- meta$paper
  if (is.null(paper$doi) || !nzchar(as.character(paper$doi[[1]] %||% ""))) {
    doi <- as.character(paper$study_handle[[1]] %||% paper$study_handle %||% "")
    folder <- doi
  } else {
    doi <- normalize_doi(paper$doi)
    folder <- doi_to_registry_folder(doi)
  }
  study_repo <- infer_study_repo_slug(study_root, meta)
  if (is.null(study_repo)) {
    stop("Could not infer study repo slug; set repo or paper.study_repo in replication.yml", call. = FALSE)
  }

  authors <- paper$authors %||% ""
  if (length(authors) > 1) {
    authors <- paste(authors, collapse = ", ")
  } else {
    authors <- as.character(authors[[1]] %||% "")
  }

  local_index <- data.frame(
    folder = folder,
    doi = doi,
    title = as.character(paper$title[[1]] %||% ""),
    journal = as.character(paper$journal %||% ""),
    year = normalize_registry_year(paper$year),
    authors = authors,
    repo = study_repo,
    stringsAsFactors = FALSE
  )

  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  monorepo_root <- normalizePath(dirname(study_root), winslash = "/", mustWork = FALSE)

  opts <- list(
    replicateEverything.use_sibling_packages = TRUE,
    replicateEverything.study_folders_root = monorepo_root,
    replicateEverything.study_data_root = monorepo_root,
    replicateEverything.index = local_index
  )
  if (!is.null(registry_root) && nzchar(registry_root) && dir.exists(registry_root)) {
    opts$replicateEverything.registry_root <- normalizePath(
      registry_root,
      winslash = "/",
      mustWork = FALSE
    )
  }
  opts
}

#' Portable study metadata for outputs/manifest.json
#'
#' Committed manifests should reference the GitHub slug and monorepo-relative
#' folder name, not machine-specific absolute paths.
#'
#' @param study_root Normalized study repository path.
#' @param meta Parsed study \code{replication.yml}.
#' @keywords internal
folder_manifest_metadata <- function(study_root, meta) {
  study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
  study_repo <- infer_study_repo_slug(study_root, meta)
  out <- list(
    study_repo = study_repo,
    study_folder = basename(study_root)
  )
  monorepo <- sibling_monorepo_root()
  if (!is.null(monorepo)) {
    monorepo <- normalizePath(monorepo, winslash = "/", mustWork = FALSE)
    rel <- sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", monorepo), "/?"), "", study_root)
    if (nzchar(rel) && !identical(rel, study_root) && !identical(rel, out$study_folder)) {
      out$monorepo_path <- rel
    }
  }
  out[!vapply(out, is.null, logical(1))]
}

#' Rewrite absolute paths in text for portable logs and manifests
#'
#' @param text Character scalar.
#' @param study_root Study repository root to relativize.
#' @keywords internal
portable_path_in_text <- function(text, study_root = NULL) {
  if (is.null(text) || length(text) != 1L || !nzchar(text)) {
    return(text)
  }
  replacements <- list()
  if (!is.null(study_root) && nzchar(study_root)) {
    study_root <- normalizePath(study_root, winslash = "/", mustWork = FALSE)
    replacements[[study_root]] <- basename(study_root)
  }
  monorepo <- sibling_monorepo_root()
  if (!is.null(monorepo)) {
    monorepo <- normalizePath(monorepo, winslash = "/", mustWork = FALSE)
    replacements[[monorepo]] <- "."
  }
  for (abs_path in names(replacements)) {
    rel <- replacements[[abs_path]]
    text <- gsub(abs_path, rel, text, fixed = TRUE)
    win_path <- gsub("/", "\\", abs_path, fixed = TRUE)
    if (!identical(win_path, abs_path)) {
      text <- gsub(win_path, rel, text, fixed = TRUE)
    }
  }
  text
}

#' Display replications from study yaml
#' @keywords internal
folder_display_replications <- function(meta) {
  steps <- tryCatch(collect_study_step_entries(meta), error = function(e) list())
  from_steps <- steps[vapply(steps, function(x) {
    is_display_step_type(x$type %||% "")
  }, logical(1))]
  from_steps[vapply(from_steps, function(x) {
    !isTRUE(x$incomplete %||% FALSE)
  }, logical(1))]
}

#' Infer GitHub slug for a folder-backed study
#' @keywords internal
infer_study_repo_slug <- function(study_root, meta) {
  from_meta <- meta$repo %||% meta$paper$study_repo %||% NULL
  if (!is.null(from_meta) && nzchar(as.character(from_meta[[1]]))) {
    return(as.character(from_meta[[1]]))
  }
  folder <- basename(normalizePath(study_root, winslash = "/", mustWork = FALSE))
  if (grepl("^rep[-_]", folder)) {
    return(paste0("replicate-anything/", folder))
  }
  NULL
}

#' Resolve data paths listed on a replication entry
#'
#' Prefers \code{data:}; falls back to \code{inputs:} when \code{data:} is omitted
#' so yaml remains the execute recipe for [get_code()] / Live Run tips.
#' @keywords internal
replication_data_paths <- function(rep) {
  data <- rep$data %||% NULL
  if (is.null(data) || (is.list(data) && !length(data)) ||
      (is.character(data) && !any(nzchar(data)))) {
    data <- rep$inputs %||% NULL
  }
  if (is.null(data)) {
    return(character(0))
  }
  if (is.list(data) && !is.data.frame(data)) {
    data <- unlist(data, use.names = FALSE)
  }
  paths <- as.character(data)
  paths[nzchar(paths)]
}

#' Check whether a baked table artifact file is valid for folder checks
#'
#' Accepts `.rds`, Excel workbooks (`.xlsx` / `.xlsm` / `.xls`), HTML with a
#' `<table>`, or (for Stata entries) monospace `<pre class="stata-output">`
#' blocks produced when regression output cannot be parsed into an HTML table.
#'
#' @param art_path Path to the artifact file.
#' @param engine Optional replication engine (`"stata"` or `"r"`).
#' @keywords internal
table_artifact_file_ok <- function(art_path, engine = NULL) {
  ext <- tolower(tools::file_ext(art_path))
  if (identical(ext, "rds")) {
    return(TRUE)
  }
  if (ext %in% c("xlsx", "xlsm", "xls")) {
    return(file.exists(art_path) && isTRUE(file.size(art_path) > 100))
  }
  if (!identical(ext, "html") || !file.exists(art_path)) {
    return(FALSE)
  }
  html <- paste(readLines(art_path, warn = FALSE), collapse = "\n")
  if (grepl("<table", html, ignore.case = TRUE)) {
    return(TRUE)
  }
  identical(engine, "stata") &&
    grepl('<pre[^>]*class="[^"]*stata-output', html, ignore.case = TRUE)
}

#' Format one Excel preview cell for Shiny Display
#'
#' Numeric values (and character cells that parse as plain numbers) are rounded
#' to 3 decimal places. Non-numeric text is left unchanged.
#'
#' @param x A length-1 cell value.
#' @return Character scalar suitable for an HTML table cell.
#' @keywords internal
format_xlsx_preview_cell <- function(x) {
  # readxl mixed-type columns are list-columns; unwrap length-1 lists.
  while (is.list(x) && length(x) == 1L) {
    x <- x[[1]]
  }
  if (length(x) != 1L) {
    x <- x[[1]]
  }
  if (is.null(x) || (length(x) == 1L && is.na(x))) {
    return("")
  }
  round3 <- function(num) {
    sprintf("%.3f", round(as.numeric(num), 3L))
  }
  if (is.numeric(x)) {
    return(round3(x))
  }
  s <- trimws(as.character(x))
  if (!nzchar(s) || identical(s, "NA")) {
    return("")
  }
  # Character cells that are plain numbers (Excel often stores these as text,
  # including binary float artifacts like "6.2399425510000004").
  if (grepl("^-?[0-9]+(\\.[0-9]+)?([eE][-+]?[0-9]+)?$", s)) {
    num <- suppressWarnings(as.numeric(s))
    if (!is.na(num)) {
      return(round3(num))
    }
  }
  s
}

#' Trim blank rows/cols and round numeric cells for Excel Display preview
#'
#' @param df A data frame from \code{readxl::read_excel(..., col_names = FALSE)}.
#' @return A character data frame (possibly empty).
#' @keywords internal
format_xlsx_preview_df <- function(df) {
  if (!is.data.frame(df) || nrow(df) == 0L || ncol(df) == 0L) {
    return(df)
  }
  is_blank <- function(x) {
    vals <- trimws(as.character(x))
    is.na(vals) | !nzchar(vals)
  }
  keep_rows <- vapply(seq_len(nrow(df)), function(i) !all(is_blank(df[i, , drop = TRUE])), logical(1))
  keep_cols <- vapply(seq_len(ncol(df)), function(i) !all(is_blank(df[[i]])), logical(1))
  if (!any(keep_rows) || !any(keep_cols)) {
    return(data.frame())
  }
  out <- df[keep_rows, keep_cols, drop = FALSE]
  out[] <- lapply(out, function(col) {
    vapply(seq_along(col), function(i) format_xlsx_preview_cell(col[[i]]), character(1))
  })
  names(out) <- rep("", ncol(out))
  out
}

#' Regex for \code{outputs:} paths that Shiny Display can open
#'
#' Includes spreadsheet sinks (Hahn \code{tab_1}/\code{tab_2} \code{.xlsx}) and
#' tabular prep sinks (\code{.csv}/\code{.dta}/\code{.tab}) so lookup does not
#' fall through to a non-existent \code{outputs/<id>.html}. Marker sinks
#' (\code{.done}) are handled separately via [load_prep_step_display()].
#'
#' @keywords internal
displayable_output_ext_regex <- function() {
  "\\.(html|png|rds|svg|xlsx|xlsm|xls|csv|dta|tab)$"
}

#' Declared \code{outputs:} paths for a prep/transform step (any extension)
#'
#' Unlike [study_declared_displayable_rels()], this keeps marker sinks such as
#' \code{.done} so local baked prep products resolve before type-default
#' \code{outputs/<id>.html} remote URLs.
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
study_declared_prep_output_rels <- function(rep) {
  if (!is_prep_entry(rep)) {
    return(character(0))
  }
  outs <- rep$outputs %||% NULL
  if (is.null(outs) || !length(outs)) {
    return(character(0))
  }
  outs <- vapply(outs, function(x) as.character(x[[1]] %||% x), character(1))
  outs <- trimws(outs)
  outs[nzchar(outs)]
}

#' Declared displayable \code{outputs:} paths only (no type-based fallbacks)
#'
#' Used when Display should stack every panel listed under \code{outputs:}
#' (e.g. multi-panel figures). \code{study_artifact_rel_candidates()} still
#' appends type defaults for single-artifact lookup / bake.
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
study_declared_displayable_rels <- function(rep) {
  outs <- rep$outputs %||% NULL
  if (is.null(outs) || !length(outs)) {
    return(character(0))
  }
  outs <- vapply(outs, function(x) as.character(x[[1]] %||% x), character(1))
  outs <- outs[nzchar(outs)]
  outs[grepl(displayable_output_ext_regex(), outs, ignore.case = TRUE)]
}

#' Candidate display artifact paths under \code{outputs/}
#'
#' Uses displayable paths from \code{outputs:} (html/png/rds/svg/xlsx/csv/dta),
#' then declared prep sinks (including \code{.done}), then type-based defaults
#' under \code{outputs/}. Prep steps with declared sinks skip the misleading
#' \code{outputs/<id>.html}/\code{.png} fallbacks that produced remote HTTP 404s.
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
study_artifact_rel_candidates <- function(rep) {
  id <- as.character(rep$id %||% "")
  cands <- character(0)
  display <- study_declared_displayable_rels(rep)
  if (length(display)) {
    cands <- c(cands, display)
  }
  prep_declared <- study_declared_prep_output_rels(rep)
  if (length(prep_declared)) {
    cands <- c(cands, prep_declared)
  }
  has_prep_sink <- length(prep_declared) > 0L
  if (nzchar(id)) {
    if (has_prep_sink) {
      # Declared prep sinks are authoritative; do not invent html/png.
    } else if (is_prep_entry(rep)) {
      cands <- c(
        cands,
        paste0("outputs/", id, ".rds"),
        paste0("outputs/", id, ".dta"),
        paste0("outputs/", id, ".csv"),
        paste0("outputs/", id, ".html"),
        paste0("outputs/", id, ".png")
      )
    } else if (identical(rep$type, "figure")) {
      cands <- c(
        cands,
        paste0("outputs/", id, ".png"),
        paste0("outputs/", id, ".html")
      )
    } else {
      cands <- c(
        cands,
        paste0("outputs/", id, ".html"),
        paste0("outputs/", id, ".png")
      )
    }
  }
  if (!has_prep_sink) {
    legacy <- default_artifact_path(rep, id)
    cands <- c(cands, legacy)
  }
  unique(cands[nzchar(cands)])
}

#' Artifact path relative to study root (primary candidate)
#'
#' Returns the first displayable path from \code{outputs:} in
#' \code{replication.yml} (html/png/rds/svg/xlsx/csv/dta), otherwise the
#' type-based default from \code{default_artifact_path()}. This is the one rule
#' used by both \code{save_artifact()} (build) and artifact lookup (Shiny), so
#' builds write exactly where lookup reads.
#'
#' @param rep A single replication entry from \code{replication.yml}.
#' @keywords internal
study_artifact_rel_path <- function(rep) {
  cands <- study_artifact_rel_candidates(rep)
  if (length(cands) == 0L) {
    return("")
  }
  cands[[1]]
}
