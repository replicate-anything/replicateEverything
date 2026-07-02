library(shiny)
library(bslib)
library(htmltools)

REGISTRY_INDEX_URL <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.csv"
REGISTRY_GITHUB <- "https://github.com/replicate-anything/registry"
ORG_GITHUB <- "https://github.com/orgs/replicate-anything/repositories"
PKGDOCS_URL <- "https://replicate-anything.github.io/replicateEverything/index.html"
LIVE_DEMO_URL <- "https://shiny2.wzb.eu/ipi/replicate/"
DEFAULT_REGISTRY_REPO <- "replicate-anything/registry"

registry_stub_yaml_url <- function(folder, repo = DEFAULT_REGISTRY_REPO) {
  sprintf("https://raw.githubusercontent.com/%s/main/papers/%s.yml", repo, folder)
}
APP_HEX_LOGO <- "logo-hex.png"

app_favicon_tags <- function() {
  tagList(
    tags$link(rel = "icon", href = "favicon/favicon.ico", sizes = "any"),
    tags$link(rel = "icon", href = "favicon/favicon.svg", type = "image/svg+xml"),
    tags$link(rel = "icon", href = "favicon/favicon-96x96.png", sizes = "96x96", type = "image/png"),
    tags$link(rel = "apple-touch-icon", href = "favicon/apple-touch-icon.png"),
    tags$link(rel = "manifest", href = "favicon/site.webmanifest")
  )
}

app_brand_title <- function() {
  tags$span(
    class = "app-brand d-inline-flex align-items-center",
    tags$img(
      src = APP_HEX_LOGO,
      height = "32",
      width = "auto",
      alt = "",
      class = "app-brand-icon me-2"
    ),
    "Replicate Everything"
  )
}

app_welcome_intro <- function() {
  tags$div(
    class = "welcome-intro",
    tags$div(
      class = "welcome-intro-layout",
      tags$img(
        src = APP_HEX_LOGO,
        alt = "Replicate Everything",
        class = "welcome-logo"
      ),
      tags$div(
        class = "welcome-copy",
        p(
          "This app lets you browse replication materials for published studies, ",
          "view precomputed tables and figures, and run live replications on demand."
        ),
        p(
          "Choose a study, then click ",
          strong("Display"),
          " for a precomputed result or ",
          strong("Run"),
          " to rerun the analysis in R."
        )
      )
    )
  )
}

#' Use a sibling registry/ package when developing in the monorepo;
#' otherwise fall back to GitHub (production default).
configure_registry_source <- function() {
  if (file.exists("local.R")) {
    source("local.R", local = FALSE)
    return(invisible(TRUE))
  }

  sibling_root <- normalizePath(file.path(".."), winslash = "/", mustWork = FALSE)
  sibling_registry <- file.path(sibling_root, "registry")
  sibling_pkg <- file.path(sibling_root, "replicateEverything")

  if (dir.exists(sibling_registry) && file.exists(file.path(sibling_registry, "index.csv"))) {
    options(
      replicateEverything.registry_root = sibling_registry,
      replicateEverything.index = utils::read.csv(
        file.path(sibling_registry, "index.csv"),
        stringsAsFactors = FALSE
      )
    )
    message("Replicate Everything: using local registry at ", sibling_registry)
  } else {
    message("Replicate Everything: using remote registry on GitHub")
  }

  if (dir.exists(sibling_pkg) && requireNamespace("devtools", quietly = TRUE)) {
    options(
      replicateEverything.use_sibling_packages = TRUE,
      replicateEverything.replication_packages_root = sibling_root
    )
    devtools::load_all(sibling_pkg, quiet = TRUE)
    options(replicate_shiny.use_local_replicate_everything = TRUE)
    if (exists("load_sibling_replication_packages", envir = asNamespace("replicateEverything"), inherits = FALSE)) {
      get("load_sibling_replication_packages", envir = asNamespace("replicateEverything"))(sibling_root)
    }
    message("Replicate Everything: using local package at ", sibling_pkg)
  }

  invisible(TRUE)
}

configure_registry_source()

using_local_replicate_everything <- function() {
  isTRUE(getOption("replicate_shiny.use_local_replicate_everything", FALSE))
}

ensure_replicate_everything <- function() {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    stop(
      "replicateEverything is not installed. Install from GitHub, then restart:\n",
      "  remotes::install_github('replicate-anything/replicateEverything')",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

ensure_study_replication_package <- function(doi, folder = NULL, repo = NULL) {
  if (isFALSE(getOption("replicate_shiny.auto_install_study_packages", TRUE))) {
    return(invisible(FALSE))
  }
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    return(invisible(FALSE))
  }
  ns <- asNamespace("replicateEverything")
  meta <- tryCatch(
    do.call(get("get_replication_meta", envir = ns), list(doi, repo = repo, folder = folder)),
    error = function(e) NULL
  )
  if (is.null(meta) || !isTRUE(do.call(get("is_package_replication", envir = ns), list(meta)))) {
    return(invisible(FALSE))
  }
  pkg <- as.character(meta$paper$package[[1]])
  ctx <- do.call(get("paper_context", envir = ns), list(doi, repo = repo, folder = folder))
  ok <- tryCatch(
    do.call(get("ensure_replication_package", envir = ns), list(pkg, meta = meta, ctx = ctx)),
    error = function(e) {
      warning(
        "Could not prepare study package ", pkg, ": ",
        conditionMessage(e),
        call. = FALSE
      )
      FALSE
    }
  )
  invisible(isTRUE(ok))
}

#' Call a replicateEverything function even if not yet exported (older installs).
replicate_fn <- function(name, ..., folder = NULL, repo = NULL) {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    stop("replicateEverything is not installed.", call. = FALSE)
  }
  ns <- asNamespace("replicateEverything")
  fn <- get(name, envir = ns)
  args <- list(...)
  fm <- names(formals(fn))
  if ("folder" %in% fm && !is.null(folder) && nzchar(folder)) {
    args$folder <- folder
  }
  if ("repo" %in% fm && !is.null(repo) && nzchar(repo)) {
    args$repo <- repo
  }
  do.call(fn, args)
}

ensure_replicate_everything()

`%||%` <- function(a, b) if (is.null(a)) b else a

is_figure_replication <- function(type) {
  identical(as.character(type), "figure")
}

is_table_replication <- function(type) {
  identical(as.character(type), "table")
}

is_artifact_source <- function(source) {
  identical(as.character(source), "artifact")
}

is_live_source <- function(source) {
  identical(as.character(source), "live")
}

replication_source_label <- function(source) {
  if (is_artifact_source(source)) {
    "Showing precomputed result."
  } else if (is_live_source(source)) {
    "Showing live replication (no precomputed artifact, or Run was clicked)."
  } else {
    "Showing replication output."
  }
}

github_repo_browse_url <- function(repo_slug, subpath = NULL) {
  base <- paste0("https://github.com/", repo_slug)
  if (!is.null(subpath) && nzchar(subpath)) {
    paste0(base, "/tree/main/", subpath)
  } else {
    paste0(base, "/tree/main")
  }
}

study_materials_info <- function(doi, folder = NULL, repo = NULL) {
  meta <- tryCatch(
    replicate_fn("get_replication_meta", doi, repo = repo, folder = folder),
    error = function(e) NULL
  )
  if (is.null(meta)) {
    return(NULL)
  }
  ctx <- replicate_fn("paper_context", doi, repo = repo, folder = folder)

  if (isTRUE(replicate_fn("is_package_replication", meta))) {
    slug <- replicate_fn("package_repo_slug", meta, ctx)
    return(list(
      type = "Package-backed study",
      repo = slug,
      url = github_repo_browse_url(slug)
    ))
  }

  if (isTRUE(replicate_fn("is_folder_study_replication", meta, ctx))) {
    slug <- replicate_fn("study_repo_slug", meta, ctx)
    return(list(
      type = "Folder-backed study",
      repo = slug,
      url = github_repo_browse_url(slug)
    ))
  }

  NULL
}

study_materials_summary_ui <- function(doi, folder = NULL, repo = NULL) {
  info <- study_materials_info(doi, folder = folder, repo = repo)
  if (is.null(info)) {
    return(NULL)
  }
  tags$p(
    class = "mb-0",
    strong("Replication type: "),
    info$type,
    br(),
    strong("Study materials: "),
    tags$a(href = info$url, target = "_blank", rel = "noopener", info$repo)
  )
}

artifact_missing <- function(result) {
  replicate_fn("artifact_display_missing", result)
}

artifact_missing_ui <- function(doi, what, folder = NULL, repo = NULL, kind = "output") {
  candidates <- tryCatch(
    replicate_fn("artifact_lookup_candidates", doi, what, folder = folder, repo = repo),
    error = function(e) character(0)
  )
  tagList(
    tags$div(
      class = "alert alert-secondary",
      tags$strong(paste0("No precomputed ", kind, " available.")),
      tags$p(
        "The registry lists this replication, but the artifact file is not available yet.",
        " Click ", tags$strong("Run"), " to generate it live."
      ),
      tags$p(
        class = "small mb-0",
        "Registry papers: build ", tags$code("artifacts/"), " with ",
        tags$code("registry/scripts/build_artifacts.R"), ". ",
        "Package-backed studies: run ", tags$code("build_report()"), " in the study R package ",
        "(writes ", tags$code("inst/report/artifacts/"), ")."
      ),
      if (length(candidates) > 0) {
        tagList(
          tags$p(class = "mb-1", tags$strong("Checked:")),
          tags$ul(
            class = "small mb-0",
            lapply(head(candidates, 6), function(path) {
              tags$li(tags$code(path))
            })
          )
        )
      }
    )
  )
}

load_registry_index <- function() {
  df <- tryCatch({
    idx <- replicateEverything::load_index()
    idx$doi <- replicateEverything::normalize_doi(idx$doi)
    if (!"repo" %in% names(idx)) idx$repo <- DEFAULT_REGISTRY_REPO
    idx
  }, error = function(e) NULL)

  if (!is.null(df) && "folder" %in% names(df)) return(df)

  tryCatch({
    df <- utils::read.csv(REGISTRY_INDEX_URL, stringsAsFactors = FALSE)
    df$doi <- replicateEverything::normalize_doi(df$doi)
    df$repo <- DEFAULT_REGISTRY_REPO
    df
  }, error = function(e) NULL)
}

