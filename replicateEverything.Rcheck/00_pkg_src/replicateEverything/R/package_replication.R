#' Whether replication metadata refers to an installed R package
#'
#' @param meta Parsed replication.yml contents.
#' @return Logical.
#' @keywords internal
is_package_replication <- function(meta) {
  pkg <- meta$paper$package %||% NULL
  !is.null(pkg) && nzchar(as.character(pkg[[1]]))
}

#' Resolve GitHub repo slug for a package-backed replication
#'
#' Used when no local sibling package is found. Set \code{paper.package_repo}
#' or top-level \code{repo} in \code{replication.yml} (GitHub slug, e.g.
#' \code{replicate-anything/rep_10.1371_journal.pone.0278337}).
#'
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character repo slug.
#' @keywords internal
package_repo_slug <- function(meta, ctx) {
  from_meta <- meta$repo %||% meta$paper$package_repo %||% NULL
  if (!is.null(from_meta) && nzchar(as.character(from_meta[[1]]))) {
    return(as.character(from_meta[[1]]))
  }
  ctx$repo
}

#' Git ref for \code{remotes::install_github()}
#'
#' @param meta Parsed replication.yml contents.
#' @return Character branch, tag, or commit.
#' @keywords internal
package_repo_ref <- function(meta) {
  ref <- meta$paper$package_ref %||% meta$package_ref %||% "main"
  as.character(ref[[1]])
}

#' Whether to resolve study packages from sibling monorepo folders
#'
#' Off by default on servers; enable via \code{local.R} or
#' \code{replicateEverything.use_sibling_packages}.
#'
#' @keywords internal
sibling_packages_enabled <- function() {
  isTRUE(getOption("replicateEverything.use_sibling_packages", FALSE)) ||
    isTRUE(getOption("replicate_shiny.use_local_replicate_everything", FALSE))
}

#' Read yaml from an HTTP(S) URL without writing a temp file
#'
#' Avoids \code{download.file()} temp-path failures on some Shiny servers.
#'
#' @param url Character URL.
#' @return Parsed yaml list or \code{NULL}.
#' @keywords internal
read_yaml_url <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(NULL)
  }
  resp <- tryCatch(
    httr::GET(
      url,
      httr::user_agent("replicateEverything"),
      httr::timeout(20)
    ),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) >= 400L) {
    return(NULL)
  }
  txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (length(txt) != 1L || !nzchar(trimws(txt))) {
    return(NULL)
  }
  tryCatch(yaml::read_yaml(text = txt), error = function(e) NULL)
}

#' Read text lines from a local path or HTTP(S) URL
#'
#' @param url Character URL or file path.
#' @return Character vector of lines, or empty if not found.
#' @keywords internal
read_lines_url <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(character(0))
  }
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    if (!file.exists(url)) {
      return(character(0))
    }
    return(readLines(url, warn = FALSE))
  }
  resp <- tryCatch(
    httr::GET(
      url,
      httr::user_agent("replicateEverything"),
      httr::timeout(20)
    ),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) >= 400L) {
    return(character(0))
  }
  txt <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (length(txt) != 1L || !nzchar(txt)) {
    return(character(0))
  }
  strsplit(txt, "\n", fixed = TRUE)[[1]]
}

#' Raw GitHub URLs for a study package R source file
#'
#' @param name Base name without \code{.R} (e.g. \code{make_figure_1}).
#' @param repo GitHub slug.
#' @param ref Git ref.
#' @keywords internal
package_replication_code_urls <- function(name, repo, ref = "main") {
  vapply(
    c(
      paste0("inst/replication_code/", name, ".R"),
      paste0("R/", name, ".R")
    ),
    function(rel) {
      sprintf("https://raw.githubusercontent.com/%s/%s/%s", repo, ref, rel)
    },
    character(1)
  )
}

