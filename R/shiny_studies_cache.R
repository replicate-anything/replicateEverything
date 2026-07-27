#' Basename for the Shiny Studies precomputed cache
#' @noRd
SHINY_STUDIES_CACHE_BASENAME <- "shiny_studies.json"

#' Session memo for [load_shiny_studies_cache()]
#' @noRd
.shiny_studies_cache_memo <- new.env(parent = emptyenv())

#' Path to `shiny_studies.json` under a registry root
#'
#' @param registry_root Path to the registry repository.
#' @return Character path.
#' @noRd
shiny_studies_cache_path <- function(registry_root) {
  file.path(registry_root, SHINY_STUDIES_CACHE_BASENAME)
}

#' Remote URL for the Shiny Studies cache on GitHub
#' @noRd
shiny_studies_cache_url <- function() {
  paste0(
    "https://raw.githubusercontent.com/",
    DEFAULT_REGISTRY_REPO,
    "/main/",
    SHINY_STUDIES_CACHE_BASENAME
  )
}

#' Parse languages cell / list into engine flags for the Studies table
#' @noRd
shiny_studies_engine_flags <- function(languages) {
  parts <- shiny_studies_languages_vec(languages)
  list(
    r = "r" %in% parts,
    stata = "stata" %in% parts,
    python = "python" %in% parts || "py" %in% parts,
    mathematica = any(parts %in% c("mathematica", "wolfram", "wolframscript"))
  )
}

#' Normalize languages to a character vector for the cache
#' @noRd
shiny_studies_languages_vec <- function(languages) {
  if (is.null(languages) || length(languages) == 0L) {
    return(character(0))
  }
  if (is.list(languages) || (is.character(languages) && length(languages) > 1L)) {
    parts <- trimws(as.character(unlist(languages, use.names = FALSE)))
  } else {
    raw <- as.character(languages[[1]] %||% languages %||% "")
    if (!length(raw) || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
      return(character(0))
    }
    parts <- trimws(strsplit(raw[[1]], "[|;]", perl = TRUE)[[1]])
  }
  unique(parts[nzchar(parts) & !is.na(parts)])
}

#' Normalize collections to a character vector for the cache
#' @noRd
shiny_studies_collections_vec <- function(collections) {
  if (is.null(collections) || length(collections) == 0L) {
    return(character(0))
  }
  if (is.list(collections) || (is.character(collections) && length(collections) > 1L)) {
    parts <- trimws(as.character(unlist(collections, use.names = FALSE)))
  } else {
    raw <- as.character(collections[[1]] %||% collections %||% "")
    if (!length(raw) || is.na(raw[[1]]) || !nzchar(raw[[1]])) {
      return(character(0))
    }
    parts <- trimws(strsplit(raw[[1]], "[|;]", perl = TRUE)[[1]])
  }
  unique(parts[nzchar(parts) & !is.na(parts)])
}

#' Citation label used in the Studies table Study column (line 1)
#' @noRd
shiny_studies_citation_label <- function(authors, year, title) {
  author <- format_author_label(authors)
  year_chr <- trimws(as.character(year %||% ""))
  if (!nzchar(year_chr) || identical(year_chr, "NA")) {
    year_chr <- ""
  }
  title_chr <- trimws(as.character(title %||% ""))
  if (nzchar(year_chr)) {
    sprintf('%s (%s) "%s"', author, year_chr, title_chr)
  } else {
    sprintf('%s "%s"', author, title_chr)
  }
}

#' Gap notes from stub summary fields (if present)
#' @noRd
shiny_studies_notes_from_meta <- function(meta) {
  notes <- list(data_unavailable = FALSE, missing_engine = FALSE)
  if (is.null(meta) || !is.list(meta)) {
    return(notes)
  }
  stub_notes <- meta$notes %||% NULL
  if (is.list(stub_notes)) {
    notes$data_unavailable <- isTRUE(stub_notes$data_unavailable)
    notes$missing_engine <- isTRUE(stub_notes$missing_engine)
  }
  # Full study yaml (or stub that still carries steps) — derive from entries
  if (is.list(meta$steps) && length(meta$steps) > 0L) {
    from_steps <- study_gap_flags_from_entries(meta)
    notes$data_unavailable <- isTRUE(notes$data_unavailable) ||
      isTRUE(from_steps$data_unavailable)
    notes$missing_engine <- isTRUE(notes$missing_engine) ||
      isTRUE(from_steps$missing_engine)
  }
  notes
}