registry_index <- load_registry_index()

nice_doi_choices <- function(index_df) {
  if (is.null(index_df) || nrow(index_df) == 0) return(character(0))
  idx <- index_df[nzchar(index_df$doi), , drop = FALSE]
  setNames(
    idx$doi,
    paste0(truncate_label(idx$title, 25L), " (", idx$year, ")")
  )
}

truncate_label <- function(text, max_chars = 25L) {
  text <- trimws(as.character(text))
  if (length(text) != 1L || !nzchar(text) || nchar(text) <= max_chars) {
    return(text)
  }
  cut <- substr(text, 1, max_chars)
  if (grepl(" ", cut, fixed = TRUE)) {
    cut <- sub(" +[^ ]*$", "", cut)
    if (!nzchar(cut)) {
      cut <- substr(text, 1, max_chars)
    }
  }
  paste0(cut, "...")
}

engine_icon_r <- function() {
  tags$svg(
    xmlns = "http://www.w3.org/2000/svg",
    viewBox = "0 0 24 24",
    width = "18",
    height = "18",
    `aria-hidden` = "true",
    tags$circle(cx = "12", cy = "12", r = "11", fill = "#276DC3"),
    tags$text(
      x = "12.5", y = "16.5", `text-anchor` = "middle",
      fill = "#ffffff", `font-size` = "13", `font-weight` = "700",
      `font-family` = "Georgia, serif"
    , "R")
  )
}

engine_icon_stata <- function() {
  tags$svg(
    xmlns = "http://www.w3.org/2000/svg",
    viewBox = "0 0 24 24",
    width = "18",
    height = "18",
    `aria-hidden` = "true",
    tags$rect(x = "1.5", y = "4", width = "21", height = "16", rx = "2.5", fill = "#0054A4"),
    tags$text(
      x = "12", y = "15.5", `text-anchor` = "middle",
      fill = "#ffffff", `font-size` = "7.5", `font-weight` = "700",
      `font-family` = "Arial, sans-serif"
    , "Stata")
  )
}

engine_toggle_ui <- function() {
  tags$div(
    class = "engine-toggle-wrap is-hidden",
    id = "engine_toggle_wrap",
    tags$div(
      class = "engine-toggle",
      role = "group",
      `aria-label` = "Replication engine",
      tags$span(class = "engine-toggle-icon engine-toggle-r", title = "R", engine_icon_r()),
      tags$div(
        class = "engine-toggle-switch-wrap",
        checkboxInput("global_engine_stata", label = NULL, value = FALSE)
      ),
      tags$span(class = "engine-toggle-icon engine-toggle-stata", title = "Stata", engine_icon_stata())
    )
  )
}

replication_stub_label <- function(type, id) {
  prefix <- switch(as.character(type), figure = "Fig", table = "Table", "Item")
  num <- sub("^[^0-9]*([0-9]+).*", "\\1", as.character(id))
  if (!nzchar(num)) {
    num <- as.character(id)
  }
  paste0(prefix, " ", num)
}

replication_display_label <- function(x) {
  stub <- replication_stub_label(x$type, x$id)
  desc <- x$description %||% NULL
  if (is.null(desc) || length(desc) == 0) {
    return(stub)
  }
  desc <- trimws(as.character(desc[[1]]))
  if (!nzchar(desc)) {
    return(stub)
  }
  paste0(stub, ": ", desc)
}

replications_to_df <- function(reps) {
  if (is.null(reps) || length(reps) == 0) return(NULL)
  reps <- reps[vapply(reps, function(x) {
    is.list(x) && !is.null(x$id) && nzchar(as.character(x$id[[1]] %||% x$id))
  }, logical(1))]
  reps <- reps[vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    type %in% c("figure", "table")
  }, logical(1))]
  if (length(reps) == 0) return(NULL)

  rep_engine <- function(x) {
    eng <- tolower(as.character(x$engine %||% ""))
    if (identical(eng, "stata")) return("stata")
    if (identical(eng, "r")) return("r")
    if (grepl("_stata$", as.character(x$id), ignore.case = TRUE)) return("stata")
    if (grepl("\\.do$", as.character(x$code %||% ""), ignore.case = TRUE)) return("stata")
    "r"
  }

  rep_group <- function(x) {
    grp <- as.character(x$group %||% "")
    if (nzchar(grp)) return(grp)
    as.character(x$id)
  }

  groups <- unique(vapply(reps, rep_group, character(1)))
  rows <- lapply(groups, function(group) {
    group_reps <- reps[vapply(reps, function(x) identical(rep_group(x), group), logical(1))]
    r_reps <- group_reps[vapply(group_reps, function(x) identical(rep_engine(x), "r"), logical(1))]
    stata_reps <- group_reps[vapply(group_reps, function(x) identical(rep_engine(x), "stata"), logical(1))]
    primary <- if (length(r_reps)) r_reps[[1]] else group_reps[[1]]
    data.frame(
      group = group,
      id = as.character(primary$id),
      r_id = if (length(r_reps)) as.character(r_reps[[1]]$id) else NA_character_,
      stata_id = if (length(stata_reps)) as.character(stata_reps[[1]]$id) else NA_character_,
      label = truncate_label(replication_display_label(primary), 25L),
      label_full = replication_display_label(primary),
      type = as.character(primary$type),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

resolve_group_replication_id <- function(row, engine = c("r", "stata")) {
  engine <- match.arg(engine)
  if (engine == "stata" && !is.na(row$stata_id) && nzchar(row$stata_id)) {
    return(row$stata_id)
  }
  if (engine == "r" && !is.na(row$r_id) && nzchar(row$r_id)) {
    return(row$r_id)
  }
  row$id
}

first_author_surname <- function(name) {
  parts <- strsplit(trimws(name), "\\s+")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) == 0) return("Unknown")
  if (length(parts) >= 4 || (length(parts) >= 3 && grepl("\\.", parts[length(parts) - 1]))) {
    paste(tail(parts, 2), collapse = " ")
  } else {
    parts[[length(parts)]]
  }
}

format_author_label <- function(authors_str) {
  authors <- trimws(strsplit(authors_str %||% "", ",\\s*")[[1]])
  authors <- authors[nzchar(authors)]
  if (length(authors) == 0) return("Unknown")
  lead <- first_author_surname(authors[[1]])
  if (length(authors) == 1) return(lead)
  if (length(authors) == 2) {
    return(paste0(lead, " and ", first_author_surname(authors[[2]])))
  }
  paste0(lead, " et al")
}

format_authors_summary <- function(authors_str) {
  authors <- trimws(strsplit(authors_str %||% "", ",\\s*")[[1]])
  authors <- authors[nzchar(authors)]
  n <- length(authors)
  if (n == 0) return("Unknown")
  if (n > 4L) {
    return(paste0(paste(head(authors, 4L), collapse = ", "), ", et al."))
  }
  if (n == 1L) return(authors[[1]])
  if (n == 2L) return(paste(authors, collapse = " and "))
  paste0(paste(head(authors, n - 1L), collapse = ", "), ", and ", authors[[n]])
}

truncate_title <- function(title, max_chars = 52) {
  title <- trimws(title %||% "")
  if (nchar(title) <= max_chars) return(title)
  paste0(substr(title, 1, max_chars - 3), "...")
}

strip_html_entities <- function(x) {
  x <- gsub("&amp;", "&", x %||% "", fixed = TRUE)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  trimws(x)
}

format_study_citation <- function(row) {
  author <- format_author_label(row$authors[[1]])
  year <- row$year[[1]] %||% ""
  title <- truncate_title(row$title[[1]])
  journal <- strip_html_entities(row$journal[[1]])
  list(
    line1 = sprintf('%s (%s) "%s"', author, year, title),
    line2 = if (nzchar(journal)) journal else ""
  )
}

studies_for_bibliography <- function(index_df) {
  if (is.null(index_df) || nrow(index_df) == 0) return(index_df)
  order(
    vapply(strsplit(index_df$authors, ",\\s*"), function(x) {
      first_author_surname(trimws(x[[1]] %||% ""))
    }, character(1)),
    index_df$year,
    index_df$title
  )
}

registry_row_for <- function(doi, index_df = registry_index) {
  if (is.null(index_df) || !"doi" %in% names(index_df)) {
    return(list(folder = NULL, repo = DEFAULT_REGISTRY_REPO))
  }
  row <- index_df[index_df$doi == doi, , drop = FALSE]
  list(
    folder = if (nrow(row) > 0 && "folder" %in% names(row)) row$folder[[1]] else NULL,
    repo = if (nrow(row) > 0 && "repo" %in% names(row)) row$repo[[1]] else DEFAULT_REGISTRY_REPO
  )
}

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

package_replication_yaml_urls <- function(repo, ref = "main") {
  unique(c(
    sprintf("https://raw.githubusercontent.com/%s/%s/replication.yml", repo, ref),
    sprintf("https://raw.githubusercontent.com/%s/%s/inst/replication.yml", repo, ref)
  ))
}

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

read_yaml_from_url <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(NULL)
  }
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    if (!file.exists(url)) {
      return(NULL)
    }
    return(tryCatch(yaml::read_yaml(url), error = function(e) NULL))
  }
  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    ns <- asNamespace("replicateEverything")
    if (exists("read_yaml_url", envir = ns, inherits = FALSE)) {
      parsed <- tryCatch(get("read_yaml_url", envir = ns)(url), error = function(e) NULL)
      if (!is.null(parsed)) {
        return(parsed)
      }
    }
  }
  tryCatch({
    con <- url(url, open = "rb")
    on.exit(close(con), add = TRUE)
    txt <- readLines(con, warn = FALSE, encoding = "UTF-8")
    if (!length(txt)) {
      return(NULL)
    }
    yaml::read_yaml(text = paste(txt, collapse = "\n"))
  }, error = function(e) NULL)
}

