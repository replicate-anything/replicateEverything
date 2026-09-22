#' Scaffold a local starter study
#'
#' Creates a minimal folder-backed study under \code{path}: \code{.Rproj},
#' \code{data/}, \code{code/}, \code{outputs/}, and \code{replication.yml}.
#' The layout mirrors the gold example study, but the handle, title, and
#' metadata are yours so nothing is named or registered as
#' \code{rep-template}.
#'
#' \code{path} must be missing or empty unless \code{FORCE = TRUE}. When
#' forcing, only scaffold targets are overwritten; unrelated files in the
#' folder are left in place. For the empty-folder check, common OS / Dropbox /
#' RStudio junk is ignored (\code{desktop.ini}, \code{Thumbs.db},
#' \code{.DS_Store}, \code{.dropbox}, \code{.dropbox.attr}, \code{.Rproj.user},
#' \code{.Rhistory}, \code{.RData}, \code{.Ruserdata}); \code{.git} and other
#' real project files still count as non-empty.
#'
#' @param path Directory for the new study. Created if missing; must be empty
#'   unless \code{FORCE = TRUE}. Common OS / Dropbox junk files are ignored
#'   when deciding emptiness (see details above). Use \code{"here"} or
#'   \code{"local"} (case-insensitive synonyms) for the current working
#'   directory (\code{getwd()}).
#' @param name Project / study handle. Defaults to \code{basename(path)} after
#'   resolving \code{path} (so \code{path = "here"} / \code{"local"} defaults
#'   to the basename of the working directory). Must not be
#'   \code{"rep-template"} (reserved for the published gold template). Used for
#'   \code{paper.study_handle}, the \code{.Rproj} basename, and file headers.
#' @param title Optional paper title. Defaults to a clear local-scaffold label
#'   that includes \code{name}.
#' @param authors Optional author string for \code{paper.authors}.
#' @param FORCE If \code{TRUE}, allow scaffolding into a non-empty folder and
#'   replace scaffold files that already exist (\code{.Rproj},
#'   \code{replication.yml}, \code{data/data.csv}, \code{code/tab_1.R},
#'   \code{README.md}, \code{.gitignore}). Unrelated files are not deleted.
#'   Directories are never deleted.
#' @return Invisibly, the normalized study root path.
#' @export
#'
#' @examples
#' \dontrun{
#' get_started("~/my-first-replication", name = "my-first-replication")
#' get_started("~/my-first-replication", name = "my-first-replication", FORCE = TRUE)
#' get_started("here")  # scaffold into getwd(); name defaults to basename(getwd())
#' get_started("local") # same as "here"
#' }
get_started <- function(path,
                        name = basename(path),
                        title = NULL,
                        authors = NULL,
                        FORCE = FALSE) {
  if (missing(path) || is.null(path) || !nzchar(as.character(path)[[1]])) {
    stop("`path` is required.", call. = FALSE)
  }
  path <- trimws(as.character(path)[[1]])
  if (is_local_study_token(path)) {
    path <- getwd()
  }
  path <- normalizePath(path.expand(path), winslash = "/", mustWork = FALSE)

  name <- .get_started_sanitize_name(name)
  if (identical(tolower(name), "rep-template")) {
    stop(
      "`name` cannot be \"rep-template\" (reserved for the gold template study). ",
      "Pick a distinct project name, e.g. name = \"my-demo\".",
      call. = FALSE
    )
  }

  if (is.null(title) || !nzchar(as.character(title)[[1]])) {
    title <- paste0("Local get_started scaffold (", name, ")")
  } else {
    title <- as.character(title)[[1]]
  }

  if (is.null(authors) || !nzchar(as.character(authors)[[1]])) {
    authors <- "Local scaffold (get_started)"
  } else {
    authors <- as.character(authors)[[1]]
  }

  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  if (!dir.exists(path)) {
    stop("Could not create directory: ", path, call. = FALSE)
  }

  if (!.get_started_dir_is_empty(path) && !isTRUE(FORCE)) {
    stop(.get_started_nonempty_message(path), call. = FALSE)
  }

  for (subdir in c("data", "code", "outputs")) {
    dir.create(file.path(path, subdir), recursive = TRUE, showWarnings = FALSE)
  }

  .get_started_write_file(
    file.path(path, paste0(name, ".Rproj")),
    .get_started_rproj_contents()
  )
  .get_started_write_file(
    file.path(path, "replication.yml"),
    .get_started_yaml_contents(name = name, title = title, authors = authors)
  )
  .get_started_write_file(
    file.path(path, "data", "data.csv"),
    .get_started_data_csv()
  )
  .get_started_write_file(
    file.path(path, "code", "tab_1.R"),
    .get_started_tab_1_r(name = name)
  )
  .get_started_write_file(
    file.path(path, "README.md"),
    .get_started_readme(name = name, title = title)
  )
  .get_started_write_file(
    file.path(path, ".gitignore"),
    .get_started_gitignore()
  )

  message(
    "Created local starter study at ", path, "\n",
    "  handle: ", name, "\n",
    "  Next: open the .Rproj, then try\n",
    "    replicateEverything::run_replication(\"", name, "\", \"tab_1\")\n",
    "  or bake Display outputs with\n",
    "    replicateEverything::build_study_outputs(\"", path, "\")"
  )
  invisible(path)
}