#' Whether an audit skip / error snippet is a data-unavailable reason
#' @noRd
audit_reason_is_data_unavailable <- function(reason) {
  txt <- as.character(reason[[1]] %||% reason %||% "")
  if (!nzchar(txt)) {
    return(FALSE)
  }
  grepl(
    "because of .+ data|proprietary|unavailable data|data_unavailable|data unavailable",
    txt,
    ignore.case = TRUE,
    perl = TRUE
  )
}

#' Per-study gap flags from the latest registry audit snapshot
#'
#' @param registry_root Optional registry checkout with \code{audit_latest.rds}.
#' @return Named list keyed by normalized DOI / handle; each value is
#'   \code{list(data_unavailable, missing_engine)}.
#' @noRd
shiny_studies_gap_map_from_audit <- function(registry_root = NULL) {
  snap <- tryCatch(
    load_registry_audit_snapshot(registry_root),
    error = function(e) NULL
  )
  out <- list()
  if (is.null(snap) || is.null(snap$results) || !nrow(snap$results)) {
    return(out)
  }
  results <- snap$results
  if (!("skipped" %in% names(results))) {
    return(out)
  }
  skipped <- results[as.logical(results$skipped) %in% TRUE, , drop = FALSE]
  if (!nrow(skipped)) {
    return(out)
  }
  for (i in seq_len(nrow(skipped))) {
    row <- skipped[i, , drop = FALSE]
    key <- trimws(as.character(row$doi[[1]] %||% ""))
    if (!nzchar(key)) {
      key <- trimws(as.character(row$folder[[1]] %||% row$handle[[1]] %||% ""))
    }
    if (!nzchar(key)) {
      next
    }
    if (grepl("/", key, fixed = TRUE) || grepl("^10\\.", key)) {
      key <- normalize_doi(key)
    }
    reason <- ""
    if ("error_snippet" %in% names(row)) {
      reason <- as.character(row$error_snippet[[1]] %||% "")
    }
    if (!nzchar(reason) && "skip_reason" %in% names(row)) {
      reason <- as.character(row$skip_reason[[1]] %||% "")
    }
    cur <- out[[key]] %||% list(data_unavailable = FALSE, missing_engine = FALSE)
    if (audit_reason_is_data_unavailable(reason)) {
      cur$data_unavailable <- TRUE
    }
    if (
      audit_reason_is_missing_engine(reason) ||
        grepl("mathematica|wolfram|matlab|julia", reason, ignore.case = TRUE)
    ) {
      cur$missing_engine <- TRUE
    }
    out[[key]] <- cur
  }
  out
}

#' Merge stub / language / audit signals into final notes flags
#' @noRd
shiny_studies_merge_notes <- function(from_meta, engines, audit_notes = NULL) {
  notes <- list(
    data_unavailable = isTRUE(from_meta$data_unavailable),
    missing_engine = isTRUE(from_meta$missing_engine) || isTRUE(engines$mathematica)
  )
  if (!is.null(audit_notes)) {
    notes$data_unavailable <- isTRUE(notes$data_unavailable) ||
      isTRUE(audit_notes$data_unavailable)
    notes$missing_engine <- isTRUE(notes$missing_engine) ||
      isTRUE(audit_notes$missing_engine)
  }
  notes
}