read_lines_from_url <- function(url) {
  if (length(url) != 1L || is.na(url) || !nzchar(url)) {
    return(character(0))
  }
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    if (!file.exists(url)) {
      return(character(0))
    }
    return(readLines(url, warn = FALSE))
  }
  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    ns <- asNamespace("replicateEverything")
    if (exists("read_lines_url", envir = ns, inherits = FALSE)) {
      lines <- tryCatch(get("read_lines_url", envir = ns)(url), error = function(e) character(0))
      if (length(lines)) {
        return(lines)
      }
    }
  }
  tryCatch({
    con <- url(url, open = "rb")
    on.exit(close(con), add = TRUE)
    readLines(con, warn = FALSE, encoding = "UTF-8")
  }, error = function(e) character(0))
}

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
  parsed <- read_yaml_from_url(url)
  if (is.null(parsed)) {
    return("could not read or parse yaml from url")
  }
  n <- length(parsed$replications %||% list())
  paste0("ok (", n, " replications in yaml)")
}

replication_display_count <- function(reps) {
  if (is.null(reps) || !length(reps)) {
    return(0L)
  }
  sum(vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    type %in% c("figure", "table")
  }, logical(1)))
}

fetch_study_replications_index <- function(folder, repo = DEFAULT_REGISTRY_REPO) {
  registry_url <- registry_stub_yaml_url(folder, DEFAULT_REGISTRY_REPO)
  stub <- read_yaml_from_url(registry_url)
  if (is.null(stub)) {
    stop("Could not read registry stub at ", registry_url, call. = FALSE)
  }

  reps <- stub$replications %||% list()
  if (length(reps) > 0) {
    return(c(stub$prep %||% list(), reps))
  }

  is_package_study <- !is.null(stub$paper$package) &&
    nzchar(as.character(stub$paper$package[[1]] %||% ""))
  is_folder_study <- !is_package_study && (
    identical(as.character(stub$paper$materials %||% ""), "folder") ||
      {
        study_repo <- stub$repo %||% stub$paper$study_repo %||% NULL
        !is.null(study_repo) &&
          nzchar(as.character(study_repo[[1]])) &&
          !identical(as.character(study_repo[[1]]), DEFAULT_REGISTRY_REPO)
      }
  )

  if (is_folder_study) {
    study_repo <- as.character((stub$repo %||% stub$paper$study_repo)[[1]])
    ref <- as.character((stub$paper$study_ref %||% stub$study_ref %||% list("main"))[[1]])
    study_url <- sprintf(
      "https://raw.githubusercontent.com/%s/%s/replication.yml",
      study_repo, ref
    )
    study_meta <- read_yaml_from_url(study_url)
    if (!is.null(study_meta) && length(study_meta$replications %||% list()) > 0) {
      return(c(study_meta$prep %||% list(), study_meta$replications %||% list()))
    }
    return(list())
  }

  pkg_repo <- stub$repo %||% stub$paper$package_repo %||% NULL
  if (is.null(pkg_repo) || !nzchar(as.character(pkg_repo[[1]]))) {
    return(list())
  }
  pkg_repo <- as.character(pkg_repo[[1]])
  ref <- as.character((stub$paper$package_ref %||% stub$package_ref %||% list("main"))[[1]])

  for (pkg_url in package_replication_yaml_urls(pkg_repo, ref)) {
    pkg_meta <- read_yaml_from_url(pkg_url)
    if (!is.null(pkg_meta) && length(pkg_meta$replications %||% list()) > 0) {
      return(c(pkg_meta$prep %||% list(), pkg_meta$replications %||% list()))
    }
  }

  list()
}

fetch_replication_code_shiny <- function(what, folder, repo = DEFAULT_REGISTRY_REPO) {
  reps <- fetch_study_replications_index(folder, repo)
  if (!length(reps)) {
    stop("No replication metadata for folder ", folder, call. = FALSE)
  }
  match <- reps[vapply(reps, function(x) identical(x$id, what), logical(1))]
  if (!length(match)) {
    stop("Replication ", what, " not found.", call. = FALSE)
  }
  entry <- match[[1]]
  source_name <- entry$make %||% entry$code
  if (is.null(source_name) || !nzchar(source_name)) {
    stop("Replication ", what, " has no make/code entry.", call. = FALSE)
  }

  registry_url <- registry_stub_yaml_url(folder, repo)
  stub <- read_yaml_from_url(registry_url)
  pkg_repo <- stub$repo %||% stub$paper$package_repo %||% NULL
  if (is.null(pkg_repo) || !nzchar(as.character(pkg_repo[[1]]))) {
    stop("No package repo in registry stub.", call. = FALSE)
  }
  pkg_repo <- as.character(pkg_repo[[1]])
  ref <- as.character((stub$paper$package_ref %||% stub$package_ref %||% list("main"))[[1]])
  package <- as.character(stub$paper$package[[1]])

  source_lines <- character(0)
  for (code_url in package_replication_code_urls(source_name, pkg_repo, ref)) {
    source_lines <- read_lines_from_url(code_url)
    if (length(source_lines)) {
      break
    }
  }
  if (!length(source_lines)) {
    stop("Could not read ", source_name, " from ", pkg_repo, call. = FALSE)
  }
  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    ns <- asNamespace("replicateEverything")
    if (exists("clean_replication_source_lines", envir = ns, inherits = FALSE)) {
      source_lines <- get("clean_replication_source_lines", envir = ns)(source_lines)
    }
  }
  source_lines <- source_lines[!grepl("^\\s*#'", source_lines)]

  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    ns <- asNamespace("replicateEverything")
    if (exists("get_code_from_package_repo", envir = ns, inherits = FALSE)) {
      ctx <- list(folder = folder, repo = repo)
      return(get("get_code_from_package_repo", envir = ns)(stub, ctx, what, package))
    }
  }

  c(
    paste0("# Replication: ", what),
    paste0("# Source: ", pkg_repo, "/", ref, "/inst/replication_code/", source_name, ".R"),
    "",
    paste0("library(", package, ")"),
    "",
    source_lines
  )
}

build_replication_index_diagnostics <- function(doi, folder = NULL, repo = NULL, replications_loaded = NULL) {
  index_repo <- repo %||% DEFAULT_REGISTRY_REPO
  registry_url <- if (!is.null(folder) && nzchar(folder)) {
    registry_stub_yaml_url(folder, DEFAULT_REGISTRY_REPO)
  } else {
    ""
  }

  registry_sources <- list()
  if (nzchar(registry_url)) {
    registry_sources[[1]] <- list(
      label = "registry stub",
      url = registry_url,
      browse_url = raw_to_github_browse(registry_url),
      status = if (nzchar(registry_url)) yaml_url_status(registry_url) else "no folder"
    )
  }

  stub <- if (nzchar(registry_url)) read_yaml_from_url(registry_url) else NULL
  package_sources <- list()
  study_sources <- list()
  package_repo <- NULL
  package_ref <- "main"
  study_repo <- NULL
  study_ref <- "main"
  is_package_study <- FALSE
  is_folder_study <- FALSE
  replications_found <- 0L

  if (!is.null(stub)) {
    is_package_study <- !is.null(stub$paper$package) &&
      nzchar(as.character(stub$paper$package[[1]] %||% ""))
    is_folder_study <- !is_package_study && (
      identical(as.character(stub$paper$materials %||% ""), "folder") ||
        {
          candidate <- stub$repo %||% stub$paper$study_repo %||% NULL
          !is.null(candidate) &&
            nzchar(as.character(candidate[[1]])) &&
            !identical(as.character(candidate[[1]]), DEFAULT_REGISTRY_REPO)
        }
    )
    reps <- stub$replications %||% list()
    if (length(reps) > 0) {
      replications_found <- replication_display_count(reps)
    }
    if (is_folder_study) {
      study_repo <- as.character((stub$repo %||% stub$paper$study_repo)[[1]])
      study_ref <- as.character((stub$paper$study_ref %||% stub$study_ref %||% list("main"))[[1]])
      study_url <- sprintf(
        "https://raw.githubusercontent.com/%s/%s/replication.yml",
        study_repo, study_ref
      )
      study_sources[[length(study_sources) + 1L]] <- list(
        label = "study repo replication.yml",
        url = study_url,
        browse_url = raw_to_github_browse(study_url),
        status = yaml_url_status(study_url)
      )
      study_meta <- read_yaml_from_url(study_url)
      if (!is.null(study_meta)) {
        replications_found <- replication_display_count(study_meta$replications %||% list())
      }
    } else {
      pkg_repo <- stub$repo %||% stub$paper$package_repo %||% NULL
      if (!is.null(pkg_repo) && nzchar(as.character(pkg_repo[[1]]))) {
        package_repo <- as.character(pkg_repo[[1]])
        package_ref <- as.character((stub$paper$package_ref %||% stub$package_ref %||% list("main"))[[1]])
        for (pkg_url in package_replication_yaml_urls(package_repo, package_ref)) {
          package_sources[[length(package_sources) + 1L]] <- list(
            label = "study package replication.yml",
            url = pkg_url,
            browse_url = raw_to_github_browse(pkg_url),
            status = yaml_url_status(pkg_url)
          )
        }
        for (pkg_url in package_replication_yaml_urls(package_repo, package_ref)) {
          pkg_meta <- read_yaml_from_url(pkg_url)
          if (!is.null(pkg_meta)) {
            replications_found <- replication_display_count(pkg_meta$replications %||% list())
            if (replications_found > 0L) {
              break
            }
          }
        }
      }
    }
  }

  re_version <- NULL
  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    re_version <- as.character(utils::packageVersion("replicateEverything"))
  }

  list(
    doi = doi,
    folder = folder,
    registry_repo = DEFAULT_REGISTRY_REPO,
    index_repo = index_repo,
    package_repo = package_repo,
    package_ref = package_ref,
    study_repo = study_repo,
    study_ref = study_ref,
    is_package_study = is_package_study,
    is_folder_study = is_folder_study,
    replications_found = replications_found,
    replications_loaded = replications_loaded,
    replicate_everything_version = re_version,
    registry_sources = registry_sources,
    package_sources = package_sources,
    study_sources = study_sources
  )
}

fetch_replications_yaml <- function(folder, repo = DEFAULT_REGISTRY_REPO) {
  fetch_study_replications_index(folder, repo)
}