#' @keywords internal
.get_started_sanitize_name <- function(name) {
  name <- as.character(name)[[1]]
  name <- trimws(name)
  if (!nzchar(name)) {
    stop("`name` must be a non-empty project handle.", call. = FALSE)
  }
  # Keep folder-friendly handles; reject path separators and spaces.
  if (grepl("[/\\\\]", name)) {
    stop("`name` must not contain path separators.", call. = FALSE)
  }
  cleaned <- gsub("[^A-Za-z0-9._-]+", "-", name)
  cleaned <- gsub("^-+|-+$", "", cleaned)
  if (!nzchar(cleaned) || !grepl("^[A-Za-z0-9]", cleaned)) {
    stop(
      "`name` must start with a letter or digit after sanitizing; got: ",
      name,
      call. = FALSE
    )
  }
  if (!identical(cleaned, name)) {
    message("Sanitized name from \"", name, "\" to \"", cleaned, "\".")
  }
  cleaned
}

#' OS / Dropbox / RStudio noise ignored when deciding whether \code{path} is
#' empty. Case-insensitive match on the basename only. Not ignored:
#' \code{.git} or other user / project files.
#' @noRd
.get_started_ignored_entry_names <- c(
  "desktop.ini",
  "Thumbs.db",
  ".DS_Store",
  ".dropbox",
  ".dropbox.attr",
  ".Rproj.user",
  ".Rhistory",
  ".RData",
  ".Ruserdata"
)

#' @keywords internal
.get_started_dir_entries <- function(path) {
  list.files(path, all.files = TRUE, no.. = TRUE)
}

#' @keywords internal
.get_started_blocking_entries <- function(path) {
  entries <- .get_started_dir_entries(path)
  ignored <- tolower(.get_started_ignored_entry_names)
  entries[!tolower(entries) %in% ignored]
}

#' @keywords internal
.get_started_dir_is_empty <- function(path) {
  length(.get_started_blocking_entries(path)) == 0L
}

#' @keywords internal
.get_started_nonempty_message <- function(path, max_show = 10L) {
  entries <- sort(.get_started_blocking_entries(path))
  n <- length(entries)
  show <- entries[seq_len(min(n, max_show))]
  listed <- paste0("`", show, "`", collapse = ", ")
  if (n > max_show) {
    listed <- paste0(listed, ", and ", n - max_show, " more")
  }
  paste0(
    "`path` is not empty: ", path, ". ",
    "Found ", n, if (n == 1L) " entry: " else " entries: ", listed, ". ",
    "Use an empty folder, or pass FORCE = TRUE to replace scaffold files ",
    "(.Rproj, replication.yml, data/data.csv, code/tab_1.R, README.md, .gitignore)."
  )
}

#' @keywords internal
.get_started_write_file <- function(path, contents) {
  writeLines(contents, path, useBytes = FALSE)
  invisible(TRUE)
}

