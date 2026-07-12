library(shiny)
library(bslib)
library(htmltools)

REGISTRY_INDEX_URL <- "https://raw.githubusercontent.com/replicate-anything/registry/main/index.csv"
REGISTRY_GITHUB <- "https://github.com/replicate-anything/registry"
ORG_GITHUB <- "https://github.com/orgs/replicate-anything/repositories"
PKGDOCS_URL <- "https://replicate-anything.github.io/replicateEverything/index.html"
SHINY_VIGNETTE_URL <- "https://replicate-anything.github.io/replicateEverything/articles/shiny-app.html"
LIVE_DEMO_URL <- "https://shiny2.wzb.eu/ipi/replicate/"
# Share links (Studies table, replication sidebar) always use the public server URL above.
# Override without editing app.R: REPLICATE_SHINY_BASE_URL in local.R / server env.
DEFAULT_REGISTRY_REPO <- "replicate-anything/registry"

registry_stub_yaml_url <- function(folder) {
  # The registry stub (studies/<folder>.yml) always lives in the registry repo,
  # never in a study's own repository.
  sprintf(
    "https://raw.githubusercontent.com/%s/main/studies/%s.yml",
    DEFAULT_REGISTRY_REPO, folder
  )
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
    "replicateEverything"
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

find_shiny_monorepo_root <- function() {
  env_root <- Sys.getenv("REPLICATE_MONOREPO_ROOT", unset = "")
  if (nzchar(env_root) && file.exists(file.path(env_root, "registry", "index.csv"))) {
    return(normalizePath(env_root, winslash = "/", mustWork = FALSE))
  }

  if (requireNamespace("replicateEverything", quietly = TRUE)) {
    found <- tryCatch(
      get("auto_detect_monorepo_root", envir = asNamespace("replicateEverything"))(),
      error = function(e) NULL
    )
    if (!is.null(found)) {
      return(found)
    }
  }

  wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  shiny_pkg <- tryCatch(system.file("shiny", package = "replicateEverything"), error = function(e) "")
  pkg_root <- tryCatch(system.file(package = "replicateEverything"), error = function(e) "")
  candidates <- unique(c(
    wd,
    shiny_pkg,
    pkg_root,
    normalizePath(file.path(wd, ".."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(wd, "../.."), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(wd, "../../.."), winslash = "/", mustWork = FALSE)
  ))
  for (root in candidates) {
    if (dir.exists(file.path(root, "registry", "index.csv")) &&
        dir.exists(file.path(root, "replicateEverything"))) {
      return(root)
    }
  }
  NULL
}

shiny_configure_monorepo_study_folders <- function(monorepo = NULL) {
  if (is.null(monorepo) || !dir.exists(monorepo)) {
    monorepo <- find_shiny_monorepo_root()
  }
  if (is.null(monorepo) || !dir.exists(monorepo)) {
    return(invisible(NULL))
  }
  if (!file.exists(file.path(monorepo, "registry", "index.csv"))) {
    return(invisible(NULL))
  }
  options(
    replicateEverything.study_folders_root = monorepo,
    replicateEverything.replication_packages_root = monorepo,
    replicateEverything.use_sibling_packages = TRUE
  )
  message("Replicate Everything: using monorepo study folders at ", monorepo)
  invisible(monorepo)
}

#' Use a sibling registry/ package when developing in the monorepo;
#' otherwise fall back to GitHub (production default).
configure_registry_source <- function() {
  if (file.exists("local.R")) {
    source("local.R", local = FALSE)
    return(invisible(TRUE))
  }

  sibling_root <- find_shiny_monorepo_root()
  if (is.null(sibling_root)) {
    sibling_root <- normalizePath(file.path(".."), winslash = "/", mustWork = FALSE)
  }
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

  shiny_configure_monorepo_study_folders()

  if (dir.exists(sibling_pkg) && requireNamespace("devtools", quietly = TRUE)) {
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

find_replicate_everything_source_root <- function() {
  candidates <- character(0)
  if (using_local_replicate_everything()) {
    monorepo <- find_shiny_monorepo_root()
    if (!is.null(monorepo)) {
      candidates <- c(candidates, file.path(monorepo, "replicateEverything"))
    }
  }
  opt_root <- getOption("replicateEverything.package_source_root", NULL)
  if (!is.null(opt_root) && nzchar(opt_root)) {
    candidates <- c(candidates, opt_root)
  }
  pkg_path <- tryCatch(
    system.file(package = "replicateEverything"),
    error = function(e) ""
  )
  if (nzchar(pkg_path)) {
    candidates <- c(
      candidates,
      normalizePath(file.path(pkg_path, ".."), winslash = "/", mustWork = FALSE),
      normalizePath(file.path(pkg_path, "../.."), winslash = "/", mustWork = FALSE)
    )
  }
  candidates <- unique(candidates[nzchar(candidates)])
  for (root in candidates) {
    desc_path <- file.path(root, "DESCRIPTION")
    if (!file.exists(desc_path)) {
      next
    }
    desc <- tryCatch(readLines(desc_path, n = 10L, warn = FALSE), error = function(e) character(0))
    if (any(grepl("^Package:\\s*replicateEverything\\s*$", desc))) {
      return(normalizePath(root, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

find_git_root <- function(start_path) {
  if (is.null(start_path) || !nzchar(start_path)) {
    return(NULL)
  }
  cur <- normalizePath(start_path, winslash = "/", mustWork = FALSE)
  for (i in seq_len(6L)) {
    if (dir.exists(file.path(cur, ".git"))) {
      return(cur)
    }
    parent <- dirname(cur)
    if (identical(parent, cur)) {
      break
    }
    cur <- parent
  }
  NULL
}

git_command_output <- function(repo_root, ...) {
  if (is.null(repo_root) || !nzchar(repo_root)) {
    return(character(0))
  }
  args <- c(...)
  if (.Platform$OS.type == "windows") {
    cmd <- paste(
      c(
        "git",
        "-C",
        shQuote(normalizePath(repo_root, winslash = "/", mustWork = FALSE)),
        args
      ),
      collapse = " "
    )
    return(tryCatch(suppressWarnings(system(cmd, intern = TRUE)), error = function(e) character(0)))
  }
  tryCatch(
    system2("git", c("-C", repo_root, args), stdout = TRUE, stderr = FALSE),
    error = function(e) character(0)
  )
}

git_head_info <- function(start_path) {
  repo_root <- find_git_root(start_path)
  if (is.null(repo_root)) {
    return(list(sha = NULL, branch = NULL, dirty = FALSE, repo_root = NULL))
  }
  sha <- git_command_output(repo_root, "rev-parse", "--short", "HEAD")
  branch <- git_command_output(repo_root, "rev-parse", "--abbrev-ref", "HEAD")
  status <- git_command_output(repo_root, "status", "--porcelain")
  list(
    sha = if (length(sha)) as.character(sha[[1]]) else NULL,
    branch = if (length(branch)) as.character(branch[[1]]) else NULL,
    dirty = length(status) > 0L,
    repo_root = repo_root
  )
}

short_build_sha <- function(sha) {
  sha <- as.character(sha[[1]] %||% sha)
  if (length(sha) != 1L || is.na(sha) || !nzchar(sha)) {
    return(NA_character_)
  }
  sha <- sub("^\\++", "", sha)
  substr(sha, 1L, 7L)
}

read_build_sha_file <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) || !file.exists(path)) {
    return(NA_character_)
  }
  line <- tryCatch(
    trimws(readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8")),
    error = function(e) ""
  )
  if (!length(line) || !nzchar(line)) {
    return(NA_character_)
  }
  short_build_sha(line)
}

shiny_deploy_dir <- function() {
  app_env <- Sys.getenv("SHINY_APP_DIR", unset = "")
  if (length(app_env) == 1L && nzchar(app_env) && dir.exists(app_env)) {
    return(normalizePath(app_env, winslash = "/", mustWork = FALSE))
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

shiny_app_bundle_sha <- function() {
  for (path in c(
    file.path(shiny_deploy_dir(), "BUNDLE_SHA"),
    system.file("shiny", "BUNDLE_SHA", package = "replicateEverything")
  )) {
    sha <- read_build_sha_file(path)
    if (nzchar(sha)) {
      return(sha)
    }
  }
  NA_character_
}

package_build_sha <- function() {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    return(NA_character_)
  }
  ns <- asNamespace("replicateEverything")
  if (exists("package_build_info", envir = ns, inherits = FALSE)) {
    sha <- tryCatch(
      get("package_build_info", envir = ns)()$sha,
      error = function(e) NA_character_
    )
    if (nzchar(sha %||% "")) {
      return(sha)
    }
  }
  desc <- tryCatch(
    utils::packageDescription("replicateEverything"),
    error = function(e) NULL
  )
  if (!is.null(desc) && nzchar(desc$RemoteSha %||% "")) {
    return(short_build_sha(desc$RemoteSha))
  }
  read_build_sha_file(
    system.file("shiny", "BUNDLE_SHA", package = "replicateEverything")
  )
}

replicate_everything_build_info <- function() {
  version <- tryCatch(
    as.character(utils::packageVersion("replicateEverything")),
    error = function(e) "unknown"
  )
  source_root <- find_replicate_everything_source_root()
  git <- git_head_info(source_root)
  package_sha <- package_build_sha()
  app_sha <- shiny_app_bundle_sha()
  list(
    version = version,
    package_sha = package_sha,
    app_sha = app_sha,
    sha = package_sha,
    branch = git$branch,
    dirty = git$dirty,
    local_dev = using_local_replicate_everything(),
    source_root = source_root,
    git_root = git$repo_root,
    app_stale = isTRUE(
      nzchar(app_sha %||% "") &&
        nzchar(package_sha %||% "") &&
        !identical(app_sha, package_sha)
    )
  )
}

replicate_everything_build_label <- function() {
  info <- replicate_everything_build_info()
  parts <- c(paste0("replicateEverything ", info$version))
  if (nzchar(info$package_sha %||% "")) {
    sha_label <- info$package_sha
    if (isTRUE(info$dirty)) {
      sha_label <- paste0(sha_label, "+")
    }
    parts <- c(parts, paste0("pkg ", sha_label))
  }
  if (nzchar(info$app_sha %||% "")) {
    parts <- c(parts, paste0("app ", info$app_sha))
  }
  if (!is.null(info$branch) && nzchar(info$branch) && !identical(info$branch, "HEAD")) {
    parts <- c(parts, info$branch)
  }
  if (isTRUE(info$local_dev)) {
    parts <- c(parts, "dev load")
  }
  paste(parts, collapse = " · ")
}

shiny_app_stale_banner_ui <- function() {
  info <- replicate_everything_build_info()
  if (!isTRUE(info$app_stale)) {
    return(NULL)
  }
  tags$div(
    class = "alert alert-warning py-2 px-3 mb-0 rounded-0 border-0 border-bottom",
    tags$strong("Shiny app bundle is older than the installed package. "),
    "Package SHA ",
    tags$code(info$package_sha),
    " vs app ",
    tags$code(info$app_sha),
    ". Run ",
    tags$code("replicateEverything::save_local_shiny('<deploy-dir>')"),
    " after updating the package, then restart Shiny Server / Connect."
  )
}

app_build_footer_ui <- function() {
  tags$footer(
    class = "app-footer text-muted small px-3 py-2 border-top",
    tags$div(
      class = "d-flex flex-wrap justify-content-between gap-2",
      tags$span(replicate_everything_build_label())
    )
  )
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
  if (!exists(name, envir = ns, inherits = FALSE)) {
    pkg_ver <- tryCatch(
      as.character(utils::packageVersion("replicateEverything")),
      error = function(e) "unknown"
    )
    stop(
      "Function replicateEverything::", name,
      " is not available (installed version ", pkg_ver, "). ",
      "Update replicateEverything ",
      "(remotes::install_github('replicate-anything/replicateEverything')) ",
      "and redeploy the Shiny app from the same release.",
      call. = FALSE
    )
  }
  fn <- get(name, envir = ns, inherits = FALSE)
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

#' Compatibility check with fallback for older replicateEverything installs.
check_study_compat <- function(...) {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    stop("replicateEverything is not installed.", call. = FALSE)
  }
  ns <- asNamespace("replicateEverything")
  args <- list(...)
  if (exists("check_study_compatibility", envir = ns, inherits = FALSE)) {
    return(do.call(get("check_study_compatibility", envir = ns), args))
  }
  if (exists("study_system_compatibility", envir = ns, inherits = FALSE)) {
    return(do.call(get("study_system_compatibility", envir = ns), args))
  }
  replicate_fn("check_study_compatibility", ...)
}

#' Maintainer hint text with fallback when the export is missing.
maintainer_hint <- function(...) {
  if (!requireNamespace("replicateEverything", quietly = TRUE)) {
    stop("replicateEverything is not installed.", call. = FALSE)
  }
  ns <- asNamespace("replicateEverything")
  args <- list(...)
  if (exists("maintainer_dependency_hint", envir = ns, inherits = FALSE)) {
    return(do.call(get("maintainer_dependency_hint", envir = ns), args))
  }
  doi <- args$doi
  audit <- args$audit
  pkg_ver <- tryCatch(
    as.character(utils::packageVersion("replicateEverything")),
    error = function(e) "unknown"
  )
  lines <- c(
    "This machine is missing dependencies declared in replication.yml.",
    paste0("(replicateEverything ", pkg_ver, " — update package and redeploy Shiny.)")
  )
  if (!is.null(audit) && !is.null(audit$dependencies)) {
    for (eng in c("r", "python", "stata")) {
      block <- audit$dependencies[[eng]]
      if (is.null(block)) next
      missing <- block$missing %||% character(0)
      if (length(missing) == 0L || isTRUE(block$ok)) next
      label <- switch(eng, r = "R", python = "Python", stata = "Stata", eng)
      lines <- c(lines, paste0(label, " missing: ", paste(missing, collapse = ", ")))
    }
  }
  lines <- c(
    lines,
    "",
    "Maintainers — install for this study:",
    if (!is.null(doi) && nzchar(as.character(doi))) {
      paste0("  install_study_dependencies(", shQuote(as.character(doi), type = "sh"), ")")
    } else {
      "  install_study_dependencies(<doi>)"
    },
    "",
    "Live Run does not install packages."
  )
  paste(lines, collapse = "\n")
}

#' Resolve DOI / path input for Shiny study loading
#'
#' Registry dropdown selections use \code{normalize_doi()} only. The DOI/path
#' field uses \code{resolve_doi_input()} when available.
resolve_study_doi_input <- function(doi_input, from_registry = FALSE) {
  doi_input <- trimws(as.character(doi_input %||% ""))
  if (isTRUE(from_registry)) {
    if (!nzchar(doi_input)) {
      stop("Study DOI is required.", call. = FALSE)
    }
    return(list(
      doi = replicate_fn("normalize_doi", doi_input),
      local_root = NULL,
      is_local = FALSE
    ))
  }
  if (!nzchar(doi_input)) {
    doi_input <- "local"
  }
  replicate_fn("resolve_doi_input", doi_input)
}

ensure_replicate_everything()

doi_resolved_url <- function(doi, paper = NULL) {
  if (!is.null(paper) || (!is.null(doi) && length(doi) && nzchar(trimws(as.character(doi))))) {
    url <- tryCatch(
      replicate_fn("paper_article_url", doi = doi, paper = paper),
      error = function(e) NULL
    )
    if (!is.null(url) && nzchar(url)) {
      return(url)
    }
  }
  if (is.null(doi) || !length(doi) || !nzchar(trimws(as.character(doi)))) {
    return(NULL)
  }
  normalized <- tryCatch(
    replicate_fn("normalize_doi", doi),
    error = function(e) trimws(as.character(doi))
  )
  if (!nzchar(normalized)) {
    return(NULL)
  }
  paste0("https://doi.org/", normalized)
}

doi_link_ui <- function(doi, label = NULL, paper = NULL) {
  url <- doi_resolved_url(doi, paper = paper)
  if (is.null(url)) {
    return("")
  }
  display <- label
  if (is.null(display) || !nzchar(display)) {
    display <- tryCatch(
      replicate_fn("normalize_doi", doi),
      error = function(e) as.character(doi)
    )
  }
  tags$a(
    href = url,
    target = "_blank",
    rel = "noopener noreferrer",
    as.character(display)
  )
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1L && is.na(a))) b else a
}

coalesce_chr <- function(...) {
  for (x in list(...)) {
    if (is.null(x)) next
    x <- as.character(x)
    if (length(x) == 1L && !is.na(x) && nzchar(trimws(x))) {
      return(x)
    }
  }
  NULL
}

is_figure_replication <- function(type) {
  identical(as.character(type), "figure")
}

is_table_replication <- function(type) {
  identical(as.character(type), "table")
}

is_step_replication <- function(type) {
  identical(as.character(type), "step")
}

entry_engine <- function(x) {
  eng <- tolower(as.character(x$engine %||% ""))
  if (identical(eng, "stata")) return("stata")
  if (identical(eng, "python") || identical(eng, "py")) return("python")
  if (identical(eng, "r")) return("r")
  id <- as.character(x$id %||% "")
  code <- as.character(x$code %||% "")
  if (grepl("_stata$", id, ignore.case = TRUE) || grepl("\\.do$", code, ignore.case = TRUE)) {
    return("stata")
  }
  if (grepl("\\.(py|ipynb)$", code, ignore.case = TRUE)) {
    return("python")
  }
  "r"
}

prep_step_title <- function(prep_df, step_id) {
  if (is.null(prep_df) || !nrow(prep_df)) {
    return(NULL)
  }
  match <- prep_df[prep_df$id == step_id, , drop = FALSE]
  if (nrow(match) == 0) {
    return(NULL)
  }
  match$label_full[[1]] %||% match$label[[1]]
}

prep_step_language <- function(step_id, prep_steps) {
  if (is.null(prep_steps) || !length(prep_steps)) {
    return("r")
  }
  match <- prep_steps[vapply(prep_steps, function(x) identical(as.character(x$id), step_id), logical(1))]
  if (length(match) == 0L) {
    return("r")
  }
  entry_engine(match[[1]])
}

is_artifact_source <- function(source) {
  identical(as.character(source), "artifact")
}

is_live_source <- function(source) {
  identical(as.character(source), "live")
}

replication_source_label <- function(source, title) {
  title <- trimws(as.character(title %||% ""))
  if (!nzchar(title)) {
    title <- "this item"
  }
  if (is_artifact_source(source)) {
    return(paste0("Showing precomputed result for ", title))
  }
  if (is_live_source(source)) {
    return(paste0("Showing replication result for ", title))
  }
  paste0("Showing result for ", title)
}

replication_row_for_id <- function(replications_df, replication_id) {
  if (is.null(replications_df) || is.null(replication_id) || !nzchar(replication_id)) {
    return(NULL)
  }
  eq <- function(col) !is.na(col) & col == replication_id
  hit <- eq(replications_df$group) |
    eq(replications_df$id) |
    eq(replications_df$r_id) |
    eq(replications_df$stata_id) |
    eq(replications_df$python_id)
  match <- replications_df[which(hit), , drop = FALSE]
  if (nrow(match) == 0) {
    return(NULL)
  }
  match[1, , drop = FALSE]
}

selected_replication_title <- function(state) {
  prep_title <- prep_step_title(state$prep_df, state$selected_replication)
  if (!is.null(coalesce_chr(prep_title))) {
    return(prep_title)
  }
  row <- replication_row_for_id(state$replications_df, state$selected_replication)
  if (!is.null(row)) {
    title <- coalesce_chr(row$label_full[[1]], row$label[[1]])
    if (!is.null(title)) {
      return(title)
    }
  }
  coalesce_chr(
    replication_stub_label(
      state$selected_type %||% "table",
      state$selected_replication %||% ""
    ),
    state$selected_replication,
    "this item"
  )
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
  kind <- replicate_fn("replication_kind", meta, ctx)
  label <- switch(
    kind,
    package = "Package-backed study",
    folder = "Folder-backed study",
    registry = "Registry-embedded study",
    "Study"
  )
  slug <- if (identical(kind, "package")) {
    replicate_fn("package_repo_slug", meta, ctx)
  } else if (identical(kind, "folder")) {
    replicate_fn("study_repo_slug", meta, ctx)
  } else {
    NULL
  }
  if (is.null(slug) || !nzchar(slug)) {
    return(NULL)
  }
  return(list(
    type = label,
    kind = kind,
    repo = slug,
    url = github_repo_browse_url(slug)
  ))
}

study_materials_summary_ui <- function(
  doi,
  folder = NULL,
  repo = NULL,
  dual_engine = FALSE,
  maintainer_row = NULL
) {
  info <- study_materials_info(doi, folder = folder, repo = repo)
  if (is.null(info)) {
    return(NULL)
  }
  tags$p(
    class = "mb-0",
    strong("Replication type: "),
    info$type,
    if (isTRUE(dual_engine)) {
      tags$span(
        class = "text-muted",
        " — Replication code available in both R and Stata."
      )
    },
    br(),
    strong("Study materials: "),
    tags$a(href = info$url, target = "_blank", rel = "noopener", info$repo),
    if (!is.null(maintainer_row) && is.data.frame(maintainer_row) && nrow(maintainer_row) > 0) {
      maintainer_link_ui(maintainer_row)
    }
  )
}

artifact_missing <- function(result) {
  replicate_fn("artifact_display_missing", result)
}

#' Probe a resolved artifact candidate (local path or URL)
#'
#' Returns whether the file exists at the resolved location and, when it does,
#' whether it can actually be loaded for display. Used by the "not available"
#' panel to explain the mismatch when a file exists but did not render.
artifact_candidate_report <- function(path) {
  is_url <- grepl("^https?://", path, ignore.case = TRUE)

  if (!is_url) {
    exists <- file.exists(path)
    return(list(
      path = path,
      exists = exists,
      status = if (exists) "local file present" else "local file not found",
      loadable = exists
    ))
  }

  resp <- tryCatch(
    httr::GET(path, httr::user_agent("replicateEverything"), httr::timeout(15)),
    error = function(e) e
  )
  if (inherits(resp, "error")) {
    return(list(path = path, exists = NA, status = paste0("network error: ", conditionMessage(resp)), loadable = FALSE))
  }
  code <- httr::status_code(resp)
  if (code >= 400L) {
    return(list(path = path, exists = FALSE, status = paste0("HTTP ", code), loadable = FALSE))
  }

  loaded <- tryCatch(
    replicate_fn("load_artifact_file_path", path),
    error = function(e) e
  )
  loadable <- !inherits(loaded, "error") &&
    !isTRUE(replicate_fn("artifact_content_missing", loaded))
  list(
    path = path,
    exists = TRUE,
    status = paste0("HTTP ", code, if (loadable) ", loads OK" else ", present but did not load"),
    loadable = loadable
  )
}

artifact_missing_ui <- function(doi, what, folder = NULL, repo = NULL, kind = "output") {
  candidates <- tryCatch(
    replicate_fn("artifact_lookup_candidates", doi, what, folder = folder, repo = repo),
    error = function(e) character(0)
  )
  reports <- lapply(candidates, function(p) tryCatch(artifact_candidate_report(p), error = function(e) NULL))
  reports <- Filter(Negate(is.null), reports)
  exists_but_unloaded <- Filter(function(r) isTRUE(r$exists) && !isTRUE(r$loadable), reports)

  tagList(
    tags$div(
      class = "alert alert-secondary",
      tags$strong(paste0("No precomputed ", kind, " available.")),
      if (length(exists_but_unloaded) > 0) {
        tags$div(
          class = "alert alert-warning small",
          tags$strong("But the artifact file does exist. "),
          "It was found at the location below but could not be loaded into this session. ",
          "Likely causes: a transient network/proxy/TLS problem reaching ",
          tags$code("raw.githubusercontent.com"),
          ", or the running app is on a stale build. ",
          "Reload the page; if it persists, reinstall the package and relaunch, or click ",
          tags$strong("Run"), " to regenerate it live."
        )
      },
      tags$p(
        "The registry lists this replication, but the artifact file is not available yet.",
        " Click ", tags$strong("Run"), " to generate it live."
      ),
      tags$p(
        class = "small mb-0",
        "Folder-backed studies: run ",
        tags$code("build_study_artifacts()"),
        "Folder-backed studies: run ",
        tags$code("build_study_artifacts()"),
        " in the study repository (writes ",
        tags$code("outputs/"),
        " paths declared in ",
        tags$code("replication.yml"),
        "). ",
        "Registry studies: build ",
        tags$code("outputs/"),
        " with ",
        tags$code("registry/scripts/build_artifacts.R"),
        ". ",
        "Package-backed studies: run ",
        tags$code("build_report()"),
        " in the study R package ",
        "(writes ",
        tags$code("inst/report/artifacts/"),
        ")."
      ),
      if (length(reports) > 0) {
        tagList(
          tags$p(class = "mb-1", tags$strong("Expected artifact:")),
          tags$ul(
            class = "small mb-0",
            lapply(reports, function(r) {
              badge_class <- if (isTRUE(r$exists) && isTRUE(r$loadable)) {
                "text-success"
              } else if (isTRUE(r$exists)) {
                "text-warning"
              } else {
                "text-danger"
              }
              tags$li(
                tags$code(r$path),
                tags$span(class = paste("ms-2", badge_class), paste0("[", r$status, "]"))
              )
            })
          )
        )
      }
    )
  )
}

load_registry_index <- function() {
  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (!is.null(registry_root) && dir.exists(registry_root)) {
    local_csv <- file.path(registry_root, "index.csv")
    if (file.exists(local_csv)) {
      df <- tryCatch({
        idx <- utils::read.csv(local_csv, stringsAsFactors = FALSE)
        options(replicateEverything.index = idx)
        idx <- replicateEverything::load_index()
        idx$doi <- replicate_fn("normalize_doi", idx$doi)
        if (!"repo" %in% names(idx)) idx$repo <- DEFAULT_REGISTRY_REPO
        idx
      }, error = function(e) NULL)
      if (!is.null(df)) {
        return(df)
      }
    }
  }

  df <- tryCatch({
    idx <- replicateEverything::load_index()
    idx$doi <- replicate_fn("normalize_doi", idx$doi)
    if (!"repo" %in% names(idx)) idx$repo <- DEFAULT_REGISTRY_REPO
    idx
  }, error = function(e) NULL)

  if (!is.null(df) && "folder" %in% names(df)) return(df)

  tryCatch({
    df <- utils::read.csv(REGISTRY_INDEX_URL, stringsAsFactors = FALSE)
    df$doi <- replicate_fn("normalize_doi", df$doi)
    df$repo <- DEFAULT_REGISTRY_REPO
    if (requireNamespace("replicateEverything", quietly = TRUE)) {
      df <- get("ensure_index_handles", envir = asNamespace("replicateEverything"))(df)
    }
    df
  }, error = function(e) NULL)
}

registry_index <- load_registry_index()

registry_audit_summary <- tryCatch(
  replicate_fn("load_registry_audit_summary"),
  error = function(e) NULL
)

study_audit_dep_line <- function(engine, dep) {
  label <- switch(
    engine,
    r = "R",
    stata = "Stata",
    python = "Python",
    toupper(engine)
  )
  if (is.null(dep)) {
    return(NULL)
  }
  ok <- dep$ok
  status_class <- if (isTRUE(ok)) {
    "study-audit-ok"
  } else if (is.na(ok)) {
    "study-audit-warn"
  } else {
    "study-audit-fail"
  }
  status_text <- if (isTRUE(ok)) {
    "OK"
  } else if (is.na(ok)) {
    "Deferred"
  } else {
    "Missing"
  }
  detail <- character(0)
  if (identical(engine, "r") && length(dep$required %||% character(0)) > 0L) {
    detail <- c(detail, paste(dep$required, collapse = ", "))
  }
  if (identical(engine, "stata") && nzchar(dep$probe %||% "")) {
    detail <- c(detail, paste0("probe: ", dep$probe))
  }
  if (identical(engine, "python") && length(dep$required %||% character(0)) > 0L) {
    detail <- c(detail, paste(dep$required, collapse = ", "))
  }
  missing <- dep$missing %||% character(0)
  if (length(missing) > 0L) {
    detail <- c(detail, paste0("missing: ", paste(missing, collapse = ", ")))
  }
  tags$div(
    class = "study-audit-row",
    tags$span(class = paste("study-audit-status", status_class), paste0(label, ": ", status_text)),
    if (length(detail) > 0L) {
      tags$span(class = "study-audit-detail text-muted", paste(detail, collapse = " · "))
    }
  )
}

study_audit_ui <- function(audit, compact = FALSE) {
  if (is.null(audit)) {
    return(NULL)
  }
  if (!is.null(audit$error)) {
    return(tags$div(
      class = "alert alert-warning study-audit small mb-0",
      tags$strong("System compatibility: "),
      audit$error
    ))
  }

  engines <- audit$languages %||% audit$engines %||% character(0)
  deps <- audit$dependencies %||% list()
  reg <- audit$registry_audit %||% list()

  engine_label <- if (length(engines) == 0L) {
    "none declared"
  } else {
    paste(
      vapply(engines, function(e) {
        switch(e, r = "R", stata = "Stata", python = "Python", e)
      }, character(1)),
      collapse = ", "
    )
  }

  reg_block <- if (!isTRUE(reg$available)) {
    NULL
  } else if (isTRUE(reg$not_in_audit)) {
    tags$p(
      class = "study-audit-row text-muted mb-0",
      "Registry audit: this study was not in the latest audit snapshot."
    )
  } else {
    reg_ok <- (reg$failed %||% 0L) == 0L
    reg_class <- if (reg_ok) "study-audit-ok" else "study-audit-fail"
    tagList(
      tags$p(
        class = "study-audit-row mb-1",
        tags$span(
          class = paste("study-audit-status", reg_class),
          sprintf(
            "Registry audit%s: %d / %d passed",
            if (nzchar(reg$finished_at %||% "")) paste0(" (", reg$finished_at, ")") else "",
            reg$passed %||% 0L,
            reg$total %||% 0L
          )
        )
      ),
      if (!reg_ok && !is.null(reg$failures) && nrow(reg$failures) > 0L) {
        tags$ul(
          class = "study-audit-failures small mb-0",
          lapply(seq_len(min(6L, nrow(reg$failures))), function(i) {
            row <- reg$failures[i, , drop = FALSE]
            label <- row$object_label %||% row$object %||% "?"
            eng <- row$engine %||% "?"
            snippet <- trimws(as.character(row$error_snippet %||% ""))
            if (nchar(snippet) > 80L) {
              snippet <- paste0(substr(snippet, 1L, 77L), "...")
            }
            tags$li(
              tags$code(paste0(label, " (", eng, ")")),
              if (nzchar(snippet)) paste0(" — ", snippet)
            )
          }),
          if (nrow(reg$failures) > 6L) {
            tags$li(class = "text-muted", sprintf("… and %d more", nrow(reg$failures) - 6L))
          }
        )
      }
    )
  }

  summary_class <- if (isTRUE(audit$ready)) {
    "alert-success"
  } else if (isTRUE(audit$install_needed)) {
    "alert-warning"
  } else {
    "alert-secondary"
  }
  summary_text <- if (isTRUE(audit$ready)) {
    "Ready — nothing to install before Run."
  } else if (isTRUE(audit$install_needed)) {
    "Some dependencies are missing on this machine (maintainer install required)."
  } else {
    "Dependency check incomplete for one or more engines."
  }

  dep_lines <- Filter(
    Negate(is.null),
    list(
      study_audit_dep_line("r", deps$r),
      study_audit_dep_line("stata", deps$stata),
      study_audit_dep_line("python", deps$python)
    )
  )

  py_exe <- audit$dependencies$python$python %||% NULL
  py_note <- if (!is.null(py_exe) && nzchar(py_exe)) {
    tags$p(
      class = "study-audit-row mb-0 text-muted",
      "Python: ",
      tags$code(py_exe)
    )
  } else {
    NULL
  }

  if (isTRUE(compact)) {
    return(tags$div(
      class = paste("study-audit-compact small mb-2", summary_class),
      tags$div(class = "study-audit-deps", dep_lines),
      py_note,
      tags$span(class = "study-audit-summary text-muted", summary_text)
    ))
  }

  tags$div(
    class = paste("alert study-audit small mb-0", summary_class),
    tags$div(class = "study-audit-title", tags$strong("System compatibility")),
    tags$p(
      class = "study-audit-row mb-1 text-muted",
      "Declared in ",
      tags$code("replication.yml"),
      " — checked on this machine only."
    ),
    tags$p(class = "study-audit-row mb-1", tags$span(class = "text-muted", "Languages: "), engine_label),
    if (length(dep_lines) > 0L) {
      tags$div(class = "study-audit-deps", dep_lines)
    },
    reg_block,
    tags$p(class = "study-audit-summary mb-0 mt-2", summary_text)
  )
}

dependency_hint_modal <- function(session, doi, audit = NULL, title = "Missing dependencies") {
  hint <- tryCatch(
    maintainer_hint(
      doi = doi,
      audit = audit
    ),
    error = function(e) conditionMessage(e)
  )
  showModal(modalDialog(
    title = title,
    tags$p(
      class = "text-muted small",
      "Live Run checks dependencies only and does not install packages."
    ),
    tags$pre(
      style = "white-space: pre-wrap; font-size: 0.82rem; max-height: 420px; overflow-y: auto;",
      hint
    ),
    easyClose = TRUE,
    footer = modalButton("Close")
  ))
}

registry_health_bar_ui <- function(summary) {
  if (is.null(summary)) {
    return(NULL)
  }
  total <- as.integer(summary$runs %||% 0)
  ok <- as.integer(summary$success %||% 0)
  if (!is.finite(total) || total <= 0L) {
    return(NULL)
  }
  ok <- max(0L, min(ok, total))
  pct_ok <- 100 * ok / total
  pct_fail <- 100 - pct_ok
  finished <- summary$finished_at %||% ""
  tags$div(
    class = "registry-health-wrap",
    tags$div(
      class = "registry-health-bar",
      title = sprintf(
        "Registry audit: %d of %d tables/figures replicating%s",
        ok,
        total,
        if (nzchar(finished)) paste0(" (", finished, ")") else ""
      ),
      tags$div(class = "registry-health-ok", style = sprintf("width:%.4f%%", pct_ok)),
      tags$div(class = "registry-health-fail", style = sprintf("width:%.4f%%", pct_fail))
    ),
    tags$span(
      class = "registry-health-label",
      sprintf("%d / %d replicating", ok, total)
    )
  )
}

nice_doi_choices <- function(index_df) {
  if (is.null(index_df) || nrow(index_df) == 0) return(character(0))
  idx <- index_df[nzchar(index_df$doi), , drop = FALSE]
  labels <- vapply(seq_len(nrow(idx)), function(i) {
    row <- idx[i, , drop = FALSE]
    author <- format_author_label(row$authors[[1]])
    year <- row$year[[1]] %||% ""
    paste0(author, " (", year, ")")
  }, character(1))
  ord <- order(
    vapply(strsplit(idx$authors, ",\\s*"), function(x) {
      first_author_surname(trimws(x[[1]] %||% ""))
    }, character(1)),
    idx$year,
    idx$title
  )
  setNames(idx$doi[ord], labels[ord])
}

truncate_label <- function(text, max_chars = 40L) {
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

engine_icon_python <- function() {
  tags$svg(
    xmlns = "http://www.w3.org/2000/svg",
    viewBox = "0 0 24 24",
    width = "18",
    height = "18",
    `aria-hidden` = "true",
    tags$rect(x = "1.5", y = "4", width = "21", height = "16", rx = "2.5", fill = "#3776AB"),
    tags$text(
      x = "12", y = "15.5", `text-anchor` = "middle",
      fill = "#FFD43B", `font-size` = "8", `font-weight` = "700",
      `font-family` = "Arial, sans-serif"
    , "Py")
  )
}

engine_icons_display <- function(has_r = FALSE, has_stata = FALSE, has_python = FALSE) {
  if (!has_r && !has_stata && !has_python) {
    return(tags$span(class = "text-muted small", "—"))
  }
  tags$div(
    class = "engine-icons-cell",
    if (has_r) tags$span(class = "engine-badge", title = "R", engine_icon_r()),
    if (has_stata) tags$span(class = "engine-badge", title = "Stata", engine_icon_stata()),
    if (has_python) tags$span(class = "engine-badge", title = "Python", engine_icon_python())
  )
}

repo_icon_folder <- function() {
  tags$svg(
    xmlns = "http://www.w3.org/2000/svg",
    viewBox = "0 0 24 24",
    width = "18",
    height = "18",
    `aria-hidden` = "true",
    fill = "#5c6b7a",
    tags$path(
      d = "M10 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z"
    )
  )
}

study_repo_url_for_row <- function(row) {
  slug <- if ("repo" %in% names(row)) as.character(row$repo[[1]] %||% "") else ""
  if (length(slug) != 1L || is.na(slug) || !nzchar(slug)) {
    return(NA_character_)
  }
  paste0("https://github.com/", slug)
}

repo_link_display <- function(repo_url) {
  if (length(repo_url) != 1L || is.na(repo_url) || !nzchar(repo_url)) {
    return(tags$span(class = "text-muted small", "—"))
  }
  tags$a(
    href = repo_url,
    target = "_blank",
    rel = "noopener",
    class = "study-repo-link",
    title = "Open study repository",
    repo_icon_folder()
  )
}

study_engine_availability <- function(reps) {
  has_r <- FALSE
  has_stata <- FALSE
  has_python <- FALSE
  if (is.null(reps) || !length(reps)) {
    return(list(r = FALSE, stata = FALSE, python = FALSE))
  }
  for (x in reps) {
    eng <- entry_engine(x)
    if (identical(eng, "stata")) {
      has_stata <- TRUE
    } else if (identical(eng, "python")) {
      has_python <- TRUE
    } else {
      has_r <- TRUE
    }
  }
  list(r = has_r, stata = has_stata, python = has_python)
}

study_engine_availability_for_row <- function(row, repo = DEFAULT_REGISTRY_REPO) {
  langs <- row$languages[[1]] %||% ""
  if (nzchar(langs)) {
    parts <- tolower(strsplit(langs, "[|;]")[[1]])
    parts <- trimws(parts)
    parts <- parts[nzchar(parts)]
    return(list(
      r = "r" %in% parts,
      stata = "stata" %in% parts,
      python = "python" %in% parts || "py" %in% parts
    ))
  }
  folder <- row$folder[[1]] %||% NULL
  if (is.null(folder) || !nzchar(folder)) {
    return(list(r = TRUE, stata = FALSE, python = FALSE))
  }
  reps <- tryCatch(
    fetch_study_replications_index(folder, repo %||% DEFAULT_REGISTRY_REPO),
    error = function(e) NULL
  )
  study_engine_availability(reps)
}

parse_index_collections <- function(row) {
  raw <- row$collections[[1]] %||% ""
  if (!nzchar(raw)) {
    return(character(0))
  }
  parts <- unlist(strsplit(raw, "[|;]", perl = TRUE))
  parts <- trimws(parts)
  unique(parts[nzchar(parts)])
}

collection_tag_abbrev <- function(collection) {
  switch(
    trimws(collection),
    "American Political Science Review" = "APSR",
    "APSR" = "APSR",
    "PED" = "PED",
    "Political Economy of Development" = "PED",
    "World Bank" = "WB",
    "IPI" = "IPI",
    {
      abbr <- toupper(gsub("[^A-Za-z]", "", collection))
      if (nzchar(abbr)) {
        substr(abbr, 1L, min(4L, nchar(abbr)))
      } else {
        collection
      }
    }
  )
}

collection_tag_class <- function(collection) {
  abbr <- collection_tag_abbrev(collection)
  switch(
    abbr,
    "APSR" = "collection-tag-apsr",
    "PED" = "collection-tag-ped",
    "WB" = "collection-tag-wb",
    "IPI" = "collection-tag-ipi",
    "collection-tag-other"
  )
}

collections_column_ui <- function(collections, max_tags = 3L) {
  if (length(collections) == 0L) {
    return(tags$span(class = "text-muted", "—"))
  }
  show <- collections[seq_len(min(length(collections), max_tags))]
  extra <- length(collections) - length(show)
  tagList(
    lapply(show, function(c) {
      abbr <- collection_tag_abbrev(c)
      tags$span(
        class = paste("collection-tag", collection_tag_class(c)),
        title = c,
        abbr
      )
    }),
    if (extra > 0L) {
      tags$span(class = "collection-tag collection-tag-more", paste0("+", extra))
    }
  )
}

collections_legend_ui <- function() {
  tags$div(
    class = "collections-legend text-muted small mt-3",
    tags$span(class = "collections-legend-label", "Collections: "),
    tags$span(class = "collection-tag collection-tag-apsr", title = "APSR", "APSR"),
    " American Political Science Review · ",
    tags$span(class = "collection-tag collection-tag-ped", title = "PED", "PED"),
    " Political economy of development · ",
    tags$span(class = "collection-tag collection-tag-wb", title = "World Bank", "WB"),
    " World Bank · ",
    tags$span(class = "collection-tag collection-tag-ipi", title = "IPI", "IPI"),
    " IPI studies"
  )
}

maintainer_link_ui <- function(row) {
  name <- trimws(as.character(row$maintainer_name[[1]] %||% ""))
  email <- trimws(as.character(row$maintainer_email[[1]] %||% ""))
  if (!nzchar(name) && !nzchar(email)) {
    return(NULL)
  }
  tip <- if (nzchar(name) && nzchar(email)) {
    paste0(name, " (", email, ")")
  } else if (nzchar(name)) {
    name
  } else {
    email
  }
  tags$span(
    class = "maintainer-link-wrap",
    " ",
    tags$a(
      href = if (nzchar(email)) paste0("mailto:", email) else "#",
      class = "maintainer-link",
      title = tip,
      "[maintainer]"
    )
  )
}

ALL_STUDIES_COLLECTION <- "__all_studies__"

registry_collection_choices <- function(index_df) {
  if (is.null(index_df) || nrow(index_df) == 0) {
    return(c("All studies" = ALL_STUDIES_COLLECTION))
  }
  cols <- unique(unlist(lapply(seq_len(nrow(index_df)), function(i) {
    parse_index_collections(index_df[i, , drop = FALSE])
  })))
  cols <- sort(cols[nzchar(cols)])
  c("All studies" = ALL_STUDIES_COLLECTION, setNames(cols, cols))
}

filter_index_by_collection <- function(index_df, collection = "") {
  if (is.null(index_df) || nrow(index_df) == 0) {
    return(index_df)
  }
  collection <- trimws(as.character(collection %||% ""))
  if (!nzchar(collection) || identical(collection, ALL_STUDIES_COLLECTION)) {
    return(index_df)
  }
  keep <- vapply(seq_len(nrow(index_df)), function(i) {
    collection %in% parse_index_collections(index_df[i, , drop = FALSE])
  }, logical(1))
  index_df[keep, , drop = FALSE]
}

shiny_deep_link_query_list <- function(doi, what = NULL, language = NULL) {
  doi_norm <- tryCatch(
    replicate_fn("normalize_doi", doi),
    error = function(e) trimws(as.character(doi))
  )
  out <- list(doi = doi_norm)
  what <- trimws(as.character(what %||% ""))
  if (nzchar(what)) {
    out$what <- what
  }
  lang <- tolower(trimws(as.character(language %||% "")))
  if (nzchar(lang) && !identical(lang, "r")) {
    out$language <- lang
  }
  out
}

shiny_query_string <- function(params) {
  if (is.null(params) || length(params) == 0L) {
    return("")
  }
  names <- names(params)
  if (is.null(names)) {
    return("")
  }
  parts <- vapply(seq_along(params), function(i) {
    paste0(
      URLencode(names[[i]], reserved = TRUE),
      "=",
      URLencode(as.character(params[[i]]), reserved = TRUE)
    )
  }, character(1))
  paste(parts[nzchar(parts)], collapse = "&")
}

shiny_share_base_url <- function() {
  env_base <- Sys.getenv("REPLICATE_SHINY_BASE_URL", unset = "")
  if (nzchar(env_base)) {
    return(sub("/+$", "", env_base))
  }
  sub("/+$", "", LIVE_DEMO_URL)
}

shiny_share_url <- function(params) {
  qs <- shiny_query_string(params)
  base <- shiny_share_base_url()
  if (nzchar(qs)) {
    paste0(base, "?", qs)
  } else {
    base
  }
}

link_icon_svg <- function() {
  HTML(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" ',
    'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ',
    'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">',
    '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path>',
    '<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path>',
    "</svg>"
  ))
}

share_link_ui <- function(params, title = "Link to this page") {
  href <- shiny_share_url(params)
  tags$a(
    href = href,
    class = "study-share-link",
    title = paste0(title, "\n", href),
    target = "_blank",
    rel = "noopener noreferrer",
    `aria-label` = title,
    link_icon_svg()
  )
}

study_dag_chain_ui <- function(path) {
  if (is.null(path) || length(path) == 0L) {
    return(NULL)
  }
  nodes <- lapply(seq_along(path), function(i) {
    node <- path[[i]]
    label <- as.character(node$label %||% node$id)
    short <- if (nchar(label) > 28L) {
      paste0(substr(label, 1L, 26L), "...")
    } else {
      label
    }
    desc <- trimws(as.character(node$description %||% ""))
    tip <- if (identical(node$kind %||% "", "data")) {
      if (nzchar(desc)) {
        paste0("Raw data\n", desc)
      } else {
        "Raw data"
      }
    } else if (nzchar(desc)) {
      paste0(label, " — ", desc)
    } else {
      label
    }
    node_class <- paste(
      "study-dag-node",
      if (identical(node$kind %||% "", "data")) "is-data" else "is-step"
    )
    tags$span(class = node_class, title = tip, short)
  })
  parts <- vector("list", length(nodes) * 2L - 1L)
  for (i in seq_along(nodes)) {
    parts[[2L * i - 1L]] <- nodes[[i]]
    if (i < length(nodes)) {
      parts[[2L * i]] <- tags$span(class = "study-dag-arrow", "\u2192")
    }
  }
  tags$div(class = "study-dag-chain", parts)
}

study_dag_facet_ui <- function(facet) {
  if (is.null(facet) || length(facet$paths) == 0L) {
    return(NULL)
  }
  tags$div(
    class = "study-dag-facet",
    tags$div(class = "study-dag-facet-title", facet$title),
    lapply(facet$paths, study_dag_chain_ui)
  )
}

study_dag_legend_ui <- function() {
  tags$div(
    class = "study-dag-legend small text-muted mt-3 pt-2",
    tags$span(class = "me-1", "Key:"),
    tags$span(class = "study-dag-node is-data study-dag-legend-swatch me-1", "raw data"),
    tags$span(class = "study-dag-node is-step study-dag-legend-swatch", "analysis step")
  )
}

study_dag_panel_body_ui <- function(facets, heading = TRUE) {
  if (is.null(facets) || length(facets) == 0L) {
    return(NULL)
  }
  tags$div(
    class = "study-dag-panel",
    if (heading) {
      tags$div(class = "study-dag-heading small text-muted mb-2", "Steps pipeline")
    },
    tags$div(
      class = "study-dag-facets",
      lapply(facets, study_dag_facet_ui)
    ),
    study_dag_legend_ui()
  )
}

study_dag_facets_for <- function(doi, folder = NULL, repo = NULL) {
  meta <- tryCatch(
    replicate_fn("get_replication_meta", doi, folder = folder, repo = repo),
    error = function(e) NULL
  )
  if (is.null(meta)) {
    return(NULL)
  }
  tryCatch(
    replicate_fn("study_dag_facets", meta),
    error = function(e) NULL
  )
}

study_dag_link_ui <- function(doi, folder = NULL, repo = NULL) {
  facets <- study_dag_facets_for(doi, folder = folder, repo = repo)
  if (is.null(facets) || length(facets) == 0L) {
    return(NULL)
  }
  tags$p(
    class = "mb-0 mt-2",
    actionLink(
      "show_study_pipeline",
      "View steps pipeline",
      class = "study-dag-link"
    )
  )
}

study_dag_panel_ui <- function(doi, folder = NULL, repo = NULL, heading = TRUE) {
  facets <- study_dag_facets_for(doi, folder = folder, repo = repo)
  if (is.null(facets) || length(facets) == 0L) {
    return(NULL)
  }
  tags$div(
    class = if (heading) "mt-3" else NULL,
    study_dag_panel_body_ui(facets, heading = heading)
  )
}

collections_badges_ui <- function(collections) {
  collections_column_ui(collections)
}

contribute_step_title <- function(text, kind = c("folder", "package", "registry", "check")) {
  kind <- match.arg(kind)
  color <- switch(
    kind,
    folder = "#0d6efd",
    package = "#198754",
    registry = "#6f42c1",
    check = "#fd7e14"
  )
  tags$h5(class = "contribute-step-title", style = paste0("color:", color, ";"), text)
}

replication_stub_label <- function(type, id) {
  prefix <- switch(
    as.character(type),
    figure = "Fig",
    table = "Table",
    step = "Step",
    prep = "Step",
    pipeline = "Step",
    "Item"
  )
  num <- sub("^[^0-9]*([0-9]+).*", "\\1", as.character(id))
  if (!nzchar(num)) {
    num <- as.character(id)
  }
  paste0(prefix, " ", num)
}

replication_display_label <- function(x) {
  yaml_label <- x$label %||% NULL
  if (!is.null(yaml_label)) {
    lab <- trimws(as.character(yaml_label[[1]] %||% yaml_label))
    if (length(lab) == 1L && !is.na(lab) && nzchar(lab)) {
      return(lab)
    }
  }
  replication_stub_label(x$type, x$id)
}

replication_entry_description <- function(x) {
  desc <- x$description %||% NULL
  if (is.null(desc) || length(desc) == 0L) {
    return("")
  }
  d <- trimws(as.character(desc[[1]] %||% desc))
  if (length(d) != 1L || is.na(d)) {
    return("")
  }
  d
}

prep_to_df <- function(prep_steps) {
  if (is.null(prep_steps) || length(prep_steps) == 0) {
    return(NULL)
  }
  rows <- lapply(prep_steps, function(x) {
    if (!is.list(x) || is.null(x$id)) {
      return(NULL)
    }
    label <- as.character(x$label %||% x$id)
    desc <- replication_entry_description(x)
    label_full <- if (nzchar(desc)) desc else label
    data.frame(
      id = as.character(x$id),
      label = truncate_label(label, 40L),
      label_full = label_full,
      engine = entry_engine(x),
      type = "step",
      stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) return(NULL)
  do.call(rbind, rows)
}

replications_to_df <- function(reps) {
  if (is.null(reps) || length(reps) == 0) return(NULL)
  reps <- reps[vapply(reps, function(x) {
    is.list(x) && !is.null(x$id) && nzchar(as.character(x$id[[1]] %||% x$id))
  }, logical(1))]
  reps <- reps[vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    if (!type %in% c("figure", "table")) {
      return(FALSE)
    }
    # A displayable entry is runnable or has a precomputed artifact. Folder
    # studies declare a `code:` path; package-backed studies declare `make:`
    # (an R function) instead. Either, or a declared `artifact:`, qualifies.
    has_code <- nzchar(as.character(x$code %||% ""))
    has_make <- nzchar(as.character(x$make %||% ""))
    has_artifact <- nzchar(as.character(x$artifact %||% ""))
    has_code || has_make || has_artifact
  }, logical(1))]
  if (length(reps) == 0) return(NULL)

  rep_engine <- entry_engine

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
    python_reps <- group_reps[vapply(group_reps, function(x) identical(rep_engine(x), "python"), logical(1))]
    primary <- if (length(r_reps)) r_reps[[1]] else if (length(python_reps)) python_reps[[1]] else group_reps[[1]]
    data.frame(
      group = group,
      id = as.character(primary$id),
      r_id = if (length(r_reps)) as.character(r_reps[[1]]$id) else NA_character_,
      stata_id = if (length(stata_reps)) as.character(stata_reps[[1]]$id) else NA_character_,
      python_id = if (length(python_reps)) as.character(python_reps[[1]]$id) else NA_character_,
      label = truncate_label(replication_display_label(primary), 40L),
      label_full = {
        desc <- replication_entry_description(primary)
        if (nzchar(desc)) desc else replication_display_label(primary)
      },
      type = as.character(primary$type),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, rows)
}

resolve_group_replication_id <- function(row, engine = c("r", "stata", "python")) {
  engine <- match.arg(engine)
  if (engine == "stata" && !is.na(row$stata_id) && nzchar(row$stata_id)) {
    return(row$stata_id)
  }
  if (engine == "python" && !is.na(row$python_id) && nzchar(row$python_id)) {
    return(row$python_id)
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
  doi_raw <- row$doi[[1]] %||% ""
  doi <- if (nzchar(doi_raw)) {
    tryCatch(replicate_fn("normalize_doi", doi_raw), error = function(e) doi_raw)
  } else {
    ""
  }
  journal_raw <- strip_html_entities(row$journal[[1]])
  journal_line <- tagList(
    if (nzchar(journal_raw)) {
      tags$em(journal_raw)
    } else {
      tags$em("Working paper")
    },
    if (nzchar(doi)) {
      paper_link <- list(doi = doi_raw)
      if ("article_url" %in% names(row)) {
        au <- row$article_url[[1]] %||% ""
        if (nzchar(as.character(au))) {
          paper_link$article_url <- as.character(au)
        }
      }
      tagList(" ", doi_link_ui(doi_raw %||% doi, paper = paper_link))
    }
  )
  list(
    line1 = sprintf('%s (%s) "%s"', author, year, title),
    line2 = journal_line
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

read_local_registry_stub <- function(folder) {
  registry_root <- getOption("replicateEverything.registry_root", NULL)
  if (is.null(registry_root) || !dir.exists(registry_root)) {
    return(NULL)
  }
  path <- file.path(registry_root, "studies", paste0(folder, ".yml"))
  if (!file.exists(path)) {
    path <- file.path(registry_root, "papers", paste0(folder, ".yml"))
  }
  if (file.exists(path)) {
    return(read_yaml_from_url(path))
  }
  draft_path <- file.path(registry_root, "drafts", paste0(folder, ".yml"))
  if (file.exists(draft_path)) {
    return(read_yaml_from_url(draft_path))
  }
  NULL
}

read_local_study_replication_index <- function(stub, folder, repo = DEFAULT_REGISTRY_REPO) {
  doi <- stub$paper$doi %||% NULL
  if (is.null(doi) || !length(doi)) {
    return(NULL)
  }
  ctx <- tryCatch(
    replicate_fn(
      "paper_context",
      replicate_fn("normalize_doi", doi),
      repo = repo,
      folder = folder
    ),
    error = function(e) NULL
  )
  if (is.null(ctx) || is.null(ctx$local_root) || !dir.exists(ctx$local_root)) {
    return(NULL)
  }
  local_yml <- file.path(ctx$local_root, "replication.yml")
  if (!file.exists(local_yml)) {
    return(NULL)
  }
  study_meta <- read_yaml_from_url(local_yml)
  study_yaml_replication_index(study_meta)
}

study_yaml_replication_index <- function(study_meta) {
  if (is.null(study_meta)) {
    return(NULL)
  }
  steps <- study_meta$steps %||% list()
  if (length(steps) > 0L) {
    return(replicate_fn("study_step_entries", study_meta))
  }
  reps <- study_meta$replications %||% list()
  if (length(reps) > 0L) {
    return(c(study_meta$prep %||% list(), reps))
  }
  NULL
}

fetch_study_replications_index <- function(folder, repo = DEFAULT_REGISTRY_REPO) {
  stub <- read_local_registry_stub(folder)
  if (is.null(stub)) {
    registry_url <- registry_stub_yaml_url(folder)
    stub <- read_yaml_from_url(registry_url)
  }
  if (is.null(stub)) {
    stop("Could not read registry stub for folder ", folder, call. = FALSE)
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
    local_reps <- read_local_study_replication_index(stub, folder, repo = repo)
    if (!is.null(local_reps) && length(local_reps) > 0L) {
      return(local_reps)
    }
    study_repo <- as.character((stub$repo %||% stub$paper$study_repo)[[1]])
    ref <- as.character((stub$paper$study_ref %||% stub$study_ref %||% list("main"))[[1]])
    study_url <- sprintf(
      "https://raw.githubusercontent.com/%s/%s/replication.yml",
      study_repo, ref
    )
    study_meta <- read_yaml_from_url(study_url)
    index <- study_yaml_replication_index(study_meta)
    if (!is.null(index) && length(index) > 0L) {
      return(index)
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

  registry_url <- registry_stub_yaml_url(folder)
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
    registry_stub_yaml_url(folder)
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

split_replication_entries <- function(reps) {
  if (is.null(reps) || !length(reps)) {
    return(list(prep = list(), replications = list()))
  }
  is_display <- vapply(reps, function(x) {
    type <- as.character(x$type %||% "")
    type %in% c("figure", "table")
  }, logical(1))
  is_prep <- vapply(reps, function(x) {
    type <- tolower(as.character(x$type %||% ""))
    type %in% c("step", "prep", "pipeline", "transform")
  }, logical(1))
  list(
    prep = reps[is_prep],
    replications = reps[is_display]
  )
}

get_replications_meta <- function(doi, folder = NULL, repo = NULL) {
  if (is.null(doi) || !nzchar(doi)) {
    return(list(replications = NULL, prep = list(), error = NULL, diagnostics = NULL))
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

  split <- split_replication_entries(replications %||% list())

  list(
    replications = split$replications,
    prep = split$prep,
    error = if (replication_display_count(split$replications) == 0L) load_error else NULL,
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
      return(replicate_fn("replication_error_message", error))
    }
    if (inherits(error, "condition")) {
      return(conditionMessage(error))
    }
    as.character(error)
  }, error = function(e) {
    raw <- if (inherits(error, "condition")) {
      conditionMessage(error)
    } else {
      paste(as.character(error), collapse = "\n")
    }
    if (
      requireNamespace("replicateEverything", quietly = TRUE) &&
      exists("strip_ansi_escapes", envir = asNamespace("replicateEverything"), inherits = FALSE)
    ) {
      raw <- replicate_fn("strip_ansi_escapes", raw)
    } else {
      raw <- gsub("\x1b", "", raw, fixed = TRUE)
    }
    raw
  })
}

replication_error_ui <- function(error, doi = NULL, folder = NULL, repo = NULL) {
  if (inherits(error, "dependency_error")) {
    msg <- format_replication_error(error)
    return(tags$div(
      class = "alert alert-warning replication-error",
      tags$strong("Dependencies missing"),
      tags$p(class = "text-muted small mb-2", "Live Run does not install packages. Use the maintainer commands below."),
      tags$pre(
        class = "replication-error-message",
        style = "white-space: pre-wrap;",
        msg
      )
    ))
  }
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

contribute_prose <- function(..., class = NULL) {
  cls <- paste(c("contribute-prose", class), collapse = " ")
  tags$div(class = cls, ...)
}

contribute_hint <- function(label, example, caption = NULL) {
  example <- gsub("\r\n", "\n", example, fixed = TRUE)
  example <- sub("^\n+", "", example)
  tags$span(
    class = "contribute-hint",
    tabindex = "0",
    role = "button",
    tags$span(class = "contribute-hint-label", label),
    tags$span(
      class = "contribute-example",
      `aria-hidden` = "true",
      if (!is.null(caption) && nzchar(caption)) {
        tags$div(class = "contribute-example-caption", caption)
      },
      tags$pre(
        class = "contribute-example-code",
        htmltools::HTML(htmltools::htmlEscape(example))
      )
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
    "repo: replicate-anything/rep-10.1017-S0003055403000534\n",
    "maintainer:\n",
    "  name: Jane Maintainer\n",
    "  email: maintainer@example.org\n",
    "collections:\n",
    "  - APSR\n",
    "languages:\n",
    "  - r\n",
    "  - stata"
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
    "repo: replicate-anything/rep-10.1017-S0003055403000534\n",
    "\n",
    "maintainer:              # required — contact on the Studies tab\n",
    "  name: Jane Maintainer\n",
    "  email: maintainer@example.org\n",
    "\n",
    "collections:             # optional tags for Studies tab filtering\n",
    "  - APSR\n",
    "\n",
    "languages:\n",
    "  - r\n",
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
    "Rscript scripts/build_artifacts.R studies/10.1017S0003055403000534\n",
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
    "repo: replicate-anything/rep-10.1371_journal.pone.0278337\n",
    "maintainer:\n",
    "  name: Jane Maintainer\n",
    "  email: maintainer@example.org\n",
    "collections:\n",
    "  - IPI\n",
    "languages:\n",
    "  - r"
  )

  example_build_registry_index <- paste0(
    "library(replicateEverything)\n",
    "options(replicateEverything.registry_root = \"../registry\")\n",
    "\n",
    "build_registry_index(\"../registry\")\n",
    "# writes index.csv with collections, maintainer_*, languages from stubs"
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

  example_local_dev <- paste0(
    "library(replicateEverything)\n",
    "configure_local_monorepo()  # or set registry_root manually\n",
    "configure_study_folder(\"10.1257/aer.91.5.1369\", \".\")\n",
    "\n",
    "check_folder_replication(\".\", full_replication = FALSE)\n",
    "run_replication(\"local\", \"tab_1\", format = TRUE)\n",
    "run_shiny_app()  # Explore tab: enter a path or leave blank for cwd"
  )

  example_folder_check <- paste0(
    "library(replicateEverything)\n",
    "check_folder_replication(\".\", full_replication = FALSE)\n",
    "run_replication(\"local\", \"tab_1\", format = TRUE)"
  )

  example_registry_connect <- paste0(
    "library(replicateEverything)\n",
    "options(replicateEverything.registry_root = \"../registry\")\n",
    "\n",
    "prepare_folder_paper(\".\", build_artifacts = FALSE)\n",
    "sync_folder_paper(\".\")\n",
    "add_folder_paper(\".\")"
  )

  example_package_check <- paste0(
    "build_report()\n",
    "testthat::test_dir(\"tests/testthat\")\n",
    "check_package_replication(\".\", full_replication = FALSE)"
  )

  example_package_registry <- paste0(
    "library(replicateEverything)\n",
    "options(replicateEverything.registry_root = \"../registry\")\n",
    "\n",
    "check_package_replication(\"../rep-package\", full_replication = FALSE)\n",
    "add_paper(\"../rep-package\")"
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
    contribute_prose(
      class = "contribute-intro",
      "We invite contributions of replications to ",
      tags$strong("replicateEverything"),
      ". Individual replications are saved in a dedicated folder or as a standalone R package, following a prespecified format. Once checked, they are included in the registry. Users can then use the ",
      tags$strong("replicateEverything"),
      " package and this Shiny app to inspect code and run replications live."
    ),
    contribute_prose(
      class = "text-muted mb-1",
      "Hover ",
      tags$span(class = "contribute-hint-demo", "underlined terms"),
      " for copy-paste examples."
    ),
    h4("How should replications be formatted?"),
    contribute_prose("There are two approaches: a ", tags$strong("folder-backed study repository"), " or a ", tags$strong("package-backed"), " R package."),

    tags$div(
      class = "contribute-section",
      h4("Folder-backed study repository"),
      contribute_step_title("1. Create a study repository", "folder"),
      contribute_prose(
        "Create a Git repository with three folders — ",
        code("code/"),
        ", ",
        code("data/"),
        ", and ",
        code("artifacts/"),
        " — plus a ",
        contribute_hint(code("replication.yml"), example_yaml),
        " that tells replicateEverything how code, data, and outputs relate."
      ),
      contribute_prose(
        tags$strong("Maintainer and collections. "),
        "Every study must name a ",
        code("maintainer:"),
        " (name + email) — shown as ",
        code("[maintainer]"),
        " on the Studies tab. List one or more ",
        code("collections:"),
        " tags (e.g. ",
        code("APSR"),
        ", ",
        code("PED"),
        ", ",
        code("World Bank"),
        ", ",
        code("IPI"),
        ") so readers can filter the bibliography. ",
        code("prepare_folder_paper()"),
        " copies these fields into the registry stub and ",
        code("index.csv"),
        " row."
      ),
      contribute_prose(
        tags$strong("R, Stata, or both. "),
        "Each table or figure is one entry in ",
        code("replication.yml"),
        ". Use ",
        code("engine: stata"),
        " and a ",
        code(".do"),
        " file for Stata; omit ",
        code("engine"),
        " (or use R scripts) for R. You may list paired entries (e.g. ",
        code("tab_1"),
        " and ",
        code("tab_1_stata"),
        ") so both engines appear in Shiny."
      ),
      contribute_prose(
        tags$strong("Artifacts must be baked. "),
        "Run ",
        contribute_hint(code("build_study_artifacts()"), example_folder_build),
        " so ",
        code("artifacts/"),
        " contains precomputed HTML tables, figures, and ",
        code("manifest.json"),
        " for fast Display in Shiny."
      ),

      contribute_step_title("2. Check locally", "check"),
      contribute_prose(
        "Before contacting the registry maintainers, confirm your repo works with replicateEverything on your machine:"
      ),
      tags$ul(
        tags$li(
          contribute_hint(code("check_folder_replication()"), example_folder_check, "Folder validation"),
          " — structure, artifacts, and optional live runs."
        ),
        tags$li(
          contribute_hint(code("run_replication()"), example_folder_check, "Run one replication"),
          " — use ",
          code('doi = "local"'),
          " when your working directory is inside the study repo."
        ),
        tags$li(
          "Launch ",
          contribute_hint(code("run_shiny_app()"), example_local_dev, "Local Shiny + dev registry"),
          " with ",
          contribute_hint(code("configure_local_monorepo()"), example_local_dev, "Local monorepo"),
          " or a development registry checkout. On the Explore tab, enter the path to your study repo (e.g. ",
          code("c:/Users/you/my_repo/"),
          " or ",
          code("~/my_repo/"),
          "), or leave the field blank when Shiny's working directory is inside the repo."
        )
      ),

      contribute_step_title("3. Connect with the registry", "registry"),
      contribute_prose("When local checks pass, add your study to the central registry:"),
      tags$ul(
        tags$li(
          contribute_hint(code("prepare_folder_paper()"), example_folder_build, "Prepare registry stubs"),
          " — writes ",
          code("registry/replication.yml"),
          " and ",
          code("registry/index.csv"),
          " snippets inside your study repo."
        ),
        tags$li(
          contribute_hint(code("sync_folder_paper()"), example_sync_folder, "Sync stub files"),
          " — copies those stubs into your local ",
          code("registry/"),
          " checkout (or copy manually)."
        ),
        tags$li(
          "Add a registry paper stub ",
          code("studies/<folder>.yml"),
          " with ",
          contribute_hint(code("materials: folder"), example_folder_stub, "Registry stub fields"),
          " pointing at your study repository (include ",
          code("maintainer:"),
          " and ",
          code("collections:"),
          ")."
        ),
        tags$li(
          "Rebuild ",
          code("index.csv"),
          " with ",
          contribute_hint(code("build_registry_index()"), example_build_registry_index, "Compile index from stubs"),
          " so ",
          code("collections"),
          ", ",
          code("maintainer_name"),
          ", and ",
          code("languages"),
          " appear on the Studies tab."
        ),
        tags$li(
          contribute_hint(code("add_folder_paper()"), example_registry_connect, "Register folder study"),
          " — validates and opens a pull request (or follow your team's process)."
        )
      ),
      p(
        class = "text-muted small",
        "See vignette ",
        code("folder-replication-checklist"),
        " for the full checklist."
      )
    ),

    tags$div(
      class = "contribute-section",
      h4("Package-backed study"),
      contribute_step_title("1. Create an R package", "package"),
      contribute_prose(
        "Scaffold manually or copy an existing study package. The package must export ",
        contribute_hint(code("run_replication()"), example_package_api, "Required API"),
        ", ",
        code("list_replications()"),
        ", ",
        code("load_artifact()"),
        ", and ",
        code("get_code()"),
        ", and include ",
        contribute_hint(code("replication.yml"), example_package_stub),
        " describing each replication (include ",
        code("maintainer:"),
        " and ",
        code("collections:"),
        " at the top level)."
      ),
      contribute_prose(
        tags$strong("R only. "),
        "Package-backed studies use R. Stata replications belong in the folder-backed model."
      ),
      contribute_prose(
        tags$strong("Bake display artifacts. "),
        "Run ",
        code("build_report()"),
        " so ",
        code("inst/report/artifacts/"),
        " holds PNG figures and HTML tables for Shiny Display."
      ),

      contribute_step_title("2. Check locally", "check"),
      tags$ul(
        tags$li(
          code("tests/testthat/"),
          " with replication smoke tests."
        ),
        tags$li(
          contribute_hint(code("check_package_replication()"), example_package_check, "Package validation"),
          " — structure, artifacts, and optional live ",
          code("run_replication()"),
          " calls."
        ),
        tags$li(
          contribute_hint(code("run_shiny_app()"), example_local_dev, "Preview in Shiny"),
          " after ",
          contribute_hint(code("configure_local_monorepo()"), example_local_dev, "Dev registry"),
          " and installing your package locally."
        )
      ),

      contribute_step_title("3. Connect with the registry", "registry"),
      tags$ul(
        tags$li(
          "Add ",
          code("studies/<folder>.yml"),
          " with ",
          contribute_hint(code("materials: package"), example_package_stub, "Package registry stub"),
          ", the package name, ",
          code("maintainer:"),
          ", and ",
          code("collections:"),
          "."
        ),
        tags$li(
          "Rebuild ",
          code("index.csv"),
          " with ",
          contribute_hint(code("build_registry_index()"), example_build_registry_index, "Compile index from stubs"),
          " (or merge the row from ",
          code("prepare_folder_paper()"),
          " for folder studies)."
        ),
        tags$li(
          contribute_hint(code("add_paper()"), example_package_registry, "Register package study"),
          " — validates the package against the registry and records it."
        )
      ),
      p(
        class = "text-muted small",
        "See vignette ",
        code("package-replication-checklist"),
        "."
      )
    )
  )
}

replication_run_snippet <- function(doi, what, language = NULL, include_language = NULL) {
  lang <- tolower(trimws(as.character(language %||% "")))
  args <- c(
    paste0("  doi = ", encodeString(doi, quote = '"')),
    paste0("  what = ", encodeString(what, quote = '"'))
  )
  if (is.null(include_language)) {
    include_language <- nzchar(lang) && !identical(lang, "r")
  }
  if (isTRUE(include_language) && nzchar(lang)) {
    lang_val <- if (identical(lang, "stata")) "stata" else language
    args <- c(args, paste0("  language = ", encodeString(lang_val, quote = '"')))
  }
  paste0(
    "replicateEverything::run_replication(\n",
    paste(args, collapse = ",\n"),
    "\n)"
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
      $(document).on('shiny:connected', function() {
        try {
          var params = new URLSearchParams(window.location.search);
          var doi = params.get('doi');
          if (!doi) return;
          Shiny.setInputValue('url_deep_link', {
            doi: doi,
            what: params.get('what') || '',
            language: params.get('language') || ''
          }, {priority: 'event'});
        } catch (e) {}
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
    .contribute-prose {
      margin-bottom: 1rem;
    }
    .contribute-hint {
      position: relative;
      display: inline;
      cursor: help;
      vertical-align: baseline;
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
      visibility: hidden;
      opacity: 0;
      pointer-events: none;
      clip: rect(0, 0, 0, 0);
      clip-path: inset(50%);
    }
    .contribute-hint:hover .contribute-example,
    .contribute-hint:focus-within .contribute-example {
      visibility: visible;
      opacity: 1;
      pointer-events: auto;
      clip: auto;
      clip-path: none;
    }
    .contribute-example-caption {
      font-weight: 600;
      margin-bottom: 0.35rem;
      color: #57606a;
      font-size: 0.7rem;
      text-transform: uppercase;
      letter-spacing: 0.02em;
    }
    .contribute-example-code {
      margin: 0;
      padding: 0.5rem;
      background: #f6f8fa;
      border-radius: 4px;
      overflow-x: auto;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      white-space: pre;
      font-size: 0.72rem;
      color: #24292f;
      text-align: left;
      tab-size: 2;
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
      width: 100%;
    }
    .doi-input-field {
      flex: 1 1 auto;
      min-width: 0;
    }
    .doi-input-field .form-group {
      margin-bottom: 0;
      width: 100%;
    }
    .doi-go-wrap {
      flex: 0 0 auto;
      margin-left: auto;
    }
    .doi-go-wrap .btn { white-space: nowrap; min-width: 2.75rem; }
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
      align-items: center;
      gap: 0.2rem;
      flex: 0 0 auto;
    }
    .engine-pick {
      width: 1.55rem;
      height: 1.55rem;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 0;
      border: 0;
      background: transparent;
      line-height: 0;
      border-radius: 999px;
    }
    .engine-pick.is-active { opacity: 1; }
    .engine-pick.is-inactive {
      opacity: 0.38;
      filter: grayscale(0.35);
    }
    .engine-pick.is-inactive:hover:not(:disabled) { opacity: 0.72; }
    .engine-pick.is-disabled {
      opacity: 0.2;
      filter: grayscale(1);
      cursor: not-allowed;
    }
    .engine-pick.is-active svg {
      box-shadow: 0 0 0 2px rgba(13, 110, 253, 0.35);
      border-radius: 999px;
    }
    .engine-icons-cell {
      display: inline-flex;
      align-items: center;
      gap: 0.2rem;
      min-width: 2.5rem;
      justify-content: center;
    }
    .engine-badge {
      display: inline-flex;
      line-height: 0;
      opacity: 0.95;
    }
    .study-list-header,
    .study-citation {
      display: grid;
      grid-template-columns: 1fr 4.5rem 3rem 4.5rem 2rem 2.75rem;
      gap: 12px;
      align-items: start;
    }
    .study-list-header {
      font-size: 0.82rem;
      font-weight: 600;
      color: #6c757d;
      border-bottom: 1px solid #dee2e6;
      padding-bottom: 0.35rem;
      margin-bottom: 0.25rem;
    }
    .study-engine-col,
    .study-run-col,
    .study-link-col {
      text-align: center;
      white-space: nowrap;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .study-share-link {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: #6c757d;
      line-height: 0;
      padding: 0.15rem;
      border-radius: 4px;
    }
    .study-share-link:hover {
      color: #0d6efd;
      background: #eef4ff;
    }
    .replication-share-link {
      display: inline-flex;
      align-items: center;
      margin-right: 0.15rem;
      color: #6c757d;
      line-height: 0;
    }
    .replication-share-link:hover { color: #0d6efd; }
    .study-dag-panel {
      border-top: 1px solid #dee2e6;
      padding-top: 0.65rem;
    }
    .study-dag-facets {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(min(100%, 22rem), 1fr));
      gap: 0.65rem;
      align-items: start;
    }
    .study-dag-facet {
      border: 1px solid #dee2e6;
      border-radius: 8px;
      padding: 0.55rem 0.65rem;
      background: #fafbfc;
      min-width: 0;
    }
    .study-dag-facet-title {
      font-size: 0.78rem;
      font-weight: 600;
      color: #495057;
      margin-bottom: 0.4rem;
      padding-bottom: 0.25rem;
      border-bottom: 1px solid #e9ecef;
    }
    .study-dag-heading {
      font-weight: 600;
      letter-spacing: 0.02em;
      text-transform: uppercase;
      font-size: 0.72rem;
    }
    .study-dag-chain {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 0.15rem 0.25rem;
      margin-bottom: 0.35rem;
      font-size: 0.82rem;
    }
    .study-dag-node {
      background: #f1f3f5;
      border-radius: 4px;
      padding: 0.1rem 0.35rem;
      cursor: help;
      max-width: 11rem;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .study-dag-node.is-data {
      background: #e7f5ff;
      border: 1px dashed #339af0;
      border-radius: 2px;
      color: #1864ab;
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 0.78rem;
    }
    .study-dag-node.is-step {
      background: #f1f3f5;
    }
    .study-dag-legend {
      border-top: 1px solid #dee2e6;
    }
    .study-dag-legend-swatch {
      cursor: default;
      max-width: none;
      display: inline-flex;
      vertical-align: middle;
    }
    .study-dag-arrow {
      color: #6c757d;
      user-select: none;
    }
    .study-go-btn {
      width: 2.25rem;
      height: 2.25rem;
      min-width: 2.25rem;
      padding: 0;
      border-radius: 50%;
      font-size: 0.68rem;
      font-weight: 600;
      line-height: 1;
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }
    .study-details-expand {
      margin-top: 0.25rem;
    }
    .study-details-expand > summary {
      cursor: pointer;
      list-style: none;
      color: inherit;
    }
    .study-details-expand > summary::-webkit-details-marker {
      display: none;
    }
    .study-details-chevron {
      display: inline-block;
      font-size: 0.75rem;
      color: #6c757d;
      transition: transform 0.15s ease;
    }
    .study-details-expand[open] .study-details-chevron {
      transform: rotate(180deg);
    }
    .study-details-body {
      border-left: 2px solid #e9ecef;
      padding-left: 0.75rem;
      margin-left: 0.35rem;
    }
    .study-collections-col {
      text-align: center;
      white-space: nowrap;
      line-height: 1.6;
    }
    .collection-tag {
      display: inline-block;
      font-size: 0.68rem;
      font-weight: 600;
      letter-spacing: 0.02em;
      padding: 0.1rem 0.35rem;
      border-radius: 0.2rem;
      margin: 0 0.1rem 0.1rem 0;
      color: #fff;
      vertical-align: middle;
    }
    .collection-tag-apsr { background: #0d6efd; }
    .collection-tag-ped { background: #198754; }
    .collection-tag-wb { background: #0dcaf0; color: #084298; }
    .collection-tag-ipi { background: #6f42c1; }
    .collection-tag-other { background: #6c757d; }
    .collection-tag-more { background: #e9ecef; color: #495057; }
    .collections-legend .collection-tag { cursor: default; }
    .maintainer-link {
      font-size: 0.9rem;
      color: #6c757d;
      text-decoration: none;
      border-bottom: 1px dotted #adb5bd;
    }
    .maintainer-link:hover {
      color: #495057;
      text-decoration: none;
    }
    .study-repo-col {
      text-align: center;
      white-space: nowrap;
    }
    .study-repo-link {
      display: inline-flex;
      line-height: 0;
      opacity: 0.9;
    }
    .study-repo-link:hover {
      opacity: 1;
    }
    .study-citation {
      padding: 0.5rem 0;
      border-bottom: 1px solid #eee;
      line-height: 1.35;
      font-size: 0.95rem;
    }
    .contribute-step-title {
      font-weight: 600;
      margin-top: 1rem;
      margin-bottom: 0.35rem;
    }
    .contribute-intro { margin-bottom: 1rem; }
    .contribute-section { margin-bottom: 1.25rem; }
    .doi-input-field input::placeholder { color: #9aa0a6; }
    .replication-actions .btn {
      min-width: 3.25rem;
      padding: 0.12rem 0.35rem;
      font-size: 0.75rem;
      line-height: 1.2;
    }
    .registry-health-wrap {
      display: flex;
      align-items: center;
      gap: 0.65rem;
      padding: 0.35rem 1rem 0;
      max-width: 100%;
    }
    .registry-health-bar {
      flex: 1 1 auto;
      display: flex;
      height: 0.55rem;
      border-radius: 999px;
      overflow: hidden;
      background: #e9ecef;
      min-width: 120px;
      max-width: 420px;
    }
    .registry-health-ok {
      background: #2ca25f;
      height: 100%;
    }
    .registry-health-fail {
      background: #de2d26;
      height: 100%;
    }
    .registry-health-label {
      font-size: 0.8rem;
      color: #495057;
      white-space: nowrap;
    }
    .study-audit-compact {
      padding: 0.35rem 0.5rem;
      border-radius: 0.25rem;
      border: 1px solid rgba(0, 0, 0, 0.08);
    }
    .compat-toolbar .btn-link {
      font-size: 0.8rem;
      text-decoration: none;
    }
    .compat-toolbar .btn-link:hover {
      text-decoration: underline;
    }
    .study-audit {
      margin-top: 0.75rem;
      padding: 0.65rem 0.85rem;
    }
    .study-audit-title {
      margin-bottom: 0.35rem;
    }
    .study-audit-row {
      font-size: 0.85rem;
      line-height: 1.35;
    }
    .study-audit-status {
      font-weight: 600;
      margin-right: 0.35rem;
    }
    .study-audit-ok { color: #198754; }
    .study-audit-warn { color: #856404; }
    .study-audit-fail { color: #b02a37; }
    .study-audit-detail { font-weight: 400; }
    .study-audit-failures {
      margin: 0.25rem 0 0.5rem 1rem;
      padding-left: 0.25rem;
    }
    .study-audit-summary {
      font-size: 0.82rem;
    }
    .app-footer {
      background: #f8f9fa;
      margin-top: 0.5rem;
    }
    .app-footer code {
      font-size: 0.75rem;
      color: inherit;
    }
  "))),
  shiny_app_stale_banner_ui(),
  registry_health_bar_ui(registry_audit_summary),
  navbarPage(
  id = "main_nav",
  title = app_brand_title(),
  theme = bs_theme(bootswatch = "flatly"),
  tabPanel(
    "Replicate",
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
            textInput("study_doi", label = NULL, placeholder = "Enter DOI or path to repo")
          ),
          tags$div(
            class = "doi-go-wrap",
            actionButton("doi_go", "Go", class = "btn-primary btn-sm")
          )
        ),
        tags$hr(style = "margin: 0.5rem 0;"),
        tags$h4(class = "mb-1", "2. Tables & figures"),
        uiOutput("check_system_compat_ui"),
        uiOutput("study_compat_result"),
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
          tabPanel("Code", uiOutput("replication_code_ui")),
          tabPanel("Pipeline", uiOutput("selected_pipeline_ui"))
        )
      )
    )
  ),
  tabPanel(
    "Studies",
    fluidPage(
      class = "px-3 py-2",
      fluidRow(
        column(
          width = 4,
          selectInput(
            "studies_collection_filter",
            "Collection",
            choices = registry_collection_choices(registry_index),
            selected = ALL_STUDIES_COLLECTION
          )
        )
      ),
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
      p(
        class = "mb-3",
        "This is a project of IPI WZB led by Macartan Humphreys, Cord Masche, and Vernon Washington."
      ),
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
      h4("Share links"),
      p(
        "Chain icons in the ",
        tags$strong("Studies"),
        " table and beside each replication open a URL on the public server ",
        tags$code(paste0(shiny_share_base_url(), "?doi=...")),
        " (optional ",
        tags$code("what="),
        " and ",
        tags$code("language="),
        " select a replication and engine). Recipients land on the same study when they open the link."
      ),
      p(
        class = "text-muted small",
        "Share links always use ",
        tags$code("LIVE_DEMO_URL"),
        " in ",
        tags$code("app.R"),
        ", or ",
        tags$code("REPLICATE_SHINY_BASE_URL"),
        " in ",
        tags$code("local.R"),
        " if the host moves — not your local session URL."
      ),
      tags$hr(),
      p(
        class = "text-muted",
        "Run interactively with ",
        tags$code("replicateEverything::run_shiny_app()"),
        " or deploy with ",
        tags$code("save_local_shiny()"),
        ". See the ",
        tags$a(href = SHINY_VIGNETTE_URL, "Shiny demo app", target = "_blank"),
        " vignette for details."
      ),
      tags$p(
        class = "text-muted small mb-0",
        tags$strong("This session: "),
        replicate_everything_build_label()
      )
    )
  )
  ),
  app_build_footer_ui()
)

server <- function(input, output, session) {
  options(shiny.sanitize.errors = FALSE)

  registry_index <<- load_registry_index()
  updateSelectInput(
    session,
    "study_select",
    choices = c("Choose a study…" = "", nice_doi_choices(registry_index))
  )
  updateSelectInput(
    session,
    "studies_collection_filter",
    choices = registry_collection_choices(registry_index),
    selected = ALL_STUDIES_COLLECTION
  )

  state <- reactiveValues(
    doi = NULL,
    replications = NULL,
    replications_df = NULL,
    selected_replication = NULL,
    selected_type = NULL,
    selected_source = "artifact",
    selected_result = NULL,
    prep_download_path = NULL,
    progress = NULL,
    replications_load_error = NULL,
    replications_index_diagnostics = NULL,
    registry_folder = NULL,
    registry_repo = NULL,
    local_study_meta = NULL,
    group_engines = list(),
    study_audit = NULL,
    study_audit_running = FALSE,
    url_deep_link_parsed = FALSE,
    pending_deep_link_doi = NULL,
    pending_deep_link_what = NULL,
    pending_deep_link_language = NULL,
    suppress_url_sync = FALSE,
    welcome_shown = FALSE
  )

  options(replicateEverything.progress = function(msg) {
    if (!is.null(msg) && nzchar(as.character(msg))) {
      state$progress <- as.character(msg)
    }
  })

  observe({
    query_string <- session$clientData$url_search
    if (is.null(query_string)) {
      return(invisible(NULL))
    }

    if (isFALSE(state$url_deep_link_parsed)) {
      state$url_deep_link_parsed <- TRUE
      qs <- sub("^\\?", "", query_string)
      if (nzchar(qs)) {
        query <- parseQueryString(qs)
        doi <- trimws(as.character(query$doi %||% ""))
        if (nzchar(doi)) {
          state$welcome_shown <- TRUE
          state$suppress_url_sync <- TRUE
          state$pending_deep_link_doi <- doi
          state$pending_deep_link_what <- trimws(as.character(query$what %||% ""))
          state$pending_deep_link_language <- trimws(as.character(query$language %||% ""))
          return(invisible(NULL))
        }
      }
    }

    if (isFALSE(state$welcome_shown)) {
      state$welcome_shown <- TRUE
      showModal(modalDialog(
        title = "Welcome to Replicate Everything",
        app_welcome_intro(),
        size = "m",
        easyClose = TRUE,
        footer = modalButton("Get started")
      ))
    }
  })

  replication_has_engine <- function(reps, engine) {
    col <- switch(
      engine,
      stata = "stata_id",
      python = "python_id",
      "r_id"
    )
    any(!is.na(reps[[col]]) & nzchar(reps[[col]]))
  }

  row_has_engine <- function(row, engine) {
    col <- switch(
      engine,
      stata = "stata_id",
      python = "python_id",
      "r_id"
    )
    val <- row[[col]][[1]]
    !is.na(val) && nzchar(val)
  }

  row_engine_count <- function(row) {
    sum(c(
      if (row_has_engine(row, "r")) 1L else 0L,
      if (row_has_engine(row, "stata")) 1L else 0L,
      if (row_has_engine(row, "python")) 1L else 0L
    ))
  }

  default_row_engine <- function(row) {
    if (row_has_engine(row, "r")) return("r")
    if (row_has_engine(row, "stata")) return("stata")
    if (row_has_engine(row, "python")) return("python")
    "r"
  }

  group_engine <- function(group, row = NULL) {
    eng <- state$group_engines[[group]]
    if (identical(eng, "stata") || identical(eng, "r") || identical(eng, "python")) {
      if (!is.null(row)) {
        if (identical(eng, "stata") && !row_has_engine(row, "stata")) return(default_row_engine(row))
        if (identical(eng, "r") && !row_has_engine(row, "r")) return(default_row_engine(row))
        if (identical(eng, "python") && !row_has_engine(row, "python")) return(default_row_engine(row))
      }
      return(eng)
    }
    if (!is.null(row)) {
      return(default_row_engine(row))
    }
    "r"
  }

  selected_replication_language <- function() {
    if (is_step_replication(state$selected_type)) {
      return(prep_step_language(state$selected_replication, state$prep_steps))
    }
    row <- replication_row_for_id(state$replications_df, state$selected_replication)
    if (is.null(row)) {
      return("r")
    }
    group_engine(row$group[[1]], row)
  }

  selected_replication_id_and_language <- function() {
    if (is_step_replication(state$selected_type)) {
      lang <- selected_replication_language()
      return(list(id = state$selected_replication, language = lang))
    }
    row <- replication_row_for_id(state$replications_df, state$selected_replication)
    if (is.null(row)) {
      return(list(id = state$selected_replication, language = "r"))
    }
    lang <- selected_replication_language()
    resolved_id <- resolve_group_replication_id(row, lang)
    resolved_lang <- if (!is.na(row$r_id) && identical(resolved_id, row$r_id)) {
      "r"
    } else if (!is.na(row$stata_id) && identical(resolved_id, row$stata_id)) {
      "stata"
    } else if (!is.na(row$python_id) && identical(resolved_id, row$python_id)) {
      "python"
    } else {
      lang
    }
    list(id = resolved_id, language = resolved_lang)
  }

  load_study <- function(doi_input, from_registry = FALSE) {
    doi_input <- trimws(as.character(doi_input %||% ""))
    if (!isTRUE(from_registry) && !nzchar(doi_input)) {
      doi_input <- "local"
    }

    resolved <- tryCatch(
      resolve_study_doi_input(doi_input, from_registry = from_registry),
      error = function(e) {
        state$doi <- NULL
        state$local_study_meta <- NULL
        state$registry_folder <- NULL
        state$registry_repo <- NULL
        state$replications <- NULL
        state$replications_df <- NULL
        state$replications_load_error <- e
        state$replications_index_diagnostics <- NULL
        state$selected_replication <- NULL
        state$selected_type <- NULL
        state$selected_result <- NULL
        state$group_engines <- list()
        state$study_audit <- NULL
        state$study_audit_running <- FALSE
        return(NULL)
      }
    )
    if (is.null(resolved)) {
      return(invisible(NULL))
    }

    doi <- resolved$doi
    ctx <- registry_row_for(doi)
    state$doi <- doi
    state$registry_folder <- ctx$folder
    state$registry_repo <- ctx$repo
    state$local_study_meta <- NULL

    if (!is.null(resolved$local_root)) {
      local_yaml <- tryCatch(
        yaml::read_yaml(file.path(resolved$local_root, "replication.yml")),
        error = function(e) NULL
      )
      if (!is.null(local_yaml$paper)) {
        state$local_study_meta <- local_yaml$paper
      }
      if (is.null(state$registry_folder) || !nzchar(state$registry_folder)) {
        state$registry_folder <- basename(resolved$local_root)
      }
    }

    withProgress(message = "Preparing study...", value = 0.1, {
      meta <- tryCatch(
        get_replications_meta(doi, folder = state$registry_folder, repo = state$registry_repo),
        error = function(e) list(replications = NULL, error = e)
      )
    })
    state$replications <- meta$replications
    state$prep_steps <- meta$prep %||% list()
    state$prep_df <- prep_to_df(state$prep_steps)
    state$replications_load_error <- meta$error
    if (
      is.null(state$replications_load_error) &&
      (is.null(meta$replications) || replication_display_count(meta$replications) == 0L)
    ) {
      state$replications_load_error <- simpleError(
        paste0(
          "No replications found for DOI ", doi, ".\n\n",
          "Check the DOI against the Studies tab. ",
          "For a local folder-backed repo, enter the path to the folder ",
          "that contains replication.yml (e.g. c:/Users/you/my_repo/ or ~/my_repo/)."
        ),
        call = NULL
      )
    }
    state$replications_index_diagnostics <- meta$diagnostics
    state$replications_df <- replications_to_df(state$replications)
    state$group_engines <- list()
    state$selected_replication <- NULL
    state$selected_type <- NULL
    state$selected_result <- NULL
    state$selected_source <- "artifact"
    state$study_audit <- NULL
    state$study_audit_running <- FALSE

    if (!is.null(state$replications_df) && nrow(state$replications_df) > 0) {
      first <- state$replications_df[1, , drop = FALSE]
      if (!isTRUE(state$suppress_url_sync) &&
          !is.null(state$pending_deep_link_what) &&
          nzchar(state$pending_deep_link_what)) {
        select_replication_by_group(
          state$pending_deep_link_what,
          language = state$pending_deep_link_language
        )
        state$pending_deep_link_what <- NULL
        state$pending_deep_link_language <- NULL
      } else {
        state$selected_replication <- first$group[[1]]
        state$selected_type <- first$type[[1]]
        load_selected_artifact(fallback_live = FALSE)
      }
    }
  }

  sync_url_to_selection <- function() {
    if (isTRUE(state$suppress_url_sync)) {
      return(invisible(NULL))
    }
    if (is.null(state$doi) || !nzchar(state$doi)) {
      updateQueryString(query = "?", mode = "replace", session = session)
      return(invisible(NULL))
    }
    if (is.null(state$selected_replication) || !nzchar(state$selected_replication)) {
      params <- shiny_deep_link_query_list(state$doi)
    } else {
      target <- selected_replication_id_and_language()
      params <- shiny_deep_link_query_list(
        state$doi,
        what = state$selected_replication,
        language = target$language
      )
    }
    qs <- shiny_query_string(params)
    updateQueryString(
      query = if (nzchar(qs)) paste0("?", qs) else "?",
      mode = "replace",
      session = session
    )
    invisible(NULL)
  }

  select_replication_by_group <- function(group_or_id, language = NULL) {
    row <- tryCatch(
      resolve_replication_row(group_or_id),
      error = function(e) NULL
    )
    if (is.null(row)) {
      return(FALSE)
    }
    lang <- tolower(trimws(as.character(language %||% "")))
    if (!nzchar(lang)) {
      lang <- group_engine(row$group[[1]], row)
    } else if (!row_has_engine(row, lang)) {
      lang <- group_engine(row$group[[1]], row)
    }
    state$group_engines[[row$group[[1]]]] <- lang
    state$selected_replication <- row$group[[1]]
    state$selected_type <- row$type[[1]]
    state$selected_source <- "artifact"
    state$selected_result <- NULL
    load_selected_artifact(fallback_live = FALSE)
    TRUE
  }

  observeEvent(input$url_deep_link, {
    link <- input$url_deep_link
    req(is.list(link))
    doi <- trimws(as.character(link$doi %||% ""))
    req(nzchar(doi))
    if (isFALSE(state$url_deep_link_parsed)) {
      state$url_deep_link_parsed <- TRUE
    }
    state$welcome_shown <- TRUE
    state$suppress_url_sync <- TRUE
    state$pending_deep_link_doi <- doi
    state$pending_deep_link_what <- trimws(as.character(link$what %||% ""))
    state$pending_deep_link_language <- trimws(as.character(link$language %||% ""))
  }, ignoreInit = TRUE)

  observeEvent(state$pending_deep_link_doi, {
    doi <- state$pending_deep_link_doi
    req(nzchar(doi))
    norm_doi <- tryCatch(
      replicate_fn("normalize_doi", doi),
      error = function(e) doi
    )
    if (!is.null(state$doi) && identical(state$doi, norm_doi)) {
      state$pending_deep_link_doi <- NULL
      state$suppress_url_sync <- FALSE
      return(invisible(NULL))
    }
    updateNavbarPage(session, "main_nav", selected = "Replicate")
    updateSelectInput(session, "study_select", selected = norm_doi)
    load_study(doi, from_registry = TRUE)
    state$pending_deep_link_doi <- NULL
    state$suppress_url_sync <- FALSE
    sync_url_to_selection()
  }, ignoreInit = TRUE)

  observeEvent(input$study_select, {
    req(nzchar(input$study_select))
    load_study(input$study_select, from_registry = TRUE)
  })

  observeEvent(input$doi_go, {
    load_study(input$study_doi, from_registry = FALSE)
  })

  observeEvent(input$go_to_study, {
    req(input$go_to_study)
    updateSelectInput(session, "study_select", selected = input$go_to_study)
    load_study(input$go_to_study, from_registry = TRUE)
    updateNavbarPage(session, "main_nav", selected = "Replicate")
    sync_url_to_selection()
  })

  observeEvent(list(state$doi, state$selected_replication, state$group_engines), {
    sync_url_to_selection()
  }, ignoreInit = TRUE)

  observeEvent(input$check_system_compat, {
    req(state$doi)
    state$study_audit_running <- TRUE
    state$study_audit <- NULL
    on.exit(state$study_audit_running <- FALSE, add = TRUE)
    withProgress(message = "Checking system compatibility...", value = 0.5, {
      state$study_audit <- tryCatch(
        check_study_compat(
          state$doi,
          folder = state$registry_folder,
          repo = state$registry_repo,
          materialize_study = TRUE,
          include_registry_audit = FALSE
        ),
        error = function(e) list(error = conditionMessage(e))
      )
    })
    audit <- state$study_audit
    if (!is.null(audit) && is.null(audit$error) && isTRUE(audit$install_needed)) {
      dependency_hint_modal(session, state$doi, audit = audit)
    }
  })

  output$check_system_compat_ui <- renderUI({
    req(state$doi)
    tags$div(
      class = "compat-toolbar d-flex justify-content-end mb-1",
      actionButton(
        "check_system_compat",
        "Check system compatibility",
        class = "btn btn-link btn-sm py-0 px-1 text-muted"
      )
    )
  })

  output$study_compat_result <- renderUI({
    if (isTRUE(state$study_audit_running)) {
      return(tags$p(class = "text-muted small mb-0", "Checking…"))
    }
    if (is.null(state$study_audit)) {
      return(NULL)
    }
    study_audit_ui(state$study_audit, compact = TRUE)
  })

  output$studies_bibliography <- renderUI({
    req(registry_index)
    idx <- registry_index[studies_for_bibliography(registry_index), , drop = FALSE]
    idx <- filter_index_by_collection(idx, input$studies_collection_filter)

    rows <- lapply(seq_len(nrow(idx)), function(i) {
      row <- idx[i, , drop = FALSE]
      cite <- format_study_citation(row)
      engines <- study_engine_availability_for_row(row)
      collections <- parse_index_collections(row)
      tags$div(
        class = "study-citation",
        tags$div(
          tags$div(cite$line1),
          tags$div(class = "text-muted", style = "font-size: 0.9rem;", cite$line2)
        ),
        tags$div(
          class = "study-collections-col",
          collections_column_ui(collections)
        ),
        tags$div(
          class = "study-repo-col",
          repo_link_display(study_repo_url_for_row(row))
        ),
        tags$div(
          class = "study-engine-col",
          engine_icons_display(engines$r, engines$stata, engines$python)
        ),
        tags$div(
          class = "study-link-col",
          share_link_ui(
            shiny_deep_link_query_list(row$doi[[1]]),
            title = "Link to this study on the public server"
          )
        ),
        tags$div(
          class = "study-run-col",
          actionButton(
            paste0("study_", i),
            "Go",
            class = "btn-primary btn-sm study-go-btn",
            onclick = sprintf(
              "Shiny.setInputValue('go_to_study', '%s', {priority: 'event'})",
              row$doi[[1]]
            )
          )
        )
      )
    })

    tagList(
      tags$div(
        class = "study-list-header",
        tags$div("Study"),
        tags$div(class = "study-collections-col", "Collection"),
        tags$div(class = "study-repo-col", "Repo"),
        tags$div(class = "study-engine-col", "Languages"),
        tags$div(class = "study-link-col", "Link"),
        tags$div(class = "study-run-col", "Go")
      ),
      rows,
      collections_legend_ui()
    )
  })

  output$study_details <- renderUI({
    req(state$doi)
    row <- registry_index[registry_index$doi == state$doi, , drop = FALSE]
    paper <- if (nrow(row) > 0) {
      list(
        title = row$title[[1]],
        authors = row$authors[[1]],
        year = row$year[[1]],
        journal = row$journal[[1]],
        doi = row$doi[[1]],
        article_url = if ("article_url" %in% names(row)) {
          row$article_url[[1]] %||% NULL
        } else {
          NULL
        }
      )
    } else if (!is.null(state$local_study_meta)) {
      state$local_study_meta
    } else {
      return(helpText("Study metadata not found in registry index."))
    }
    journal_raw <- strip_html_entities(paper$journal %||% "")
    journal_display <- if (nzchar(journal_raw)) {
      tags$em(journal_raw)
    } else {
      tags$em("Working paper")
    }
    doi_value <- if (nrow(row) > 0) {
      row$doi[[1]]
    } else {
      paper$doi %||% state$doi
    }
    tagList(
      card(
        card_header(if (!is.null(state$local_study_meta) && nrow(row) == 0) {
          "Study details (local)"
        } else {
          "Study details"
        }),
        h4(paper$title %||% state$doi),
        tags$details(
          class = "study-details-expand",
          tags$summary(
            class = "study-details-summary",
            tags$span(class = "study-details-chevron", HTML("&#9660;")),
            tags$span(class = "ms-1", strong("DOI: "), doi_link_ui(doi_value, paper = paper))
          ),
          tags$div(
            class = "study-details-body pt-2",
            p(
              class = "mb-2",
              strong("Authors: "), format_authors_summary(paper$authors %||% ""), br(),
              if (!is.null(paper$year) && nzchar(as.character(paper$year))) {
                tagList(strong("Year: "), paper$year, br())
              },
              strong("Journal: "), journal_display
            ),
            if (!is.null(state$local_study_meta) && nrow(row) == 0) {
              p(
                class = "text-muted small mb-2",
                "Loaded from ",
                code("replication.yml"),
                " via a local path or the working directory."
              )
            },
            study_materials_summary_ui(
              state$doi,
              folder = state$registry_folder,
              repo = state$registry_repo,
              dual_engine = !is.null(state$replications_df) &&
                replication_has_engine(state$replications_df, "r") &&
                replication_has_engine(state$replications_df, "stata"),
              maintainer_row = if (nrow(row) > 0) row else NULL
            ),
            study_dag_link_ui(
              state$doi,
              folder = state$registry_folder,
              repo = state$registry_repo
            )
          )
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
      if (!is.null(active_id) && (identical(group, active_id) || identical(resolved_id, active_id))) {
        "bg-light border border-primary"
      } else {
        ""
      }
    )
    engine_pick_btn <- function(eng) {
      active <- identical(engine, eng)
      btn_class <- paste(
        "engine-pick",
        if (active) "is-active" else "is-inactive"
      )
      icon <- if (eng == "r") engine_icon_r() else engine_icon_stata()
      tags$button(
        type = "button",
        class = btn_class,
        title = if (eng == "r") "R" else "Stata",
        `aria-label` = if (eng == "r") "Use R replication" else "Use Stata replication",
        `aria-pressed` = if (active) "true" else "false",
        onclick = sprintf(
          "Shiny.setInputValue('engine_action', '%s:%s', {priority: 'event'})",
          group, eng
        ),
        icon
      )
    }
    engine_picks <- tagList(
      if (row_has_engine(row, "r")) engine_pick_btn("r"),
      if (row_has_engine(row, "stata")) engine_pick_btn("stata"),
      if (row_has_engine(row, "python") && !row_has_engine(row, "r") && !row_has_engine(row, "stata")) {
        tags$span(class = "engine-badge", title = "Python", engine_icon_python())
      }
    )
    tags$div(
      class = row_class,
      tags$span(label, class = "replication-label", title = label_full),
      tags$div(
        class = "replication-actions",
        if (!is.null(state$doi) && nzchar(state$doi)) {
          tags$a(
            href = shiny_share_url(
              shiny_deep_link_query_list(state$doi, what = group, language = engine)
            ),
            class = "replication-share-link",
            title = paste0("Link to ", label, " on the public server"),
            target = "_blank",
            rel = "noopener noreferrer",
            `aria-label` = paste0("Link to ", label),
            link_icon_svg()
          )
        },
        engine_picks,
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
    if (!is.null(state$replications_load_error) && is.null(state$doi)) {
      return(tags$div(
        class = "alert alert-warning mb-0",
        tags$pre(
          class = "mb-0 mt-0",
          style = "white-space: pre-wrap; font-family: inherit; font-size: inherit; background: transparent; border: 0; padding: 0;",
          format_replication_error(state$replications_load_error)
        )
      ))
    }
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
      if (nrow(tabs) > 0) {
        tagList(
          tags$h6(class = "text-muted mb-2", "Tables"),
          lapply(seq_len(nrow(tabs)), function(i) {
            row <- tabs[i, , drop = FALSE]
            replication_row(
              row,
              active_id = active,
              engine = group_engine(row$group[[1]], row)
            )
          })
        )
      },
      if (nrow(figs) > 0) {
        tagList(
          tags$h6(class = "text-muted mb-2 mt-2", "Figures"),
          lapply(seq_len(nrow(figs)), function(i) {
            row <- figs[i, , drop = FALSE]
            replication_row(
              row,
              active_id = active,
              engine = group_engine(row$group[[1]], row)
            )
          })
        )
      },
      if (!is.null(state$prep_df) && nrow(state$prep_df) > 0) {
        tagList(
          tags$h6(class = "text-muted mb-2 mt-2", "Pipeline steps"),
          lapply(seq_len(nrow(state$prep_df)), function(i) {
            row <- state$prep_df[i, , drop = FALSE]
            step_id <- row$id[[1]]
            step_engine <- row$engine[[1]] %||% "r"
            safe_id <- gsub("[^a-zA-Z0-9]", "_", step_id)
            engine_badge <- switch(
              step_engine,
              stata = tags$span(class = "engine-badge", title = "Stata", engine_icon_stata()),
              python = tags$span(class = "engine-badge", title = "Python", engine_icon_python()),
              tags$span(class = "engine-badge", title = "R", engine_icon_r())
            )
            tags$div(
              class = paste(
                "replication-row d-flex align-items-center rounded",
                if (identical(state$selected_replication, step_id)) {
                  "bg-light border border-primary"
                } else {
                  ""
                }
              ),
              engine_badge,
              tags$span(row$label[[1]], class = "replication-label", title = row$label_full[[1]]),
              tags$div(
                class = "replication-actions",
                actionButton(
                  paste0("prep_run_", safe_id),
                  "Run",
                  class = "btn-outline-primary btn-sm",
                  onclick = sprintf(
                    "Shiny.setInputValue('replication_action', 'replicate:%s', {priority: 'event'})",
                    step_id
                  )
                )
              )
            )
          })
        )
      }
    )
  })

  observeEvent(input$engine_action, {
    req(input$engine_action)
    parts <- strsplit(input$engine_action, ":", fixed = TRUE)[[1]]
    req(length(parts) == 2)
    row <- resolve_replication_row(parts[[1]])
    eng <- parts[[2]]
    if (!row_has_engine(row, eng)) return()
    state$group_engines[[parts[[1]]]] <- eng
    cur_row <- tryCatch(
      resolve_replication_row(state$selected_replication),
      error = function(e) NULL
    )
    same_group <- !is.null(cur_row) && identical(cur_row$group[[1]], parts[[1]])
    state$selected_replication <- parts[[1]]
    state$selected_type <- row$type[[1]]
    if (isTRUE(same_group)) {
      state$selected_result <- NULL
      state$selected_source <- "artifact"
      load_selected_artifact(fallback_live = FALSE)
    }
    sync_url_to_selection()
  }, ignoreInit = TRUE)

  observeEvent(input$replication_action, {
    req(input$replication_action, state$doi)
    parts <- strsplit(input$replication_action, ":", fixed = TRUE)[[1]]
    req(length(parts) == 2)
    action <- parts[[1]]
    group_or_id <- parts[[2]]

    if (!is.null(state$prep_df) && nrow(state$prep_df) > 0 &&
        group_or_id %in% state$prep_df$id) {
      state$selected_replication <- group_or_id
      state$selected_type <- "step"
      state$selected_result <- NULL
      if (action == "replicate") {
        run_live_replication(
          state$doi,
          group_or_id,
          prep_step_language(group_or_id, state$prep_steps)
        )
      }
      updateTabsetPanel(session, "result_tabs", selected = "Output")
      return()
    }

    req(state$replications_df)
    row <- resolve_replication_row(group_or_id)

    state$selected_replication <- row$group[[1]]
    state$selected_type <- row$type[[1]]
    state$selected_result <- NULL

    if (action == "display") {
      state$selected_source <- "artifact"
      load_selected_artifact(fallback_live = FALSE)
    } else if (action == "replicate") {
      tryCatch(
        {
          target <- selected_replication_id_and_language()
          run_live_replication(state$doi, target$id, target$language)
        },
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
      target <- selected_replication_id_and_language()
      loaded <- replicate_fn(
        "load_replication_for_display",
        state$doi,
        target$id,
        language = target$language,
        prefer = "artifact",
        fallback_live = fallback_live,
        install_deps = FALSE,
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
        language = selected_replication_language(),
        source = state$selected_source,
        install_deps = is_live_source(state$selected_source),
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    }, error = function(e) {
      list(ok = FALSE, error = e)
    })
  })

  run_live_replication <- function(doi, what, language = "r") {
    audit <- tryCatch(
      check_study_compat(
        doi,
        folder = state$registry_folder,
        repo = state$registry_repo,
        materialize_study = TRUE,
        include_registry_audit = FALSE
      ),
      error = function(e) list(error = conditionMessage(e), ready = FALSE)
    )
    if (!is.null(audit$error) || !isTRUE(audit$ready)) {
      dependency_hint_modal(session, doi, audit = audit)
      hint <- tryCatch(
        maintainer_hint(doi = doi, audit = audit),
        error = function(e) conditionMessage(e)
      )
      state$selected_result <- structure(
        list(message = hint),
        class = c("dependency_error", "error", "condition")
      )
      state$selected_source <- "live"
      state$progress <- NULL
      return(invisible(NULL))
    }

    tryCatch({
      withProgress(message = "Running live replication...", value = 0.2, {
        state$progress <- "Running replication"
        ensure_study_replication_package(doi, folder = state$registry_folder, repo = state$registry_repo)
        loaded <- replicate_fn(
          "load_replication_for_display",
          doi,
          what,
          language = language,
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
    caption <- selected_replication_title(state)
    source_line <- replication_source_label(state$selected_source, caption)
    if (is_step_replication(state$selected_type)) {
      tagList(
        p(class = "text-muted", source_line),
        uiOutput("selected_prep_ui")
      )
    } else if (is_figure_replication(state$selected_type)) {
      tagList(
        p(class = "text-muted", source_line),
        uiOutput("selected_figure_ui")
      )
    } else if (is_table_replication(state$selected_type)) {
      tagList(
        p(class = "text-muted", source_line),
        uiOutput("selected_table_ui")
      )
    } else {
      helpText("Select a pipeline step, table, or figure to view output.")
    }
  })

  output$selected_prep_ui <- renderUI({
    tryCatch({
      if (inherits(state$selected_result, "error")) {
        return(replication_error_ui(
          state$selected_result,
          doi = state$doi,
          folder = state$registry_folder,
          repo = state$registry_repo
        ))
      }
      if (is.null(state$selected_result)) {
        return(helpText("Click Run to execute this pipeline step."))
      }
      raw <- state$selected_result
      status <- NULL
      output_path <- NULL
      obj <- raw
      if (is.list(raw) && !is.null(raw$object)) {
        status <- raw$status %||% NULL
        output_path <- raw$output_path %||% NULL
        obj <- replicate_fn("replication_object", raw)
      }
      state$prep_download_path <- output_path
      tagList(
        if (!is.null(status) && nzchar(status)) {
          tags$div(class = "alert alert-success mb-2", status)
        },
        if (!is.null(output_path) && nzchar(output_path) && file.exists(output_path)) {
          tagList(
            tags$p(class = "mb-1", tags$strong("Output file: "), tags$code(basename(output_path))),
            downloadButton("prep_download", "Download output", class = "btn-sm btn-outline-secondary mb-2")
          )
        },
        if (is.data.frame(obj)) {
          tagList(
            tags$p(class = "text-muted mb-1", "Preview (first rows):"),
            tableOutput("selected_prep_table")
          )
        } else if (is.list(obj) && !is.null(obj$note)) {
          tags$p(class = "mb-0", obj$note)
        } else {
          tags$pre(class = "mb-0", utils::capture.output(print(obj)))
        }
      )
    }, error = function(e) {
      replication_error_ui(
        e,
        doi = state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      )
    })
  })

  output$selected_prep_table <- renderTable({
    req(state$selected_result)
    raw <- state$selected_result
    obj <- if (is.list(raw) && !is.null(raw$object)) {
      replicate_fn("replication_object", raw)
    } else {
      raw
    }
    req(is.data.frame(obj))
    obj
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$prep_download <- downloadHandler(
    filename = function() {
      path <- state$prep_download_path
      if (is.null(path) || !nzchar(path)) {
        return("prep_output.dat")
      }
      basename(path)
    },
    content = function(file) {
      path <- state$prep_download_path
      req(!is.null(path), file.exists(path))
      file.copy(path, file, overwrite = TRUE)
    }
  )

  output$selected_figure_ui <- renderUI({
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
    target <- selected_replication_id_and_language()
    lang <- target$language
    rep_row <- replication_row_for_id(state$replications_df, state$selected_replication)
    include_lang <- !is.null(rep_row) && row_engine_count(rep_row) > 1L
    simple_code <- replication_run_snippet(
      state$doi,
      target$id,
      lang,
      include_language = include_lang
    )
    full_code <- tryCatch(
      paste(
        replicate_fn(
          "get_code",
          state$doi,
          target$id,
          language = lang,
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
            target$id,
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
        target$id,
        language = lang,
        folder = state$registry_folder,
        repo = state$registry_repo
      ),
      error = function(e) "r"
    )
    code_panel_ui(simple_code, full_code, language = code_lang)
  })

  observeEvent(input$show_study_pipeline, {
    req(state$doi)
    showModal(modalDialog(
      title = "Steps pipeline",
      study_dag_panel_ui(
        state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo,
        heading = FALSE
      ),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  })

  output$selected_pipeline_ui <- renderUI({
    req(state$selected_replication, state$doi)
    meta <- tryCatch(
      replicate_fn(
        "get_replication_meta",
        state$doi,
        folder = state$registry_folder,
        repo = state$registry_repo
      ),
      error = function(e) NULL
    )
    if (is.null(meta)) {
      return(helpText("Could not load study metadata for the pipeline view."))
    }
    target <- selected_replication_id_and_language()
    paths <- tryCatch(
      replicate_fn("study_dag_for_step", meta, target$id),
      error = function(e) list()
    )
    if (length(paths) == 0L) {
      return(helpText("No pipeline graph available for this item."))
    }
    tagList(
      tags$div(
        class = "study-dag-panel",
        lapply(paths, study_dag_chain_ui)
      ),
      study_dag_legend_ui()
    )
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