#' Compact related-study records for the cache (title / url / key)
#' @noRd
shiny_studies_related_records <- function(keys, direction, index) {
  items <- resolve_related_studies(keys, direction = direction, index = index)
  lapply(items, function(item) {
    list(
      key = as.character(item$key %||% ""),
      title = as.character(item$title %||% item$label %||% ""),
      doi = as.character(item$doi %||% ""),
      repo = as.character(item$repo %||% ""),
      href = {
        h <- item$href %||% NA_character_
        if (length(h) != 1L || is.na(h)) "" else as.character(h)
      },
      in_registry = isTRUE(item$in_registry),
      label = as.character(item$label %||% item$title %||% item$key %||% "")
    )
  })
}

#' Build one Shiny Studies cache record from an index row + stub meta
#' @noRd
shiny_studies_record_from_row <- function(
  row,
  meta = NULL,
  index = NULL,
  audit_gap_map = NULL
) {
  folder <- index_row_field(row, "folder", "")
  handle <- index_row_field(row, "handle", folder)
  doi <- index_row_field(row, "doi", "")
  if (nzchar(doi)) {
    doi <- normalize_doi(doi)
  }
  key <- if (nzchar(doi)) doi else handle
  if (!nzchar(key)) {
    key <- folder
  }
  title <- index_row_field(row, "title", "")
  authors <- index_row_field(row, "authors", "")
  year <- index_row_field(row, "year", "")
  journal <- index_row_field(row, "journal", "")
  repo <- index_row_field(row, "repo", "")
  article_url <- index_row_field(row, "article_url", "")
  if (nzchar(article_url) && grepl("github\\.com", article_url, ignore.case = TRUE)) {
    article_url <- ""
  }

  languages <- shiny_studies_languages_vec(index_row_field(row, "languages", ""))
  if (length(languages) == 0L && is.list(meta)) {
    languages <- shiny_studies_languages_vec(meta$languages %||% character(0))
  }
  engines <- shiny_studies_engine_flags(languages)
  if (!any(unlist(engines))) {
    engines <- list(r = TRUE, stata = FALSE, python = FALSE, mathematica = FALSE)
    if (!length(languages)) {
      languages <- "r"
    }
  }

  collections <- shiny_studies_collections_vec(
    index_row_field(row, "collections", "")
  )
  if (length(collections) == 0L && is.list(meta)) {
    collections <- shiny_studies_collections_vec(
      meta$collections %||% meta$paper$collections %||% character(0)
    )
  }

  from_meta <- shiny_studies_notes_from_meta(meta)
  audit_notes <- NULL
  if (is.list(audit_gap_map) && length(audit_gap_map) > 0L) {
    audit_notes <- audit_gap_map[[key]]
    if (is.null(audit_notes) && nzchar(doi)) {
      audit_notes <- audit_gap_map[[doi]]
    }
    if (is.null(audit_notes) && nzchar(handle)) {
      audit_notes <- audit_gap_map[[handle]]
    }
    if (is.null(audit_notes) && nzchar(folder)) {
      audit_notes <- audit_gap_map[[folder]]
    }
  }
  notes <- shiny_studies_merge_notes(from_meta, engines, audit_notes)

  related_up <- shiny_studies_related_records(
    index_row_field(row, "related_upstream", ""),
    "upstream",
    index
  )
  related_down <- shiny_studies_related_records(
    index_row_field(row, "related_downstream", ""),
    "downstream",
    index
  )

  study_url <- if (nzchar(repo)) {
    paste0("https://github.com/", normalize_repo_slug(repo))
  } else {
    ""
  }
  paper_study_url <- ""
  source_repository <- ""
  if (is.list(meta) && is.list(meta$paper)) {
    paper_study_url <- trimws(as.character(meta$paper$study_url %||% ""))
    source_repository <- paper_source_repository(paper = meta$paper) %||% ""
  }
  if (!nzchar(study_url) && nzchar(paper_study_url)) {
    study_url <- paper_study_url
  }
  # Prefer index column when present (future-proof); stubs remain the source of truth.
  if (!nzchar(source_repository) && "source_repository" %in% names(row)) {
    source_repository <- trimws(as.character(index_row_field(row, "source_repository", "")))
  }
  source_kind <- if (nzchar(source_repository)) {
    source_repository_kind(source_repository)
  } else {
    ""
  }

  list(
    folder = folder,
    handle = handle,
    doi = doi,
    key = key,
    title = title,
    authors = authors,
    year = year,
    journal = journal,
    citation_label = shiny_studies_citation_label(authors, year, title),
    collections = as.list(collections),
    languages = as.list(languages),
    engines = engines,
    notes = notes,
    related_upstream = related_up,
    related_downstream = related_down,
    article_url = article_url,
    repo = repo,
    study_url = study_url,
    source_repository = source_repository,
    source_repository_kind = source_kind,
    maintainer_name = index_row_field(row, "maintainer_name", ""),
    maintainer_email = index_row_field(row, "maintainer_email", "")
  )
}