get_replications_meta <- function(doi, folder = NULL, repo = NULL) {
  if (is.null(doi) || !nzchar(doi)) {
    return(list(replications = NULL, error = NULL, diagnostics = NULL))
  }
  doi <- replicate_fn("normalize_doi", doi)
  ctx <- list(
    folder = folder,
    repo = repo %||% DEFAULT_REGISTRY_REPO
  )

  replications <- NULL
  load_error <- NULL

  if (!is.null(ctx$folder) && nzchar(ctx$folder)) {
    replications <- tryCatch(
      fetch_study_replications_index(ctx$folder, ctx$repo),
      error = function(e) {
        load_error <<- e
        NULL
      }
    )
  }

  if (replication_display_count(replications) == 0L) {
    replications <- tryCatch(
      replicate_fn(
        "list_replications",
        doi,
        folder = ctx$folder,
        repo = ctx$repo
      ),
      error = function(e) {
        if (is.null(load_error)) {
          load_error <<- e
        }
        NULL
      }
    )
  }

  diagnostics <- build_replication_index_diagnostics(
    doi,
    folder = ctx$folder,
    repo = ctx$repo,
    replications_loaded = replication_display_count(replications)
  )

  if (!is.null(load_error) && replication_display_count(replications) == 0L) {
    message(
      "Replicate Everything: could not load replication index for ", doi,
      if (!is.null(ctx$folder)) paste0(" (folder: ", ctx$folder, ")") else "",
      ": ", conditionMessage(load_error)
    )
    diagnostics$error_message <- conditionMessage(load_error)
  }

  list(
    replications = replications,
    error = if (replication_display_count(replications) == 0L) load_error else NULL,
    diagnostics = diagnostics
  )
}

load_replication_artifact <- function(doi, what, folder = NULL, repo = NULL) {
  ns <- asNamespace("replicateEverything")
  if (exists("load_artifact", envir = ns, inherits = FALSE)) {
    return(replicate_fn("load_artifact", doi, what, folder = folder, repo = repo))
  }
  path <- replicate_fn("get_artifact_path", doi, what, folder = folder, repo = repo)
  if (is.null(path)) {
    return(NULL)
  }
  if (grepl("^https?://", path)) {
    ext <- tolower(tools::file_ext(path))
    tmp <- tempfile(fileext = paste0(".", ext))
    utils::download.file(path, tmp, quiet = TRUE, mode = "wb")
    if (ext %in% c("png", "svg", "jpg", "jpeg")) {
      return(tmp)
    }
    path <- tmp
  }
  if (!file.exists(path)) {
    return(NULL)
  }
  ext <- tolower(tools::file_ext(path))
  switch(
    ext,
    rds = readRDS(path),
    png = path,
    svg = path,
    html = paste(readLines(path, warn = FALSE), collapse = "\n"),
    path
  )
}

format_replication_error <- function(error) {
  if (is.null(error)) {
    return("Unknown error")
  }
  if (is.character(error)) {
    return(paste(error, collapse = "\n"))
  }
  tryCatch({
    if (
      requireNamespace("replicateEverything", quietly = TRUE) &&
      exists("replication_error_message", envir = asNamespace("replicateEverything"), inherits = FALSE)
    ) {
      return(replicateEverything::replication_error_message(error))
    }
    if (inherits(error, "condition")) {
      return(conditionMessage(error))
    }
    as.character(error)
  }, error = function(e) {
    paste("Could not format error message:", conditionMessage(e))
  })
}

replication_error_ui <- function(error, doi = NULL, folder = NULL, repo = NULL) {
  if (!is.null(doi) && nzchar(doi)) {
    install_ui <- study_package_install_ui(doi, folder = folder, repo = repo, error = error)
    if (!is.null(install_ui)) {
      return(install_ui)
    }
  }
  tags$div(
    class = "alert alert-danger replication-error",
    tags$strong("Replication failed"),
    tags$pre(
      class = "replication-error-message mb-0 mt-2",
      format_replication_error(error)
    )
  )
}

study_package_install_ui <- function(doi, folder = NULL, repo = NULL, error = NULL) {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    return(NULL)
  }
  ns <- asNamespace("replicateEverything")
  if (inherits(error, "study_package_error")) {
    # always show install UI for structured package errors
  } else if (!is.null(error)) {
    msg <- format_replication_error(error)
    if (!grepl("replication package|\\.rdb|not installed|not available", msg, ignore.case = TRUE)) {
      return(NULL)
    }
  }
  meta <- tryCatch(
    replicate_fn("get_replication_meta", doi, repo = repo, folder = folder),
    error = function(e) NULL
  )
  if (is.null(meta) || !isTRUE(replicate_fn("is_package_replication", meta))) {
    return(NULL)
  }
  pkg <- as.character(meta$paper$package[[1]])
  if (is.null(error)) {
    usable <- exists("replication_package_usable", envir = ns, inherits = FALSE) &&
      isTRUE(get("replication_package_usable", envir = ns)(pkg))
    if (usable) {
      return(NULL)
    }
  }
  ctx <- replicate_fn("paper_context", doi, repo = repo, folder = folder)
  info <- replicate_fn("study_package_install_info", meta, ctx)
  if (is.null(info)) {
    return(NULL)
  }

  tags$div(
    class = "alert alert-info replication-package-install",
    tags$strong("Replication package required"),
    tags$p("To replicate this study, install the replication package first."),
    tags$p(tags$strong("Package: "), tags$code(info$package)),
    if (!is.na(info$github_url)) {
      tagList(
        tags$p(
          tags$strong("GitHub: "),
          tags$a(
            href = info$github_url,
            target = "_blank",
            paste0(info$repo, "@", info$ref)
          )
        ),
        tags$p(
          tags$strong("Install: "),
          tags$code(info$install_github)
        )
      )
    },
    if (!is.null(info$sibling_path) && nzchar(info$sibling_path)) {
      tags$p(
        "A local copy was found at ",
        tags$code(info$sibling_path),
        ". Run ",
        tags$code(info$load_local),
        " in this R session (or restart Shiny from the monorepo)."
      )
    }
  )
}

replication_index_debug_ui <- function(diag) {
  if (is.null(diag)) {
    return(tags$div(
      class = "alert alert-warning",
      tags$strong("No tables or figures loaded."),
      tags$p("Diagnostics were not available for this study.")
    ))
  }

  source_li <- function(src) {
    tags$li(
      tags$strong(src$label %||% "source"),
      " — ",
      tags$code(src$status %||% "unknown"),
      tags$br(),
      if (nzchar(src$browse_url %||% "")) {
        tags$a(href = src$browse_url, target = "_blank", src$browse_url)
      } else {
        tags$code(src$url %||% "")
      },
      if (!identical(src$url, src$browse_url) && nzchar(src$url %||% "")) {
        tagList(tags$br(), tags$small(class = "text-muted", "raw: ", tags$code(src$url)))
      }
    )
  }

  tagList(
    tags$div(
      class = "alert alert-warning",
      tags$strong("No tables or figures loaded for this study."),
      tags$p(
        if (isTRUE(diag$is_package_study)) {
          tagList(
            "Package-backed study: index should come from study repo ",
            tags$code(paste0(diag$package_repo, "@", diag$package_ref)),
            " (not the registry stub alone)."
          )
        } else if (isTRUE(diag$is_folder_study)) {
          tagList(
            "Folder-backed study: index should come from study repo ",
            tags$code(paste0(diag$study_repo, "@", diag$study_ref)),
            " (not the registry stub alone)."
          )
        } else {
          "Checked registry replication.yml sources."
        }
      ),
      if (length(diag$registry_sources %||% list()) > 0) {
        tagList(tags$p(class = "mb-1", tags$strong("Registry stub")), tags$ul(lapply(diag$registry_sources, source_li)))
      },
      if (length(diag$package_sources %||% list()) > 0) {
        tagList(
          tags$p(class = "mb-1 mt-2", tags$strong("Study package index (replication.yml)")),
          tags$ul(lapply(diag$package_sources, source_li))
        )
      },
      if (length(diag$study_sources %||% list()) > 0) {
        tagList(
          tags$p(class = "mb-1 mt-2", tags$strong("Study repo index (replication.yml)")),
          tags$ul(lapply(diag$study_sources, source_li))
        )
      },
      tags$p(
        class = "mb-0 small text-muted",
        "Yaml lists ",
        diag$replications_found %||% 0L,
        " table/figure entries; app loaded ",
        diag$replications_loaded %||% 0L,
        ".",
        if (!is.null(diag$replicate_everything_version)) {
          tagList(tags$br(), "replicateEverything version: ", tags$code(diag$replicate_everything_version))
        }
      ),
      if (!is.null(diag$error_message) && nzchar(diag$error_message)) {
        tags$pre(class = "small mt-2 mb-0", diag$error_message)
      }
    )
  )
}

display_object <- function(doi, what, obj, install_deps = FALSE, folder = NULL, repo = NULL) {
  if (inherits(obj, "error")) {
    return(obj)
  }
  if (is.list(obj) && !is.null(obj$display)) {
    return(obj$display)
  }
  if (is.list(obj) && identical(obj$source, "package")) {
    return(replicate_fn("replication_object", obj))
  }
  if (is.character(obj) && length(obj) == 1 && nzchar(obj) && file.exists(obj)) {
    return(obj)
  }
  if (is.character(obj) && length(obj) == 1 && grepl("<table|<html|<!DOCTYPE|<pre", obj, ignore.case = TRUE)) {
    return(obj)
  }
  analysis <- if (is.list(obj) && !is.null(obj$object)) {
    replicate_fn("replication_object", obj)
  } else {
    obj
  }
  if (is.null(analysis)) {
    return(NULL)
  }
  tryCatch(
    replicate_fn(
      "format_for_display",
      analysis,
      doi,
      what,
      install_deps = install_deps,
      folder = folder,
      repo = repo
    ),
    error = function(e) e
  )
}