#' Read study package source from GitHub (no install required)
#'
#' @inheritParams package_replication_code_urls
#' @return Character lines or empty.
#' @keywords internal
read_package_repo_source <- function(name, repo, ref = "main") {
  for (url in package_replication_code_urls(name, repo, ref)) {
    lines <- read_lines_url(url)
    if (length(lines)) {
      return(lines)
    }
  }
  character(0)
}

#' Drop roxygen and export-alias lines from replication source for display
#'
#' @param lines Character vector.
#' @keywords internal
clean_replication_source_lines <- function(lines) {
  if (!length(lines)) {
    return(lines)
  }
  is_roxygen <- grepl("^\\s*#'", lines)
  is_alias <- grepl(
    "^\\s*(make_fig_|make_tab_|format_fig_|format_tab_)\\d+\\s*<-\\s*",
    lines
  )
  lines[!is_roxygen & !is_alias]
}

#' @keywords internal
is_package_dataset_name <- function(name) {
  is.character(name) &&
    length(name) == 1L &&
    nzchar(name) &&
    !grepl("[/\\\\]", name) &&
    !grepl("\\.[a-zA-Z0-9]+$", name)
}

#' Build get_code output for a package-backed study from remote source
#'
#' @param meta Parsed replication metadata (with replications list).
#' @param ctx Paper context.
#' @param what Replication id.
#' @param package R package name.
#' @keywords internal
get_code_from_package_repo <- function(meta, ctx, what, package) {
  entry <- find_replication_entry(meta, what)
  source_name <- entry$make %||% entry$code
  if (is.null(source_name) || !nzchar(source_name)) {
    stop("Replication ", what, " has no make/code entry.", call. = FALSE)
  }

  repo <- package_repo_slug(meta, ctx)
  ref <- package_repo_ref(meta)
  source_lines <- clean_replication_source_lines(
    read_package_repo_source(source_name, repo, ref)
  )
  if (!length(source_lines)) {
    stop(
      "Could not read ", source_name, " from package repo ",
      repo, " (ref: ", ref, "). Tried inst/replication_code/ and R/.",
      call. = FALSE
    )
  }

  header <- c(
    paste0("# Replication: ", what),
    if (!is.null(entry$label) && nzchar(entry$label)) paste0("# ", entry$label) else NULL,
    if (!is.null(entry$description) && nzchar(entry$description)) {
      paste0("# ", entry$description)
    } else {
      NULL
    },
    ""
  )
  header <- header[!vapply(header, is.null, logical(1))]

  deps <- meta$paper$dependencies %||% list()
  dep_lines <- vapply(deps, function(x) {
    pkg <- as.character(x)
    if (length(pkg) != 1L || !nzchar(pkg)) return("")
    paste0("library(", pkg, ")")
  }, character(1))
  dep_lines <- dep_lines[nzchar(dep_lines)]

  setup_lines <- c(
    paste0(
      "library(", package, ")",
      "  # make_*, format_*, helpers, and packaged data"
    ),
    dep_lines,
    ""
  )

  data_names <- entry$data
  data_lines <- character(0)
  if (!is.null(data_names)) {
    if (length(data_names) == 1L && is_package_dataset_name(data_names[[1]])) {
      nm <- data_names[[1]]
      data_lines <- c(paste0(nm, " <- ", package, "::", nm), "")
    } else if (length(data_names) == 1L) {
      data_lines <- c(paste0("# data: ", data_names[[1]]), "")
    } else {
      arg_names <- if (identical(entry$make, "make_table_2")) {
        c("survey", "labels")
      } else {
        as.character(data_names)
      }
      for (i in seq_along(data_names)) {
        data_lines <- c(
          data_lines,
          paste0(arg_names[[i]], " <- ", package, "::", data_names[[i]])
        )
      }
      data_lines <- c(data_lines, "")
    }
  }

  make_fn <- entry$make %||% entry$code
  fmt <- entry$format %||% NULL
  call_line <- if (is.null(data_names)) {
    paste0(make_fn, "()")
  } else if (length(data_names) == 1L && is_package_dataset_name(data_names[[1]])) {
    paste0(make_fn, "(", data_names[[1]], ")")
  } else if (identical(make_fn, "make_table_2")) {
    paste0(
      make_fn,
      "(survey = ", data_names[[1]], ", labels = ", data_names[[2]], ")"
    )
  } else {
    paste0(make_fn, "(", paste(data_names, collapse = ", "), ")")
  }
  run_lines <- c(paste0("obj <- ", call_line))
  if (!is.null(fmt) && nzchar(fmt)) {
    run_lines <- c(run_lines, paste0("obj <- ", fmt, "(obj)"))
  }
  run_lines <- c(run_lines, "obj")

  c(
    header,
    setup_lines,
    data_lines,
    paste0("# --- ", source_name, ".R (from ", repo, ") ---"),
    source_lines,
    "",
    "# --- run (from replication.yml) ---",
    run_lines
  )
}