#' Build and write the Shiny Studies cache artifact
#'
#' Writes \code{registry/shiny_studies.json} with one record per study: citation
#' fields, collections, languages/engines, notes flags (data unavailable /
#' missing engine), related upstream/downstream (dois, titles, urls), article
#' and study/repo urls. Intended for the Shiny Studies tab — no live yaml fetch
#' at list time.
#'
#' Called from [build_registry_index()]. Gap flags come from stub
#' \code{notes:} (written by [sync_study_to_registry()]), declared languages
#' (mathematica → missing engine), and the latest audit snapshot when present.
#'
#' @param registry_root Path to the registry repository.
#' @param index Optional index data frame (defaults to compiling from stubs).
#' @param metas Optional list of stub metas aligned with \code{index} rows.
#' @return Invisibly, a list with \code{path}, \code{n}, and \code{cache}.
#'
#' @examples
#' \dontrun{
#' build_shiny_studies_cache("../registry")
#' }
#'
#' @export
build_shiny_studies_cache <- function(
  registry_root,
  index = NULL,
  metas = NULL
) {
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    stop("registry_root not found for shiny studies cache.", call. = FALSE)
  }
  registry_root <- normalizePath(registry_root, winslash = "/", mustWork = FALSE)

  if (is.null(index)) {
    index <- compile_registry_index_from_stubs(registry_root)
  }
  if (is.null(index) || !is.data.frame(index) || nrow(index) == 0L) {
    stop("No studies available to build shiny_studies.json.", call. = FALSE)
  }
  index <- ensure_index_handles(index)

  if (is.null(metas)) {
    studies_dir <- registry_studies_dir(registry_root)
    yml_files <- file.path(studies_dir, paste0(index$folder, ".yml"))
    metas <- lapply(yml_files, function(path) {
      if (!file.exists(path)) {
        return(NULL)
      }
      tryCatch(yaml::read_yaml(path), error = function(e) NULL)
    })
  }

  audit_gap_map <- shiny_studies_gap_map_from_audit(registry_root)

  studies <- lapply(seq_len(nrow(index)), function(i) {
    shiny_studies_record_from_row(
      index[i, , drop = FALSE],
      meta = if (length(metas) >= i) metas[[i]] else NULL,
      index = index,
      audit_gap_map = audit_gap_map
    )
  })

  # Alphabetical by citation surname / year / title (Studies table order)
  ord <- order(
    vapply(studies, function(s) {
      first_author_surname(
        trimws(strsplit(as.character(s$authors %||% ""), ",\\s*")[[1]][[1]] %||% "")
      )
    }, character(1)),
    vapply(studies, function(s) as.character(s$year %||% ""), character(1)),
    vapply(studies, function(s) as.character(s$title %||% ""), character(1))
  )
  studies <- studies[ord]

  cache <- list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    schema_version = 1L,
    n = length(studies),
    studies = studies
  )

  path <- shiny_studies_cache_path(registry_root)
  jsonlite::write_json(
    cache,
    path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  # Invalidate session memo so the next load sees the new file
  rm(list = ls(envir = .shiny_studies_cache_memo), envir = .shiny_studies_cache_memo)

  invisible(list(path = path, n = length(studies), cache = cache))
}