as_table_ui <- function(result) {
  if (inherits(result, "error")) {
    return(replication_error_ui(result))
  }

  obj <- if (is.list(result) && !is.null(result$object)) {
    replicate_fn("replication_object", result)
  } else {
    result
  }

  if (is.character(obj) && length(obj) == 1 && grepl("<table|<pre", obj, ignore.case = TRUE)) {
    html <- if (grepl("<table", obj, ignore.case = TRUE)) {
      replicate_fn("normalize_html_table", obj)
    } else {
      obj
    }
    return(tags$div(
      class = "replication-table table-responsive",
      HTML(html)
    ))
  }

  if (is.character(obj) && length(obj) == 1 && grepl("^\\s*<", obj)) {
    return(HTML(replicate_fn("normalize_html_table", obj)))
  }

  if (is.data.frame(obj) || is.matrix(obj)) {
    return(tableOutput("dynamic_table"))
  }

  HTML(as.character(obj))
}

contribute_hint <- function(label, example, caption = NULL) {
  tags$span(
    class = "contribute-hint",
    tabindex = "0",
    tags$span(class = "contribute-hint-label", label),
    tags$span(
      class = "contribute-example",
      if (!is.null(caption)) tags$div(class = "contribute-example-caption", caption),
      tags$pre(tags$code(example))
    )
  )
}

contribute_tab_ui <- function() {
  example_folder_stub <- paste0(
    "paper:\n",
    "  doi: https://doi.org/10.1017/S0003055403000534\n",
    "  title: Ethnicity, Insurgency, and Civil War\n",
    "  materials: folder\n",
    "  study_repo: replicate-anything/rep-10.1017-S0003055403000534\n",
    "  study_folder: rep-10.1017-S0003055403000534\n",
    "repo: replicate-anything/rep-10.1017-S0003055403000534"
  )

  example_folder_repo <- paste0(
    "replication.yml\n",
    "data/repdata.dta\n",
    "code/tab_1.R\n",
    "artifacts/tab_1.html\n",
    "artifacts/manifest.json"
  )

  example_yaml <- paste0(
    "paper:\n",
    "  doi: https://doi.org/10.1017/S0003055403000534\n",
    "  title: Ethnicity, Insurgency, and Civil War\n",
    "  dependencies:\n",
    "    - haven\n",
    "    - modelsummary\n",
    "\n",
    "replications:\n",
    "  - id: tab_1\n",
    "    type: table\n",
    "    label: Table 1\n",
    "    data: data/repdata.dta\n",
    "    code: code/tab_1.R\n",
    "    format: format_tab_1\n",
    "    artifact: artifacts/tab_1.rds"
  )

  example_make_format <- paste0(
    "make_tab_1 <- function(data) {\n",
    "  glm(onset ~ warl + gdpenl + lpopl, data = data,\n",
    "      family = binomial())\n",
    "}\n",
    "\n",
    "format_tab_1 <- function(object) {\n",
    "  modelsummary::modelsummary(\n",
    "    object,\n",
    "    output = \"kableExtra\",\n",
    "    stars = TRUE\n",
    "  )\n",
    "}"
  )

  example_script <- paste0(
    "# Study repo: https://github.com/replicate-anything/rep-10.1017-S0003055403000534\n",
    "\n",
    "library(haven)\n",
    "library(modelsummary)\n",
    "library(kableExtra)\n",
    "\n",
    "make_tab_1 <- function(data) { ... }\n",
    "format_tab_1 <- function(object) { ... }\n",
    "\n",
    "make_tab_1(haven::read_dta(\"../data/repdata.dta\")) |> format_tab_1()"
  )

  example_figure <- paste0(
    "  - id: fig_1\n",
    "    type: figure\n",
    "    data: data/example.csv\n",
    "    code: code/fig_1.R\n",
    "    artifact: artifacts/fig_1.png\n",
    "\n",
    "make_fig_1 <- function(data) {\n",
    "  ggplot2::ggplot(data, ggplot2::aes(x, y)) +\n",
    "    ggplot2::geom_line()\n",
    "}"
  )

  example_build <- paste0(
    "cd registry\n",
    "Rscript scripts/build_artifacts.R\n",
    "\n",
    "# one paper only:\n",
    "Rscript scripts/build_artifacts.R papers/10.1017S0003055403000534\n",
    "\n",
    "Rscript scripts/validate_artifacts.R"
  )

  example_package_stub <- paste0(
    "paper:\n",
    "  doi: https://doi.org/10.1371/journal.pone.0278337\n",
    "  title: Public support for global vaccine sharing...\n",
    "  package: rep1371journalpone0278337\n",
    "  package_repo: replicate-anything/rep-10.1371_journal.pone.0278337\n",
    "  package_ref: main\n",
    "repo: replicate-anything/rep-10.1371_journal.pone.0278337"
  )

  example_package_api <- paste0(
    "list_replications()\n",
    "run_replication(\"fig_1\")\n",
    "load_artifact(\"tab_1\")\n",
    "get_code(\"fig_1\")\n",
    "build_report()   # writes inst/report/artifacts/"
  )

  example_folder_build <- paste0(
    "library(replicateEverything)\n",
    "options(\n",
    "  replicateEverything.registry_root = \"../registry\",\n",
    "  replicateEverything.use_sibling_packages = TRUE\n",
    ")\n",
    "\n",
    "build_study_artifacts(\".\", install_deps = TRUE)\n",
    "testthat::test_dir(\"tests/testthat\")\n",
    "prepare_folder_paper(\".\", build_artifacts = FALSE)"
  )

  example_sync_folder <- paste0(
    "options(replicateEverything.registry_root = \"../registry\")\n",
    "sync_folder_paper(\".\")"
  )

  example_package_tests <- paste0(
    "build_report()\n",
    "testthat::test_dir(\"tests/testthat\")\n",
    "check_package_replication(\".\", full_replication = FALSE)"
  )

  example_add_paper <- paste0(
    "library(replicateEverything)\n",
    "options(replicateEverything.registry_root = \"../registry\")\n",
    "\n",
    "check_package_replication(\n",
    "  \"../rep-10.1371_journal.pone.0278337\",\n",
    "  full_replication = FALSE\n",
    ")\n",
    "\n",
    "add_paper(\"../rep-10.1371_journal.pone.0278337\")"
  )

  fluidPage(
    class = "px-3 py-2",
    tags$div(
      class = "d-flex align-items-center gap-2 mb-2",
      tags$img(
        src = APP_HEX_LOGO,
        height = "32",
        width = "auto",
        alt = "",
        class = "app-brand-icon"
      ),
      h3(class = "mb-0", "Contribute a replication")
    ),
    p(
      class = "text-muted",
      "Two models: ",
      tags$strong("folder-backed study repo"),
      " (code/data in a dedicated repo; registry stub only) and ",
      tags$strong("package-backed"),
      " (study R package on GitHub; registry stub only). Hover ",
      tags$span(class = "contribute-hint-demo", "underlined terms"),
      " for examples."
    ),
    h4("Folder-backed study repo"),
    tags$ol(
      tags$li(
        "Create a study repository with ",
        contribute_hint(code("replication.yml"), example_yaml, "Study replication.yml"),
        ", ",
        contribute_hint(code("data/"), example_folder_repo, "Study repo layout"),
        ", ",
        code("code/"),
        ", and ",
        code("artifacts/"),
        "."
      ),
      tags$li(
        "Add a registry stub file ",
        code("papers/<folder>.yml"),
        " with ",
        contribute_hint(code("materials: folder"), example_folder_stub, "Registry stub fields"),
        " pointing at the study repo."
      ),
      tags$li(
        "Update ",
        code("index.csv"),
        " so the ",
        code("repo"),
        " column names the study repository."
      ),
      tags$li(
        "Build artifacts, test, and prepare registry stub files with ",
        contribute_hint(code("prepare_folder_paper()"), example_folder_build, "Build, test, prepare"),
        ". This writes ",
        code("registry/replication.yml"),
        " and ",
        code("registry/index.csv"),
        " in the study repo."
      ),
      tags$li(
        "Sync those files to the registry with ",
        contribute_hint(code("sync_folder_paper()"), example_sync_folder, "Sync to registry"),
        " (or copy manually). See vignette ",
        code("folder-replication-checklist"),
        "."
      )
    ),
    h4("Package-backed study"),
    tags$ol(
      tags$li(
        "Build an R package with ",
        contribute_hint(code("replication.yml"), example_package_stub, "Registry stub fields"),
        " and exported ",
        contribute_hint(code("run_replication()"), example_package_api, "Required API"),
        "."
      ),
      tags$li(
        "Bake display artifacts with ",
        code("build_report()"),
        " into ",
        code("inst/report/artifacts/"),
        " (PNG figures, HTML tables)."
      ),
      tags$li(
        "Add ",
        code("tests/testthat/"),
        " and validate with ",
        contribute_hint(code("check_package_replication()"), example_package_tests, "Build, test, validate"),
        "."
      ),
      tags$li(
        "Register with ",
        contribute_hint(code("add_paper()"), example_add_paper, "Register package"),
        " in ",
        code("replicateEverything"),
        ". See vignette ",
        code("package-replication-checklist"),
        "."
      )
    )
  )
}

replication_run_snippet <- function(doi, what) {
  paste0(
    "replicateEverything::run_replication(\n",
    "  doi = ", encodeString(doi, quote = '"'), ",\n",
    "  what = ", encodeString(what, quote = '"'), "\n",
    ")"
  )
}

code_copy_icon_svg <- function() {
  HTML(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" ',
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ',
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
    '<rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>',
    '<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>',
    "</svg>"
  ))
}

code_block_ui <- function(code_text, block_id, button_id, title = NULL, language = "r") {
  if (is.null(code_text) || !nzchar(code_text)) {
    return(NULL)
  }
  lang_class <- paste0("language-", language)
  tags$div(
    class = "replication-code-wrap",
    if (!is.null(title) && nzchar(title)) {
      tags$div(class = "replication-code-title", title)
    },
    tags$div(
      class = "replication-code-block",
      tags$button(
        type = "button",
        class = "replication-code-copy",
        id = button_id,
        title = "Copy code",
        `aria-label` = "Copy code",
        onclick = sprintf("copyReplicationCode('%s', '%s')", block_id, button_id),
        code_copy_icon_svg()
      ),
      tags$pre(
        tags$code(
          class = lang_class,
          id = block_id,
          code_text
        )
      )
    )
  )
}