#' Download a registry or package file to a temp path
#'
#' Uses \code{httr} for HTTP(S) URLs to avoid \code{download.file()} temp-path
#' failures on some Shiny servers.
#'
#' @param url HTTP(S) URL or local path.
#' @return Character path to temp file.
#' @keywords internal
download_registry_file <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("Invalid download URL.", call. = FALSE)
  }
  ext <- tools::file_ext(sub(".*\\.", "", basename(url)))
  if (!nzchar(ext)) {
    ext <- "txt"
  }
  tmp <- tempfile(fileext = paste0(".", ext))
  if (grepl("^https?://", url, ignore.case = TRUE)) {
    resp <- tryCatch(
      httr::GET(
        url,
        httr::user_agent("replicateEverything"),
        httr::timeout(20)
      ),
      error = function(e) NULL
    )
    if (!is.null(resp) && httr::status_code(resp) < 400L) {
      writeBin(httr::content(resp, as = "raw"), tmp)
      return(tmp)
    }
  }
  utils::download.file(url, tmp, quiet = TRUE, mode = "wb")
  tmp
}

#' Raw GitHub URLs for a study package \code{replication.yml}
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch or tag.
#' @return Character vector of raw URLs (tried in order).
#' @keywords internal
package_replication_yaml_urls <- function(repo, ref = "main") {
  unique(c(
    sprintf("https://raw.githubusercontent.com/%s/%s/replication.yml", repo, ref),
    sprintf("https://raw.githubusercontent.com/%s/%s/inst/replication.yml", repo, ref)
  ))
}

#' Convert a raw GitHub URL to a browseable \code{/blob/} link
#'
#' @param url Raw \code{raw.githubusercontent.com} URL.
#' @return Browse URL or original \code{url}.
#' @keywords internal
raw_to_github_browse <- function(url) {
  if (length(url) != 1L || !nzchar(url) || !grepl("^https://raw\\.githubusercontent\\.com/", url)) {
    return(url)
  }
  rest <- sub("^https://raw\\.githubusercontent\\.com/", "", url)
  parts <- strsplit(rest, "/", fixed = TRUE)[[1]]
  if (length(parts) < 4L) {
    return(url)
  }
  paste0(
    "https://github.com/", parts[[1]], "/", parts[[2]],
    "/blob/", parts[[3]], "/",
    paste(parts[-(1:3)], collapse = "/")
  )
}