#' File mtime as a character token for memo keys
#' @noRd
shiny_studies_mtime_token <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return("")
  }
  format(file.info(path)$mtime, "%Y-%m-%d %H:%M:%OS", tz = "UTC")
}

#' Load the Shiny Studies cache (session-memoized by file mtime)
#'
#' Prefers a local registry checkout's \code{shiny_studies.json}, then the
#' GitHub raw URL. Memoized in-process keyed by path + mtime so Shiny tab
#' switches do not rebuild.
#'
#' @param registry_root Optional registry root. Defaults to
#'   \code{getOption("replicateEverything.registry_root")} or
#'   [auto_detect_registry_root()].
#' @param force If \code{TRUE}, bypass the session memo.
#' @return List with \code{studies}, \code{n}, \code{generated_at},
#'   \code{schema_version}, and \code{source} / \code{mtime}.
#'
#' @examples
#' \dontrun{
#' cache <- load_shiny_studies_cache()
#' length(cache$studies)
#' }
#'
#' @export
load_shiny_studies_cache <- function(registry_root = NULL, force = FALSE) {
  if (is.null(registry_root) || !nzchar(as.character(registry_root))) {
    registry_root <- getOption("replicateEverything.registry_root", NULL)
  }
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    registry_root <- auto_detect_registry_root()
  }

  local_path <- NULL
  if (!is.null(registry_root) && dir.exists(registry_root)) {
    candidate <- shiny_studies_cache_path(registry_root)
    if (file.exists(candidate)) {
      local_path <- normalizePath(candidate, winslash = "/", mustWork = FALSE)
    }
  }

  memo_key <- if (!is.null(local_path)) {
    paste0("file:", local_path, "@", shiny_studies_mtime_token(local_path))
  } else {
    "remote:github"
  }

  if (!isTRUE(force) && exists(memo_key, envir = .shiny_studies_cache_memo, inherits = FALSE)) {
    return(get(memo_key, envir = .shiny_studies_cache_memo))
  }

  cache <- NULL
  source <- NULL
  mtime <- NULL

  if (!is.null(local_path)) {
    cache <- tryCatch(
      jsonlite::fromJSON(local_path, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(cache)) {
      source <- local_path
      mtime <- shiny_studies_mtime_token(local_path)
    }
  }

  if (is.null(cache)) {
    url <- shiny_studies_cache_url()
    cache <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = FALSE),
      error = function(e) NULL
    )
    if (!is.null(cache)) {
      source <- url
      mtime <- as.character(cache$generated_at %||% "")
    }
  }

  if (is.null(cache) || !is.list(cache$studies)) {
    stop(
      "Could not load shiny_studies.json from the registry. ",
      "Run build_registry_index() / build_shiny_studies_cache() first.",
      call. = FALSE
    )
  }

  cache$source <- source
  cache$mtime <- mtime
  cache$n <- length(cache$studies)
  assign(memo_key, cache, envir = .shiny_studies_cache_memo)
  cache
}

#' Filter / sort studies from the precomputed Shiny cache
#'
#' Trivial collection filter only — no yaml fetch.
#'
#' @param cache Result of [load_shiny_studies_cache()] or
#'   [build_shiny_studies_cache()].
#' @param collection Optional collection tag, or \code{NULL} / empty /
#'   \code{"__all_studies__"} for all.
#' @return List of study records.
#'
#' @examples
#' \dontrun{
#' rows <- studies_table_data(load_shiny_studies_cache(), collection = "APSR")
#' }
#'
#' @export
studies_table_data <- function(cache, collection = NULL) {
  studies <- if (is.list(cache) && !is.null(cache$studies)) {
    cache$studies
  } else if (is.list(cache) && !is.null(cache$cache$studies)) {
    cache$cache$studies
  } else if (is.list(cache) && is.null(names(cache))) {
    cache
  } else {
    list()
  }
  if (!length(studies)) {
    return(list())
  }

  want <- trimws(as.character(collection %||% ""))
  if (
    !nzchar(want) ||
      identical(want, "__all_studies__") ||
      identical(tolower(want), "all studies")
  ) {
    return(studies)
  }

  Filter(function(s) {
    cols <- shiny_studies_collections_vec(s$collections %||% character(0))
    want %in% cols
  }, studies)
}