code_panel_ui <- function(simple_code, full_code = NULL, language = "r") {
  if ((is.null(simple_code) || !nzchar(simple_code)) &&
      (is.null(full_code) || !nzchar(full_code))) {
    return(helpText("Select a table or figure to view code."))
  }
  tags$div(
    class = "replication-code-panel",
    code_block_ui(
      simple_code,
      "replication_simple_code_block",
      "copy_simple_code_btn",
      "One-line replication",
      language = language
    ),
    if (!is.null(full_code) && nzchar(full_code)) {
      code_block_ui(
        full_code,
        "replication_full_code_block",
        "copy_full_code_btn",
        "Full replication code",
        language = language
      )
    }
  )
}

ui <- tagList(
  tags$head(
    app_favicon_tags(),
    tags$link(
      rel = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css"
    ),
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"),
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/r.min.js"),
    tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/languages/stata.min.js"),
    tags$script(HTML("
      function copyReplicationCode(elementId, buttonId) {
        var el = document.getElementById(elementId);
        if (!el) return;
        var text = el.textContent;
        var write = navigator.clipboard && navigator.clipboard.writeText
          ? navigator.clipboard.writeText(text)
          : new Promise(function(resolve, reject) {
              var ta = document.createElement('textarea');
              ta.value = text;
              document.body.appendChild(ta);
              ta.select();
              try { document.execCommand('copy'); resolve(); }
              catch (err) { reject(err); }
              document.body.removeChild(ta);
            });
        write.then(function() {
          var btn = document.getElementById(buttonId);
          if (!btn) return;
          btn.classList.add('copied');
          btn.setAttribute('aria-label', 'Copied');
          btn.setAttribute('title', 'Copied');
          setTimeout(function() {
            btn.classList.remove('copied');
            btn.setAttribute('aria-label', 'Copy code');
            btn.setAttribute('title', 'Copy code');
          }, 1500);
        });
      }
      Shiny.addCustomMessageHandler('highlightCode', function(msg) {
        document.querySelectorAll('.replication-code-block code[class*=language-]').forEach(function(el) {
          if (window.hljs) hljs.highlightElement(el);
        });
      });
      Shiny.addCustomMessageHandler('engineToggleState', function(msg) {
        var wrap = document.getElementById('engine_toggle_wrap');
        if (!wrap) return;
        wrap.classList.toggle('is-hidden', msg.wrapClass === 'is-hidden');
        var rIcon = wrap.querySelector('.engine-toggle-r');
        var sIcon = wrap.querySelector('.engine-toggle-stata');
        var input = wrap.querySelector("input[type='checkbox']");
        if (rIcon) rIcon.classList.toggle('disabled', !msg.hasR);
        if (sIcon) sIcon.classList.toggle('disabled', !msg.hasStata);
        if (input) input.disabled = !!msg.disabled;
      });
    ")),
    tags$style(HTML("
    .replication-table table { display: table; width: auto; max-width: 100%; margin-bottom: 1rem; }
    .replication-table thead { display: table-header-group; }
    .replication-table tbody { display: table-row-group; }
    .replication-table tfoot { display: table-footer-group; }
    .replication-table tr { display: table-row; }
    .replication-table th, .replication-table td { display: table-cell; vertical-align: top; }
    .replication-table caption { caption-side: top; font-weight: 600; padding-bottom: 0.5rem; }
    .replication-code-panel { margin-top: 0.25rem; }
    .replication-code-wrap { margin-bottom: 0.85rem; }
    .replication-code-wrap:last-child { margin-bottom: 0; }
    .replication-code-title {
      font-size: 0.78rem;
      font-weight: 600;
      color: #57606a;
      margin: 0 0 0.3rem 0;
      letter-spacing: 0.01em;
    }
    .replication-code-block {
      position: relative;
      max-height: 70vh;
      overflow: auto;
      margin: 0;
      border: 1px solid #d0d7de;
      border-radius: 6px;
      background: #f6f8fa;
    }
    .replication-code-block pre {
      margin: 0;
      padding: 0.55rem 2.1rem 0.55rem 0.7rem;
      background: transparent;
      border: 0;
      font-size: 0.8125rem;
      line-height: 1.45;
    }
    .replication-code-block code,
    .replication-code-block .hljs {
      white-space: pre;
      display: block;
      background: transparent !important;
      padding: 0 !important;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }
    .replication-code-copy {
      position: absolute;
      top: 0.35rem;
      right: 0.35rem;
      z-index: 2;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 1.65rem;
      height: 1.65rem;
      padding: 0;
      border: 1px solid #d0d7de;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.92);
      color: #57606a;
      cursor: pointer;
      line-height: 1;
    }
    .replication-code-copy:hover {
      background: #ffffff;
      color: #24292f;
      border-color: #afb8c1;
    }
    .replication-code-copy.copied {
      color: #1a7f37;
      border-color: #4ac26b;
    }
    .contribute-hint {
      position: relative;
      display: inline;
      cursor: help;
    }
    .contribute-hint-label {
      border-bottom: 1px dotted currentColor;
    }
    .contribute-hint-demo {
      border-bottom: 1px dotted currentColor;
    }
    .contribute-hint:hover,
    .contribute-hint:focus-within {
      z-index: 1050;
    }
    .contribute-example {
      display: none;
      position: absolute;
      left: 0;
      top: calc(100% + 6px);
      z-index: 1050;
      min-width: 280px;
      max-width: min(560px, 92vw);
      max-height: 360px;
      overflow: auto;
      background: #fff;
      border: 1px solid #dce0e4;
      border-radius: 6px;
      padding: 0.65rem 0.75rem;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
      font-size: 0.75rem;
      line-height: 1.4;
      color: #24292f;
      text-align: left;
      white-space: normal;
    }
    .contribute-hint:hover .contribute-example,
    .contribute-hint:focus-within .contribute-example {
      display: block;
    }
    .contribute-example-caption {
      font-weight: 600;
      margin-bottom: 0.35rem;
      color: #57606a;
      font-size: 0.7rem;
      text-transform: uppercase;
      letter-spacing: 0.02em;
    }
    .contribute-example pre {
      margin: 0;
      padding: 0.5rem;
      background: #f6f8fa;
      border-radius: 4px;
      overflow-x: auto;
    }
    .contribute-example code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      white-space: pre;
      font-size: 0.72rem;
      color: #24292f;
    }
    .replication-error-message {
      white-space: pre-wrap;
      word-break: break-word;
      font-size: 0.85rem;
      background: transparent;
      border: none;
      padding: 0;
    }
    .app-brand-icon {
      height: 32px;
      width: auto;
      display: block;
    }
    .welcome-intro { margin-bottom: 0.5rem; }
    .welcome-intro-layout {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 1.25rem;
    }
    .welcome-logo {
      width: min(168px, 38vw);
      height: auto;
      flex: 0 0 auto;
    }
    .welcome-copy {
      flex: 1 1 240px;
      min-width: 0;
    }
    .welcome-copy p { margin-bottom: 0.75rem; }
    .welcome-copy p:last-child { margin-bottom: 0; }
    .sidebar-panel-compact .shiny-input-container { margin-bottom: 0.55rem; }
    .sidebar-panel-compact h4, .sidebar-panel-compact h5 {
      margin-top: 0.35rem;
      margin-bottom: 0.45rem;
      font-size: 1rem;
    }
    .doi-input-row {
      display: flex;
      align-items: flex-end;
      gap: 0.35rem;
      margin-bottom: 0.55rem;
    }
    .doi-input-row .form-group {
      margin-bottom: 0;
      flex: 1 1 auto;
      min-width: 0;
    }
    .doi-go-wrap .btn { white-space: nowrap; min-width: 2.75rem; }
    .engine-toggle-wrap { margin-bottom: 0.55rem; }
    .engine-toggle-wrap.is-hidden { display: none; }
    .engine-toggle {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 0.45rem;
    }
    .engine-toggle-icon {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      line-height: 0;
      opacity: 0.95;
    }
    .engine-toggle-icon.disabled { opacity: 0.35; }
    .engine-toggle-switch-wrap {
      flex: 0 0 auto;
    }
    .engine-toggle-switch-wrap .shiny-input-container {
      margin-bottom: 0;
    }
    .engine-toggle-switch-wrap .checkbox {
      margin: 0;
      min-height: 0;
    }
    .engine-toggle-switch-wrap .checkbox label {
      position: relative;
      display: inline-block;
      width: 2.6rem;
      height: 1.35rem;
      margin: 0;
      padding: 0;
      font-size: 0;
      line-height: 0;
      cursor: pointer;
    }
    .engine-toggle-switch-wrap .checkbox label::before {
      content: '';
      position: absolute;
      inset: 0;
      background: #cfd8dc;
      border-radius: 999px;
      transition: background 0.15s ease;
    }
    .engine-toggle-switch-wrap .checkbox label::after {
      content: '';
      position: absolute;
      height: 1rem;
      width: 1rem;
      left: 0.18rem;
      bottom: 0.18rem;
      background: #ffffff;
      border-radius: 50%;
      transition: transform 0.15s ease;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.18);
    }
    .engine-toggle-switch-wrap .checkbox input[type='checkbox'] {
      position: absolute;
      opacity: 0;
      width: 100%;
      height: 100%;
      margin: 0;
      cursor: pointer;
      z-index: 2;
    }
    .engine-toggle-switch-wrap .checkbox label:has(> input:checked)::before {
      background: #0054A4;
    }
    .engine-toggle-switch-wrap .checkbox label:has(> input:checked)::after {
      transform: translateX(1.25rem);
    }
    .engine-toggle-switch-wrap .checkbox input[type='checkbox']:disabled {
      cursor: not-allowed;
    }
    .engine-toggle-switch-wrap .checkbox label:has(> input:disabled) {
      opacity: 0.45;
      cursor: not-allowed;
    }
    .replication-list-wrap .text-muted { margin-bottom: 0.35rem !important; font-size: 0.82rem; }
    .replication-row {
      gap: 0.35rem;
      margin-bottom: 0.25rem !important;
      padding: 0.15rem 0.25rem !important;
    }
    .replication-label {
      flex: 1 1 auto;
      min-width: 0;
      font-size: 0.82rem;
      line-height: 1.25;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .replication-actions {
      display: inline-flex;
      gap: 0.25rem;
      flex: 0 0 auto;
    }
    .replication-actions .btn {
      min-width: 3.25rem;
      padding: 0.12rem 0.35rem;
      font-size: 0.75rem;
      line-height: 1.2;
    }
  "))),
  navbarPage(
  id = "main_nav",
  title = app_brand_title(),
  theme = bs_theme(bootswatch = "flatly"),
  tabPanel(
    "Explore",
    sidebarLayout(
      sidebarPanel(
        width = 4,
        class = "sidebar-panel-compact",
        h4("1. Choose a study"),
        selectInput(
          "study_select",
          label = NULL,
          choices = c("Choose a study…" = "", nice_doi_choices(registry_index))
        ),
        tags$div(
          class = "doi-input-row",
          tags$div(
            class = "doi-input-field",
            textInput("study_doi", label = NULL, placeholder = "Or enter DOI")
          ),
          tags$div(
            class = "doi-go-wrap",
            actionButton("doi_go", "Go", class = "btn-primary btn-sm")
          )
        ),
        tags$hr(style = "margin: 0.5rem 0;"),
        h4("2. Tables & figures"),
        engine_toggle_ui(),
        div(class = "replication-list-wrap", uiOutput("replication_list"))
      ),
      mainPanel(
        width = 8,
        uiOutput("study_details"),
        uiOutput("progress_ui"),
        tags$hr(),
        tabsetPanel(
          id = "result_tabs",
          tabPanel("Output", uiOutput("selected_output_ui")),
          tabPanel("Code", uiOutput("replication_code_ui"))
        )
      )
    )
  ),
  tabPanel(
    "Studies",
    fluidPage(
      class = "px-3 py-2",
      uiOutput("studies_bibliography")
    )
  ),
  tabPanel(
    "Contribute",
    contribute_tab_ui()
  ),
  tabPanel(
    "About",
    fluidPage(
      class = "px-3 py-2",
      h4("replicateEverything"),
      p(
        "This demo app is bundled with the ",
        tags$a(href = PKGDOCS_URL, "replicateEverything", target = "_blank"),
        " R package. Browse studies, display precomputed artifacts, and run live replications."
      ),
      tags$ul(
        tags$li(tags$a(href = LIVE_DEMO_URL, "Live demo (this app)", target = "_blank")),
        tags$li(tags$a(href = PKGDOCS_URL, "Package documentation", target = "_blank")),
        tags$li(tags$a(href = REGISTRY_GITHUB, "Replication registry", target = "_blank")),
        tags$li(tags$a(href = ORG_GITHUB, "Study repositories", target = "_blank"))
      ),
      tags$hr(),
      p(
        class = "text-muted",
        "Run interactively with ",
        tags$code("replicateEverything::run_shiny_app()"),
        " or deploy with ",
        tags$code("save_local_shiny()"),
        ". See the ",
        tags$em("Shiny demo app"),
        " vignette for details."
      )
    )
  )
  )
)

server <- function(input, output, session) {
  options(shiny.sanitize.errors = FALSE)

  state <- reactiveValues(
    doi = NULL,
    replications = NULL,
    replications_df = NULL,
    selected_replication = NULL,
    selected_type = NULL,
    selected_source = "artifact",
    selected_result = NULL,
    progress = NULL,
    replications_load_error = NULL,
    replications_index_diagnostics = NULL,
    registry_folder = NULL,
    registry_repo = NULL
  )

  showModal(modalDialog(
    title = "Welcome to Replicate Everything",
    app_welcome_intro(),
    size = "m",
    easyClose = TRUE,
    footer = modalButton("Get started")
  ))

  replication_has_engine <- function(reps, engine) {
    col <- if (engine == "stata") "stata_id" else "r_id"
    any(!is.na(reps[[col]]) & nzchar(reps[[col]]))
  }

  current_engine <- function() {
    if (isTRUE(input$global_engine_stata)) "stata" else "r"
  }

  sync_engine_toggle <- function() {
    reps <- state$replications_df
    show <- !is.null(state$doi) && !is.null(reps) && nrow(reps) > 0
    has_r <- show && replication_has_engine(reps, "r")
    has_stata <- show && replication_has_engine(reps, "stata")
    cls <- if (show && has_r && has_stata) "" else "is-hidden"
    session$sendCustomMessage("engineToggleState", list(
      wrapClass = cls,
      hasR = has_r,
      hasStata = has_stata,
      disabled = !has_r || !has_stata
    ))
    if (show && !has_stata && isTRUE(input$global_engine_stata)) {
      updateCheckboxInput(session, "global_engine_stata", value = FALSE)
    }
  }

  load_study <- function(doi) {
    req(nzchar(doi))
    doi <- replicate_fn("normalize_doi", doi)
    ctx <- registry_row_for(doi)
    state$doi <- doi
    state$registry_folder <- ctx$folder
    state$registry_repo <- ctx$repo

    withProgress(message = "Preparing study...", value = 0.1, {
      meta <- tryCatch(
        get_replications_meta(doi, folder = ctx$folder, repo = ctx$repo),
        error = function(e) list(replications = NULL, error = e)
      )
    })
    state$replications <- meta$replications
    state$replications_load_error <- meta$error
    state$replications_index_diagnostics <- meta$diagnostics
    state$replications_df <- replications_to_df(state$replications)
    reps <- state$replications_df
    has_r <- !is.null(reps) && replication_has_engine(reps, "r")
    has_stata <- !is.null(reps) && replication_has_engine(reps, "stata")
    updateCheckboxInput(
      session,
      "global_engine_stata",
      value = !has_r && has_stata
    )
    state$selected_replication <- NULL
    state$selected_type <- NULL
    state$selected_result <- NULL
    state$selected_source <- "artifact"

    if (!is.null(state$replications_df) && nrow(state$replications_df) > 0) {
      first <- state$replications_df[1, , drop = FALSE]
      eng <- current_engine()
      state$selected_replication <- resolve_group_replication_id(first, eng)
      state$selected_type <- first$type[[1]]
      load_selected_artifact(fallback_live = FALSE)
    }
    sync_engine_toggle()
  }

  observeEvent(input$study_select, {
    req(nzchar(input$study_select))
    load_study(input$study_select)
  })

  observeEvent(input$doi_go, {
    req(input$study_doi)
    load_study(input$study_doi)
  })

  observeEvent(input$go_to_study, {
    req(input$go_to_study)
    updateSelectInput(session, "study_select", selected = input$go_to_study)
    load_study(input$go_to_study)
    updateNavbarPage(session, "main_nav", selected = "Explore")
  })

  output$studies_bibliography <- renderUI({
    req(registry_index)
    idx <- registry_index[studies_for_bibliography(registry_index), , drop = FALSE]

    rows <- lapply(seq_len(nrow(idx)), function(i) {
      row <- idx[i, , drop = FALSE]
      cite <- format_study_citation(row)
      tags$div(
        class = "study-citation d-flex align-items-start py-2 border-bottom",
        style = "gap: 12px;",
        tags$div(
          class = "flex-grow-1",
          style = "line-height: 1.35; font-size: 0.95rem;",
          tags$div(cite$line1),
          if (nzchar(cite$line2)) {
            tags$div(class = "text-muted", style = "font-size: 0.9rem;", cite$line2)
          }
        ),
        actionButton(
          paste0("study_", i),
          "Run",
          class = "btn-primary btn-sm",
          style = "flex-shrink: 0; min-width: 84px; margin-top: 1px;",
          onclick = sprintf(
            "Shiny.setInputValue('go_to_study', '%s', {priority: 'event'})",
            row$doi[[1]]
          )
        )
      )
    })

    tagList(rows)
  })

  output$study_details <- renderUI({
    req(state$doi)
    row <- registry_index[registry_index$doi == state$doi, , drop = FALSE]
    if (nrow(row) == 0) {
      return(helpText("Study metadata not found in registry index."))
    }
    tagList(
      card(
        card_header("Study details"),
        h4(row$title[[1]]),
        p(
          strong("DOI: "), state$doi, br(),
          strong("Authors: "), format_authors_summary(row$authors[[1]]), br(),
          strong("Year: "), row$year[[1]], br(),
          strong("Journal: "), HTML(row$journal[[1]])
        ),
        study_materials_summary_ui(
          state$doi,
          folder = state$registry_folder,
          repo = state$registry_repo
        )
      ),
      study_package_install_ui(
        state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    )
  })

  replication_row <- function(row, active_id = NULL, engine = "r") {
    group <- row$group[[1]]
    label <- row$label[[1]]
    label_full <- row$label_full[[1]] %||% label
    safe_group <- gsub("[^a-zA-Z0-9]", "_", group)
    resolved_id <- resolve_group_replication_id(row, engine)
    row_class <- paste(
      "replication-row d-flex align-items-center rounded",
      if (!is.null(active_id) && identical(resolved_id, active_id)) {
        "bg-light border border-primary"
      } else {
        ""
      }
    )
    tags$div(
      class = row_class,
      tags$span(label, class = "replication-label", title = label_full),
      tags$div(
        class = "replication-actions",
        actionButton(
          paste0("display_", safe_group),
          "Display",
          class = "btn-outline-secondary btn-sm",
          onclick = sprintf(
            "Shiny.setInputValue('replication_action', 'display:%s', {priority: 'event'})",
            group
          )
        ),
        actionButton(
          paste0("replicate_", safe_group),
          "Run",
          class = "btn-primary btn-sm",
          onclick = sprintf(
            "Shiny.setInputValue('replication_action', 'replicate:%s', {priority: 'event'})",
            group
          )
        )
      )
    )
  }

  resolve_replication_row <- function(group_or_id) {
    reps <- state$replications_df
    req(!is.null(reps), nrow(reps) > 0)
    row <- reps[reps$group == group_or_id, , drop = FALSE]
    if (nrow(row) == 0) {
      row <- reps[reps$id == group_or_id, , drop = FALSE]
    }
    req(nrow(row) == 1)
    row
  }

  output$replication_list <- renderUI({
    if (is.null(state$doi)) {
      return(helpText("Choose a study to see its tables and figures."))
    }
    if (!is.null(state$replications_load_error)) {
      return(replication_error_ui(
        state$replications_load_error,
        doi = state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      ))
    }
    reps <- state$replications_df
    if (is.null(reps) || nrow(reps) == 0) {
      return(replication_index_debug_ui(state$replications_index_diagnostics))
    }

    figs <- reps[reps$type == "figure", , drop = FALSE]
    tabs <- reps[reps$type == "table", , drop = FALSE]
    active <- state$selected_replication

    tagList(
      if (nrow(figs) > 0) {
        tagList(
          tags$h6(class = "text-muted mb-2", "Figures"),
          lapply(seq_len(nrow(figs)), function(i) {
            replication_row(
              figs[i, , drop = FALSE],
              active_id = active,
              engine = current_engine()
            )
          })
        )
      },
      if (nrow(tabs) > 0) {
        tagList(
          tags$h6(class = "text-muted mb-2 mt-2", "Tables"),
          lapply(seq_len(nrow(tabs)), function(i) {
            replication_row(
              tabs[i, , drop = FALSE],
              active_id = active,
              engine = current_engine()
            )
          })
        )
      }
    )
  })

  observeEvent(input$global_engine_stata, {
    req(state$replications_df, state$selected_replication)
    row <- tryCatch(
      resolve_replication_row(state$selected_replication),
      error = function(e) NULL
    )
    if (is.null(row)) return()
    rep_id <- resolve_group_replication_id(row, current_engine())
    if (identical(rep_id, state$selected_replication)) return()
    state$selected_replication <- rep_id
    state$selected_type <- row$type[[1]]
    state$selected_result <- NULL
    state$selected_source <- "artifact"
    load_selected_artifact(fallback_live = FALSE)
  }, ignoreInit = TRUE)

  observeEvent(input$replication_action, {
    req(input$replication_action, state$replications_df)
    parts <- strsplit(input$replication_action, ":", fixed = TRUE)[[1]]
    req(length(parts) == 2)
    action <- parts[[1]]
    group_or_id <- parts[[2]]

    row <- resolve_replication_row(group_or_id)
    rep_id <- resolve_group_replication_id(row, current_engine())

    state$selected_replication <- rep_id
    state$selected_type <- row$type[[1]]
    state$selected_result <- NULL

    if (action == "display") {
      state$selected_source <- "artifact"
      load_selected_artifact(fallback_live = FALSE)
    } else if (action == "replicate") {
      tryCatch(
        run_live_replication(state$doi, rep_id),
        error = function(e) {
          state$selected_result <- e
          state$selected_source <- "live"
        }
      )
    }

    updateTabsetPanel(session, "result_tabs", selected = "Output")
  }, ignoreInit = TRUE)

  load_selected_artifact <- function(fallback_live = TRUE) {
    req(state$doi, state$selected_replication)
    withProgress(message = "Loading precomputed result...", value = 0.4, {
      state$progress <- "Loading artifact"
      loaded <- replicate_fn(
        "load_replication_for_display",
        state$doi,
        state$selected_replication,
        prefer = "artifact",
        fallback_live = fallback_live,
        install_deps = TRUE,
        folder = state$registry_folder,
        repo = state$registry_repo
      )
      state$progress <- NULL

      if (isTRUE(loaded$ok)) {
        state$selected_result <- loaded$raw %||% loaded$value
        state$selected_source <- loaded$source
        return(invisible(NULL))
      }
      if (!is.null(loaded$error)) {
        state$selected_result <- loaded$error
        state$selected_source <- loaded$source %||% "artifact"
        return(invisible(NULL))
      }
      state$selected_result <- NULL
      state$selected_source <- "artifact"
    })
  }

  resolved_selected_display <- reactive({
    tryCatch({
      req(state$selected_replication, state$doi)

      if (inherits(state$selected_result, "error")) {
        return(list(ok = FALSE, error = state$selected_result))
      }

      if (is.null(state$selected_result)) {
        return(list(ok = FALSE, missing = TRUE))
      }

      replicate_fn(
        "resolve_replication_display",
        state$doi,
        state$selected_replication,
        state$selected_result,
        source = state$selected_source,
        install_deps = is_live_source(state$selected_source),
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    }, error = function(e) {
      list(ok = FALSE, error = e)
    })
  })

  run_live_replication <- function(doi, what) {
    tryCatch({
      withProgress(message = "Running live replication...", value = 0.2, {
        state$progress <- "Running replication"
        ensure_study_replication_package(doi, folder = state$registry_folder, repo = state$registry_repo)
        loaded <- replicate_fn(
          "load_replication_for_display",
          doi,
          what,
          prefer = "live",
          fallback_live = FALSE,
          install_deps = TRUE,
          folder = state$registry_folder,
          repo = state$registry_repo
        )
        state$selected_result <- if (isTRUE(loaded$ok)) {
          loaded$raw %||% loaded$value
        } else if (!is.null(loaded$error)) {
          loaded$error
        } else {
          NULL
        }
        state$selected_source <- "live"
        state$progress <- NULL
      })
    }, error = function(e) {
      state$selected_result <- e
      state$selected_source <- "live"
      state$progress <- NULL
    })
  }

  output$progress_ui <- renderUI({
    if (is.null(state$progress)) return(NULL)
    div(
      class = "alert alert-info",
      tags$strong("Working: "), state$progress
    )
  })

  output$selected_output_ui <- renderUI({
    req(state$selected_replication)
    if (is_figure_replication(state$selected_type)) {
      tagList(
        p(class = "text-muted", replication_source_label(state$selected_source)),
        uiOutput("selected_figure_ui")
      )
    } else if (is_table_replication(state$selected_type)) {
      tagList(
        p(class = "text-muted", replication_source_label(state$selected_source)),
        uiOutput("selected_table_ui")
      )
    } else {
      helpText("Select a table or figure to view output.")
    }
  })

  output$selected_figure_ui <- renderUI({
    tryCatch({
      resolved <- resolved_selected_display()
      if (!resolved$ok && !is.null(resolved$error)) {
        return(replication_error_ui(
          resolved$error,
          doi = state$doi,
          folder = state$registry_folder,
          repo = state$registry_repo
        ))
      }
      if (!resolved$ok && isTRUE(resolved$missing)) {
        return(artifact_missing_ui(
          state$doi,
          state$selected_replication,
          folder = state$registry_folder,
          repo = state$registry_repo,
          kind = "figure"
        ))
      }
      plotOutput("selected_plot", height = "500px")
    }, error = function(e) {
      replication_error_ui(
        e,
        doi = state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    })
  })

  output$selected_plot <- renderPlot({
    tryCatch({
      resolved <- resolved_selected_display()
      if (!isTRUE(resolved$ok)) {
        plot.new()
        msg <- if (!is.null(resolved$error)) {
          format_replication_error(resolved$error)
        } else {
          "No output available for this figure."
        }
        text(0.5, 0.5, paste(strwrap(msg, 50), collapse = "\n"), cex = 0.85)
        return(invisible(NULL))
      }

      val <- resolved$value
      if (inherits(val, "replication_result")) {
        print(replicate_fn("replication_object", val))
      } else if (is.character(val) && length(val) == 1 && file.exists(val)) {
        img <- png::readPNG(val)
        grid::grid.raster(img)
      } else {
        print(val)
      }
    }, error = function(e) {
      plot.new()
      text(
        0.5, 0.5,
        paste(strwrap(format_replication_error(e), 50), collapse = "\n"),
        cex = 0.85
      )
    })
  })

  output$selected_table_ui <- renderUI({
    tryCatch({
      req(state$selected_replication, state$doi)
      if (is.null(state$selected_result) && is_artifact_source(state$selected_source)) {
        load_selected_artifact(fallback_live = FALSE)
      }
      resolved <- resolved_selected_display()
      if (!resolved$ok && !is.null(resolved$error)) {
        return(replication_error_ui(
          resolved$error,
          doi = state$doi,
          folder = state$registry_folder,
          repo = state$registry_repo
        ))
      }
      if (!resolved$ok && isTRUE(resolved$missing)) {
        return(artifact_missing_ui(
          state$doi,
          state$selected_replication,
          folder = state$registry_folder,
          repo = state$registry_repo,
          kind = "table"
        ))
      }
      as_table_ui(resolved$value)
    }, error = function(e) {
      replication_error_ui(
        e,
        doi = state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    })
  })

  output$dynamic_table <- renderTable({
    req(!inherits(state$selected_result, "error"))
    obj <- tryCatch(
      replicate_fn("replication_object", state$selected_result),
      error = function(e) NULL
    )
    req(!is.null(obj))
    if (is.data.frame(obj) || is.matrix(obj)) obj else as.data.frame(obj)
  }, striped = TRUE, bordered = TRUE)

  output$replication_code_ui <- renderUI({
    req(state$selected_replication, state$doi)
    simple_code <- replication_run_snippet(state$doi, state$selected_replication)
    full_code <- tryCatch(
      paste(
        replicate_fn(
          "get_code",
          state$doi,
          state$selected_replication,
          folder = state$registry_folder,
          repo = state$registry_repo
        ),
        collapse = "\n"
      ),
      error = function(e) NULL
    )
    if (is.null(full_code) || !nzchar(full_code)) {
      full_code <- tryCatch(
        paste(
          fetch_replication_code_shiny(
            state$selected_replication,
            state$registry_folder,
            state$registry_repo
          ),
          collapse = "\n"
        ),
        error = function(e) NULL
      )
    }
    if ((is.null(full_code) || !nzchar(full_code)) && !nzchar(simple_code)) {
      return(helpText(
        "Could not load replication code. ",
        "Package-backed studies need the study R package installed on this server; ",
        "folder-backed and registry studies load scripts from the study or registry repo."
      ))
    }
    code_lang <- tryCatch(
      replicate_fn(
        "replication_code_language_for",
        state$doi,
        state$selected_replication,
        folder = state$registry_folder,
        repo = state$registry_repo
      ),
      error = function(e) "r"
    )
    code_panel_ui(simple_code, full_code, language = code_lang)
  })

  observeEvent(list(state$selected_replication, input$result_tabs), {
    if (is.null(input$result_tabs) || input$result_tabs != "Code") {
      return()
    }
    req(state$selected_replication)
    session$onFlushed(function() {
      session$sendCustomMessage("highlightCode", list())
    }, once = TRUE)
  }, ignoreInit = TRUE)
}

shinyApp(ui, server)