#' @keywords internal
.get_started_rproj_contents <- function() {
  c(
    "Version: 1.0",
    "",
    "RestoreWorkspace: Default",
    "SaveWorkspace: Default",
    "AlwaysSaveHistory: Default",
    "",
    "EnableCodeIndexing: Yes",
    "UseSpacesForTab: Yes",
    "NumSpacesForTab: 2",
    "Encoding: UTF-8",
    "",
    "RnwWeave: Sweave",
    "LaTeX: pdfLaTeX"
  )
}

#' @keywords internal
.get_started_data_csv <- function() {
  c(
    "X,Y",
    "0,0",
    "0,0",
    "0,0",
    "0,1",
    "1,0",
    "1,1",
    "1,1",
    "1,1"
  )
}

#' @keywords internal
.get_started_tab_1_r <- function(name) {
  c(
    paste0("# Table 1 — Local get_started scaffold (", name, ")"),
    paste0("# Execute via: run_replication(\"", name, "\", \"tab_1\")"),
    "",
    "library(estimatr)",
    "",
    "make_tab_1 <- function(data) {",
    "  estimatr::lm_robust(Y ~ X, data = data)",
    "}",
    "",
    "format_tab_1 <- function(object) {",
    "  coefs <- as.data.frame(summary(object)$coefficients)",
    "  knitr::kable(coefs, format = \"html\", digits = 3)",
    "}"
  )
}

#' @keywords internal
.get_started_yaml_contents <- function(name, title, authors) {
  year <- format(Sys.Date(), "%Y")
  c(
    "paper:",
    paste0("  study_handle: ", name),
    paste0("  title: \"", .get_started_yaml_escape(title), "\""),
    paste0("  year: \"", year, "\""),
    paste0("  authors: ", .get_started_yaml_escape(authors)),
    "  abstract: >",
    paste0(
      "    Local starter study created by replicateEverything::get_started(). ",
      "Handle \"", name, "\"."
    ),
    "  dependencies:",
    "    - estimatr",
    "    - knitr",
    "",
    "languages:",
    "  - r",
    "",
    "steps:",
    "  - id: tab_1",
    "    type: table",
    "    label: Simple table",
    "    description: OLS of Y on X with robust SEs (estimatr::lm_robust)",
    "    engine: r",
    "    inputs:",
    "      - data/data.csv",
    "    code: code/tab_1.R",
    "    format: format_tab_1",
    "    outputs:",
    "      - outputs/tab_1.html",
    "    dependencies:",
    "      - estimatr",
    "      - knitr",
    "",
    "  - id: tab_1_format",
    "    type: format",
    "    parent: tab_1",
    "    code: code/tab_1.R"
  )
}

#' @keywords internal
.get_started_yaml_escape <- function(x) {
  gsub("\"", "\\\\\"", as.character(x)[[1]], fixed = TRUE)
}

#' @keywords internal
.get_started_readme <- function(name, title) {
  c(
    paste0("# ", name),
    "",
    paste0(title, "."),
    "",
    "Created by `replicateEverything::get_started()`.",
    "",
    paste0("- **Handle:** `", name, "` (no article DOI)"),
    "- **One table:** OLS of `Y` on `X` with `estimatr::lm_robust`",
    "",
    "## Layout",
    "",
    "```",
    "replication.yml   # metadata + steps DAG",
    "data/data.csv     # toy input",
    "code/tab_1.R      # make_tab_1() + format_tab_1()",
    "outputs/          # bake Display HTML here",
    paste0(name, ".Rproj"),
    "```",
    "",
    "## Try it",
    "",
    "```r",
    "library(replicateEverything)",
    paste0("run_replication(\"", name, "\", \"tab_1\")"),
    "build_study_outputs(\".\")",
    "```",
    "",
    "Replace the toy CSV and `code/tab_1.R` with your study materials, then",
    "extend `replication.yml` steps as needed."
  )
}

#' @keywords internal
.get_started_gitignore <- function() {
  c(
    ".Rproj.user",
    ".Rhistory",
    ".RData",
    ".Ruserdata",
    "outputs/staging/",
    "*.log"
  )
}