#' Probe a yaml URL and return a short status string
#'
#' @param url Local path or HTTP(S) URL.
#' @keywords internal
yaml_url_status <- function(url) {
  if (length(url) != 1L || !nzchar(url)) {
    return("empty url")
  }
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    if (!file.exists(url)) {
      return("missing (local file)")
    }
    parsed <- tryCatch(yaml::read_yaml(url), error = function(e) NULL)
    if (is.null(parsed)) {
      return("local file exists but yaml parse failed")
    }
    n <- length(parsed$replications %||% list())
    return(paste0("ok (local file, ", n, " replications)"))
  }
  resp <- tryCatch(
    httr::GET(url, httr::user_agent("replicateEverything"), httr::timeout(15)),
    error = function(e) paste0("error: ", conditionMessage(e))
  )
  if (is.character(resp)) {
    return(resp)
  }
  sc <- httr::status_code(resp)
  if (sc >= 400L) {
    return(paste0("HTTP ", sc))
  }
  parsed <- read_yaml_url(url)
  if (is.null(parsed)) {
    return(paste0("HTTP ", sc, " but yaml parse failed"))
  }
  n <- length(parsed$replications %||% list())
  paste0("ok (HTTP ", sc, ", ", n, " replications)")
}

#' Fetch \code{replication.yml} from a study package GitHub repo
#'
#' Lets the app list tables/figures without installing the package.
#'
#' @param meta Parsed registry stub or package metadata.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Parsed yaml list or \code{NULL}.
#' @keywords internal
fetch_package_replication_yaml <- function(meta, ctx) {
  repo <- package_repo_slug(meta, ctx)
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    return(NULL)
  }
  if (identical(repo, "replicate-anything/registry")) {
    return(NULL)
  }
  ref <- package_repo_ref(meta)
  for (meta_url in package_replication_yaml_urls(repo, ref)) {
    parsed <- read_yaml_url(meta_url)
    if (!is.null(parsed)) {
      return(parsed)
    }
  }
  NULL
}

#' Report where the replication index was sought (for debugging Shiny)
#'
#' When a package-backed study lists no tables/figures, this shows which
#' \code{replication.yml} URLs were checked. The study index should come from
#' the package repo (e.g.
#' \code{replicate-anything/rep_10.1371_journal.pone.0278337}), not only the
#' registry stub under \code{papers/<folder>/}.
#'
#' @param doi Character DOI.
#' @param repo Optional registry repo slug from \code{index.csv}.
#' @param folder Optional registry folder name.
#' @return A list with \code{registry_sources}, \code{package_sources}, etc.
#'
#' @examples
#' \dontrun{
#' replication_index_diagnostics("10.1177/00491241211036161")
#' }
#'
#' @export
replication_index_diagnostics <- function(doi, repo = NULL, folder = NULL) {
  doi <- normalize_doi(doi)
  ctx <- paper_context(doi, repo = repo, folder = folder)

  source_entry <- function(label, url) {
    list(
      label = label,
      url = url,
      browse_url = if (grepl("^https?://", url)) raw_to_github_browse(url) else url,
      status = yaml_url_status(url)
    )
  }

  registry_sources <- list()
  if (!is.null(ctx$local_root)) {
    registry_sources[[length(registry_sources) + 1L]] <- source_entry(
      "local registry stub",
      file.path(ctx$local_root, "replication.yml")
    )
  }
  registry_raw <- paste0(ctx$base_url, "/replication.yml")
  registry_sources[[length(registry_sources) + 1L]] <- source_entry(
    "registry stub (GitHub)",
    registry_raw
  )

  stub <- NULL
  for (src in registry_sources) {
    if (grepl("^ok", src$status)) {
      if (grepl("^https?://", src$url)) {
        stub <- read_yaml_url(src$url)
      } else if (file.exists(src$url)) {
        stub <- tryCatch(yaml::read_yaml(src$url), error = function(e) NULL)
      }
      if (!is.null(stub)) {
        break
      }
    }
  }
  if (is.null(stub)) {
    stub <- read_yaml_url(registry_raw)
  }

  package_sources <- list()
  package_repo <- NULL
  package_ref <- "main"
  replications_found <- 0L
  is_package_study <- !is.null(stub) && is_package_replication(stub)

  if (is_package_study) {
    package_repo <- package_repo_slug(stub, ctx)
    package_ref <- package_repo_ref(stub)
    for (pkg_url in package_replication_yaml_urls(package_repo, package_ref)) {
      package_sources[[length(package_sources) + 1L]] <- source_entry(
        "study package replication.yml",
        pkg_url
      )
    }
    pkg_meta <- fetch_package_replication_yaml(stub, ctx)
    if (!is.null(pkg_meta)) {
      replications_found <- length(pkg_meta$replications %||% list())
    }
  } else if (!is.null(stub)) {
    replications_found <- length(stub$replications %||% list())
  }

  list(
    doi = doi,
    folder = ctx$folder,
    registry_repo = ctx$repo,
    package_repo = package_repo,
    package_ref = package_ref,
    is_package_study = is_package_study,
    replications_found = replications_found,
    registry_sources = registry_sources,
    package_sources = package_sources
  )
}