#' Convert Shiny Studies cache records to an index-like data frame
#'
#' Used by Shiny helpers that still expect index.csv columns (Replicate
#' dropdown, registry_index_row_for, etc.).
#'
#' @param cache Result of [load_shiny_studies_cache()].
#' @return Data frame.
#' @noRd
shiny_studies_as_index_df <- function(cache) {
  studies <- studies_table_data(cache)
  if (!length(studies)) {
    return(ensure_index_handles(data.frame(
      folder = character(0),
      handle = character(0),
      doi = character(0),
      title = character(0),
      journal = character(0),
      year = character(0),
      authors = character(0),
      repo = character(0),
      collections = character(0),
      maintainer_name = character(0),
      maintainer_email = character(0),
      languages = character(0),
      article_url = character(0),
      related_upstream = character(0),
      related_downstream = character(0),
      stringsAsFactors = FALSE
    )))
  }
  rows <- lapply(studies, function(s) {
    engines <- s$engines %||% list()
    langs <- shiny_studies_languages_vec(s$languages %||% character(0))
    if (!length(langs)) {
      langs <- c(
        if (isTRUE(engines$r)) "r",
        if (isTRUE(engines$stata)) "stata",
        if (isTRUE(engines$python)) "python",
        if (isTRUE(engines$mathematica)) "mathematica"
      )
      langs <- unlist(langs)
    }
    data.frame(
      folder = as.character(s$folder %||% ""),
      handle = as.character(s$handle %||% s$folder %||% ""),
      doi = as.character(s$doi %||% ""),
      title = as.character(s$title %||% ""),
      journal = as.character(s$journal %||% ""),
      year = as.character(s$year %||% ""),
      authors = as.character(s$authors %||% ""),
      repo = as.character(s$repo %||% ""),
      collections = paste(
        shiny_studies_collections_vec(s$collections %||% character(0)),
        collapse = "|"
      ),
      maintainer_name = as.character(s$maintainer_name %||% ""),
      maintainer_email = as.character(s$maintainer_email %||% ""),
      languages = paste(langs, collapse = ";"),
      article_url = as.character(s$article_url %||% ""),
      related_upstream = encode_related_keys(
        vapply(s$related_upstream %||% list(), function(x) {
          as.character(x$key %||% "")
        }, character(1))
      ),
      related_downstream = encode_related_keys(
        vapply(s$related_downstream %||% list(), function(x) {
          as.character(x$key %||% "")
        }, character(1))
      ),
      data_unavailable = isTRUE(s$notes$data_unavailable),
      missing_engine = isTRUE(s$notes$missing_engine),
      stringsAsFactors = FALSE
    )
  })
  ensure_index_handles(do.call(rbind, rows))
}

#' Look up one study record in the Shiny Studies cache by DOI / handle / folder
#' @noRd
shiny_studies_find <- function(cache, key) {
  key <- trimws(as.character(key %||% ""))
  if (!nzchar(key)) {
    return(NULL)
  }
  key_norm <- if (grepl("/", key, fixed = TRUE) || grepl("^10\\.", key)) {
    normalize_doi(key)
  } else {
    key
  }
  studies <- studies_table_data(cache)
  for (s in studies) {
    candidates <- c(
      as.character(s$key %||% ""),
      as.character(s$doi %||% ""),
      as.character(s$handle %||% ""),
      as.character(s$folder %||% "")
    )
    candidates <- unique(candidates[nzchar(candidates)])
    if (key %in% candidates || key_norm %in% candidates) {
      return(s)
    }
    if (any(vapply(candidates, function(c) {
      grepl("/", c, fixed = TRUE) && identical(normalize_doi(c), key_norm)
    }, logical(1)))) {
      return(s)
    }
  }
  NULL
}
