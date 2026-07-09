#' Format a DOI or path for use in maintainer hint code
#' @keywords internal
hint_quote_study <- function(doi) {
  d <- as.character(doi[[1]] %||% doi)
  shQuote(d, type = "sh")
}

#' Suggest permanent Python / Stata paths via Renviron
#'
#' @return Character vector of \code{KEY=value} lines.
#' @keywords internal
executable_renviron_lines <- function() {
  py <- tryCatch(find_python_executable(), error = function(e) NULL)
  st <- find_stata_executable()
  lines <- character(0)
  if (!is.null(py) && nzchar(py)) {
    py_norm <- gsub("\\\\", "/", py)
    lines <- c(lines, paste0("PYTHON=", py_norm))
  }
  if (!is.null(st) && nzchar(st)) {
    st_norm <- gsub("\\\\", "/", st)
    lines <- c(lines, paste0("STATA=", st_norm))
  }
  lines
}

#' Maintainer guidance when dependencies or executables are missing
#'
#' Used in error messages, Shiny modals, and documentation. Returns plain text
#' suitable for \code{stop()} or display.
#'
#' @param doi Optional study DOI for single-study install hints.
#' @param audit Optional \code{study_system_compatibility} object from
#'   [check_study_compatibility()].
#' @param scope \code{"study"} or \code{"package"} for package-backed studies.
#' @param package Package name when \code{scope = "package"}.
#' @param missing_r Character vector of missing CRAN packages.
#' @param include_path_hints Include \code{.Renviron} lines for Python/Stata.
#' @return Character scalar (multi-line).
#' @seealso [install_study_dependencies()], [install_registry_dependencies()],
#'   [check_study_compatibility()]
#'
#' @examples
#' \dontrun{
#' maintainer_dependency_hint("10.1017/S0003055426101749")
#' }
#'
#' @export
maintainer_dependency_hint <- function(
  doi = NULL,
  audit = NULL,
  scope = c("study", "package"),
  package = NULL,
  missing_r = NULL,
  include_path_hints = TRUE
) {
  scope <- match.arg(scope)
  lines <- character(0)
  kind <- if (!is.null(audit) && !is.null(audit$kind)) {
    audit$kind
  } else if (identical(scope, "package")) {
    "package"
  } else {
    "folder"
  }
  build_fn <- study_build_function(kind)

  lines <- c(
    lines,
    "This machine is missing dependencies declared in replication.yml."
  )

  if (!is.null(audit) && !is.null(audit$dependencies)) {
    pkg_block <- audit$dependencies$package %||% NULL
    if (!is.null(pkg_block) && !isTRUE(pkg_block$ok)) {
      lines <- c(
        lines,
        paste0(
          "Study package not installed: ",
          paste(pkg_block$missing %||% pkg_block$required, collapse = ", ")
        )
      )
    }
    deps <- audit$dependencies
    for (eng in c("r", "python", "stata")) {
      block <- deps[[eng]]
      if (is.null(block)) next
      missing <- block$missing %||% character(0)
      if (length(missing) == 0L || isTRUE(block$ok)) next
      label <- switch(eng, r = "R", python = "Python", stata = "Stata", eng)
      lines <- c(lines, paste0(label, " missing: ", paste(missing, collapse = ", ")))
    }
  } else if (length(missing_r) > 0L) {
    lines <- c(lines, paste0("R missing: ", paste(missing_r, collapse = ", ")))
  }

  lines <- c(lines, "", "Maintainers — install for this study:")
  if (!is.null(doi) && nzchar(as.character(doi))) {
    lines <- c(
      lines,
      paste0("  install_study_dependencies(", hint_quote_study(doi), ")")
    )
  } else {
    lines <- c(lines, "  install_study_dependencies(<doi-or-study-path>)")
  }
  lines <- c(
    lines,
    "",
    "Install for every study in the registry:",
    "  install_registry_dependencies()",
    "",
    "Build display artifacts after dependencies are satisfied:",
    if (identical(kind, "package") && !is.null(package)) {
      paste0("  ", build_fn, "(", shQuote(as.character(package[[1]] %||% package), type = "sh"), ", install_deps = TRUE)")
    } else if (identical(kind, "package") && !is.null(audit$dependencies$package$required)) {
      paste0("  ", build_fn, "(", shQuote(audit$dependencies$package$required[[1]], type = "sh"), ", install_deps = TRUE)")
    } else {
      paste0("  ", build_fn, "(<study-path>, install_deps = TRUE)")
    },
    "",
    "Check without installing:",
    if (!is.null(doi) && nzchar(as.character(doi))) {
      paste0("  check_study_compatibility(", hint_quote_study(doi), ")")
    } else {
      "  check_study_compatibility(<doi>)"
    }
  )

  if (isTRUE(include_path_hints)) {
    renv <- executable_renviron_lines()
    lines <- c(
      lines,
      "",
      "Point R at Python or Stata permanently (~/.Renviron, then restart R):",
      "  usethis::edit_r_environ()   # or edit the file by hand"
    )
    if (length(renv) > 0L) {
      lines <- c(lines, paste0("  ", renv))
    } else {
      lines <- c(
        lines,
        "  PYTHON=C:/path/to/python.exe",
        "  STATA=C:/Program Files/Stata17/StataMP-64.exe"
      )
    }
    lines <- c(
      lines,
      "",
      "Live Run does not install packages. Use the functions above once during",
      "machine setup (see vignette(\"maintainer-setup\"))."
    )
  }

  paste(lines, collapse = "\n")
}

#' Shiny-friendly list form of [maintainer_dependency_hint()]
#' @param ... Passed to [maintainer_dependency_hint()].
#' @return List with \code{title}, \code{body}, and \code{lines}.
#' @keywords internal
maintainer_dependency_hint_ui <- function(...) {
  body <- maintainer_dependency_hint(...)
  list(
    title = "Missing dependencies",
    body = body,
    lines = strsplit(body, "\n", fixed = TRUE)[[1]]
  )
}