#' Folder names to check when locating a sibling replication package
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Character vector of folder names (no duplicates).
#' @keywords internal
package_folder_candidates <- function(package, meta, ctx) {
  explicit <- c(
    meta$paper$package_folder %||% NULL,
    meta$paper$package_path %||% NULL,
    meta$package_folder %||% NULL
  )
  explicit <- vapply(explicit, function(x) {
    if (is.null(x)) return("")
    as.character(x[[1]])
  }, character(1))
  explicit <- explicit[nzchar(explicit)]

  derived <- character(0)
  if (!is.null(ctx$folder) && nzchar(ctx$folder)) {
    derived <- c(
      paste0("rep_", ctx$folder),
      ctx$folder
    )
  }

  unique(c(explicit, derived))
}

#' Resolve a local path to a study replication package
#'
#' Search order:
#' \enumerate{
#'   \item Explicit path in \code{paper.package_path} (if it exists)
#'   \item \code{getOption("replicateEverything.replication_packages")} map
#'   \item Sibling folders under \code{replication_packages_root} or monorepo root
#' }
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @return Normalized path, or \code{NULL}.
#' @keywords internal
resolve_replication_package_path <- function(package, meta, ctx) {
  explicit_path <- meta$paper$package_path %||% NULL
  if (!is.null(explicit_path) && nzchar(as.character(explicit_path[[1]]))) {
    path <- as.character(explicit_path[[1]])
    if (dir.exists(path) && package_desc_matches(path, package)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  pkg_map <- getOption("replicateEverything.replication_packages", NULL)
  if (!is.null(pkg_map) && !is.null(pkg_map[[package]])) {
    path <- pkg_map[[package]]
    if (dir.exists(path) && package_desc_matches(path, package)) {
      return(normalizePath(path, winslash = "/", mustWork = FALSE))
    }
  }

  if (!sibling_packages_enabled()) {
    return(NULL)
  }

  roots <- c(
    getOption("replicateEverything.replication_packages_root", NULL),
    sibling_monorepo_root()
  )
  roots <- unique(roots[!vapply(roots, is.null, logical(1))])
  roots <- roots[dir.exists(roots)]

  folders <- package_folder_candidates(package, meta, ctx)
  for (root in roots) {
    for (folder in folders) {
      candidate <- file.path(root, folder)
      if (package_desc_matches(candidate, package)) {
        return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
      }
    }
  }

  NULL
}

#' @keywords internal
package_desc_matches <- function(path, pkg_name) {
  desc_path <- file.path(path, "DESCRIPTION")
  if (!file.exists(desc_path)) {
    return(FALSE)
  }
  desc <- tryCatch(
    read.dcf(desc_path),
    error = function(e) NULL
  )
  !is.null(desc) &&
    nrow(desc) >= 1 &&
    identical(as.character(desc[1, "Package"]), pkg_name)
}

#' Parent directory of the registry when developing in a monorepo
#'
#' @return Character path or \code{NULL}.
#' @keywords internal
sibling_monorepo_root <- function() {
  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    return(NULL)
  }
  normalizePath(file.path(registry_root, ".."), winslash = "/", mustWork = FALSE)
}

#' SHA recorded for a package installed from GitHub
#'
#' @param package Installed package name.
#' @return Character SHA or \code{NA_character_}.
#' @keywords internal
installed_package_remote_sha <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    return(NA_character_)
  }
  desc <- tryCatch(
    utils::packageDescription(package),
    error = function(e) NULL
  )
  if (is.null(desc)) {
    return(NA_character_)
  }
  sha <- desc$RemoteSha %||% NA_character_
  if (length(sha) != 1L || !nzchar(sha)) {
    return(NA_character_)
  }
  as.character(sha)
}

#' Latest commit SHA for a GitHub repo ref
#'
#' Uses the GitHub REST API (not \code{remotes}) so version checks work on
#' servers where \code{remotes::remote_sha()} fails on temp paths.
#'
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
github_remote_sha <- function(repo, ref = "main") {
  if (length(repo) != 1L || is.na(repo) || !nzchar(repo)) {
    return(NA_character_)
  }
  if (length(ref) != 1L || is.na(ref) || !nzchar(ref)) {
    ref <- "main"
  }
  cache_key <- paste(repo, ref, sep = "@")
  if (exists(cache_key, envir = .github_remote_sha_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .github_remote_sha_cache))
  }
  repo <- gsub("^/", "", as.character(repo))
  ref <- as.character(ref)
  url <- sprintf(
    "https://api.github.com/repos/%s/commits/%s",
    repo,
    utils::URLencode(ref, reserved = TRUE)
  )
  resp <- tryCatch(
    httr::GET(
      url,
      httr::user_agent("replicateEverything"),
      httr::timeout(15)
    ),
    error = function(e) NULL
  )
  if (is.null(resp) || httr::status_code(resp) >= 400L) {
    return(NA_character_)
  }
  parsed <- tryCatch(
    httr::content(resp, as = "parsed", type = "application/json"),
    error = function(e) NULL
  )
  if (is.null(parsed) || is.null(parsed$sha) || !nzchar(parsed$sha)) {
    return(NA_character_)
  }
  sha <- as.character(parsed$sha)
  assign(cache_key, sha, envir = .github_remote_sha_cache)
  sha
}

#' @keywords internal
.github_remote_sha_cache <- new.env(parent = emptyenv())

#' Whether an installed package lags the GitHub ref
#'
#' @param package Installed package name.
#' @param repo GitHub slug \code{org/repo}.
#' @param ref Branch, tag, or commit.
#' @keywords internal
github_package_outdated <- function(package, repo, ref = "main") {
  tryCatch({
    if (!requireNamespace(package, quietly = TRUE)) {
      return(TRUE)
    }
    local_sha <- installed_package_remote_sha(package)
    if (is.na(local_sha)) {
      return(TRUE)
    }
    remote_sha <- github_remote_sha(repo, ref)
    if (is.na(remote_sha) || !nzchar(remote_sha)) {
      return(FALSE)
    }
    !identical(local_sha, remote_sha)
  }, error = function(e) {
    warning(
      "Could not compare installed ", package, " with GitHub (", repo, "@", ref, "): ",
      conditionMessage(e),
      call. = FALSE
    )
    FALSE
  })
}

#' Install or upgrade a study package from GitHub
#'
#' @param package R package name.
#' @param repo GitHub slug.
#' @param ref Git ref.
#' @keywords internal
install_replication_package_github <- function(package, repo, ref = "main") {
  if (!requireNamespace("remotes", quietly = TRUE)) {
    stop(
      "Package remotes is required to install ", package,
      " from GitHub (", repo, ").",
      call. = FALSE
    )
  }
  spec <- paste0(repo, "@", ref)
  message("Installing ", package, " from GitHub (", spec, ") ...")
  remotes::install_github(
    spec,
    upgrade = "always",
    quiet = TRUE,
    args = "--no-test-load"
  )
  invisible(TRUE)
}

#' @keywords internal
try_install_replication_package_github <- function(package, repo, ref = "main") {
  tryCatch(
    {
      install_replication_package_github(package, repo, ref)
      requireNamespace(package, quietly = TRUE)
    },
    error = function(e) {
      warning(
        "Could not install ", package, " from GitHub (", repo, "@", ref, "): ",
        conditionMessage(e),
        call. = FALSE
      )
      FALSE
    }
  )
}

#' Load or install a study replication package
#'
#' Tries, in order: local sibling package (when configured), installed package
#' (upgrade from GitHub when outdated), then fresh GitHub install from
#' \code{package_repo_slug()}.
#'
#' @param package R package name.
#' @param meta Parsed replication.yml contents.
#' @param ctx Paper context from \code{paper_context()}.
#' @keywords internal
ensure_replication_package <- function(package, meta = NULL, ctx = NULL) {
  if (requireNamespace(package, quietly = TRUE)) {
    if (!is.null(meta) && !is.null(ctx)) {
      repo <- package_repo_slug(meta, ctx)
      ref <- package_repo_ref(meta)
      if (github_package_outdated(package, repo, ref)) {
        ok <- try_install_replication_package_github(package, repo, ref)
        return(invisible(isTRUE(ok) || requireNamespace(package, quietly = TRUE)))
      }
    }
    return(invisible(TRUE))
  }

  local_path <- resolve_replication_package_path(package, meta, ctx)
  if (!is.null(local_path)) {
    ok <- tryCatch(
      {
        load_replication_package_path(local_path, package)
        requireNamespace(package, quietly = TRUE)
      },
      error = function(e) {
        warning(
          "Could not load local replication package at ", local_path, ": ",
          conditionMessage(e),
          call. = FALSE
        )
        FALSE
      }
    )
    if (isTRUE(ok)) {
      return(invisible(TRUE))
    }
  }

  if (!is.null(meta) && !is.null(ctx)) {
    repo <- package_repo_slug(meta, ctx)
    ref <- package_repo_ref(meta)
    needs_update <- github_package_outdated(package, repo, ref)
    if (needs_update) {
      ok <- try_install_replication_package_github(package, repo, ref)
      if (isTRUE(ok)) {
        return(invisible(TRUE))
      }
    }
  }

  if (requireNamespace(package, quietly = TRUE)) {
    return(invisible(TRUE))
  }

  if (is.null(meta) || is.null(ctx)) {
    warning(
      "Replication package ", package,
      " is not installed and no local sibling was found.",
      call. = FALSE
    )
    return(invisible(FALSE))
  }

  repo <- package_repo_slug(meta, ctx)
  ref <- package_repo_ref(meta)
  ok <- try_install_replication_package_github(package, repo, ref)
  if (!isTRUE(ok) && !requireNamespace(package, quietly = TRUE)) {
    warning(
      "Could not install replication package ", package,
      " from ", repo, " (ref: ", ref, ").",
      call. = FALSE
    )
    return(invisible(FALSE))
  }
  invisible(TRUE)
}

#' Load a package from a local source tree
#'
#' @param path Path to package root (contains DESCRIPTION).
#' @param package Expected package name.
#' @keywords internal
load_replication_package_path <- function(path, package) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !dir.exists(path)) {
    stop("Invalid replication package path.", call. = FALSE)
  }
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(path, quiet = TRUE)
    return(invisible(TRUE))
  }
  if (requireNamespace("remotes", quietly = TRUE)) {
    remotes::install_local(
      path,
      upgrade = "never",
      quiet = TRUE,
      args = "--no-test-load"
    )
    return(invisible(TRUE))
  }
  stop(
    "Found local replication package at ", path,
    " but need devtools or remotes to load it.",
    call. = FALSE
  )
}

#' Call a function from a study replication package
#'
#' @param package Package name.
#' @param fn Function name as string.
#' @param ... Arguments passed to the function.
#' @keywords internal
call_replication_package <- function(package, fn, ...) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop("Replication package ", package, " is not installed.", call. = FALSE)
  }
  fun <- get(fn, envir = asNamespace(package))
  fun(...)
}
