#' Strip ANSI color/hyperlink escape codes from text
#'
#' @param x Character vector (log lines, error messages, etc.).
#' @return Character vector with ANSI escapes removed.
#' @keywords internal
strip_ansi_escapes <- function(x) {
  if (!is.character(x) || !length(x)) {
    return(x)
  }
  tryCatch({
    x <- gsub("\x1b\\[[0-9;]*m", "", x, perl = TRUE)
    gsub("\x1b\\]8;[^\x1b]*\x1b\\\\", "", x, perl = TRUE)
  }, error = function(e) {
    gsub("\x1b", "", x, fixed = TRUE)
  })
}

#' Format a replication error for user-facing display
#'
#' Unwraps \code{conditionMessage()} and, when present, parent errors and the
#' call that failed.
#'
#' @param x An error condition or character message.
#' @return A single character string suitable for logs or UI.
#'
#' @examples
#' \dontrun{
#' err <- simpleError("Replication failed", call = quote(run_replication()))
#' replication_error_message(err)
#' }
#'
#' @keywords internal
replication_error_message <- function(x) {
  if (inherits(x, "study_package_error")) {
    return(strip_ansi_escapes(conditionMessage(x)))
  }
  if (is.character(x)) {
    return(strip_ansi_escapes(paste(x, collapse = "\n")))
  }
  if (!inherits(x, "condition")) {
    return(as.character(x))
  }

  parts <- c(conditionMessage(x))

  parent <- x$parent
  if (!is.null(parent) && inherits(parent, "condition")) {
    parts <- c(parts, paste0("Caused by: ", conditionMessage(parent)))
  }

  call <- conditionCall(x)
  if (!is.null(call) && inherits(x, "error")) {
    parts <- c(
      parts,
      paste0("Call: ", paste(deparse(call, nlines = 1, width.cutoff = 120L), collapse = ""))
    )
  }

  strip_ansi_escapes(paste(parts, collapse = "\n\n"))
}

#' Whether an error is the generic empty-\code{steps:} normalize failure
#'
#' @param e A condition.
#' @keywords internal
is_missing_steps_normalize_error <- function(e) {
  if (!inherits(e, "condition")) {
    return(FALSE)
  }
  grepl(
    "must declare a non-empty steps:\\s*block",
    conditionMessage(e),
    ignore.case = TRUE
  )
}

#' User-facing explanation when replication steps cannot be listed
#'
#' Distinguishes private/404/network fetch failures, yaml parse problems, and
#' a genuine empty stub. Shiny surfaces this via [list_replications()] errors
#' and [replication_error_message()].
#'
#' @param meta Parsed registry stub or study metadata.
#' @param ctx Optional paper context from [paper_context()].
#' @param normalize_error Optional normalize/parse error to prefer when the
#'   study yaml was already loaded (e.g. deprecated \code{artifact:}).
#' @return Character scalar.
#' @keywords internal
missing_replication_steps_message <- function(
  meta,
  ctx = NULL,
  normalize_error = NULL
) {
  if (
    !is.null(normalize_error) &&
      inherits(normalize_error, "condition") &&
      !is_missing_steps_normalize_error(normalize_error)
  ) {
    return(conditionMessage(normalize_error))
  }

  n_steps <- length(meta$steps %||% list())
  if (n_steps > 0L && !is.null(normalize_error)) {
    return(conditionMessage(normalize_error))
  }

  if (is_package_replication(meta)) {
    return(package_study_steps_unavailable_message(meta, ctx))
  }
  if (is_folder_study_replication(meta, ctx)) {
    return(folder_study_steps_unavailable_message(meta, ctx))
  }

  paste0(
    "No replication steps found for this study.\n\n",
    "The registry entry has no steps: block and no fetchable study repository. ",
    "Add repo: / paper.study_repo (folder-backed) or paper.package ",
    "(package-backed), then ensure the study replication.yml is publicly readable."
  )
}

#' Diagnose missing steps for a folder-backed study
#' @keywords internal
folder_study_steps_unavailable_message <- function(meta, ctx = NULL) {
  repo <- study_repo_slug(meta, ctx)
  ref <- study_repo_ref(meta)
  header <- paste0(
    "Could not load replication steps for this study.\n\n",
    "The registry stub has no steps:; tables and figures come from the study repo ",
    repo, "@", ref, "."
  )

  local_notes <- character(0)
  if (!is.null(ctx) && !is.null(ctx$local_root) && nzchar(as.character(ctx$local_root))) {
    local_yml <- file.path(ctx$local_root, "replication.yml")
    probe <- yaml_url_probe(local_yml)
    if (!isTRUE(probe$ok)) {
      local_notes <- c(
        local_notes,
        paste0("Local study path: ", local_yml, " — ", probe$status)
      )
    }
  }
  local_path <- tryCatch(
    resolve_study_folder_path(meta, ctx),
    error = function(e) NULL
  )
  if (!is.null(local_path)) {
    local_yml <- file.path(local_path, "replication.yml")
    probe <- yaml_url_probe(local_yml)
    if (isTRUE(probe$ok)) {
      return(describe_fetched_yaml_without_usable_steps(
        header,
        source_label = paste0("local study yaml at ", local_yml),
        parsed = probe$parsed,
        probe = probe
      ))
    }
    local_notes <- c(
      local_notes,
      paste0("Local study path: ", local_yml, " — ", probe$status)
    )
  }

  if (identical(repo, DEFAULT_REGISTRY_REPO) || !nzchar(repo)) {
    return(paste0(
      header, "\n\n",
      "No study repository slug is set on the registry stub ",
      "(expected repo: or paper.study_repo)."
    ))
  }

  urls <- folder_study_yaml_urls(repo, ref)
  probes <- lapply(urls, yaml_url_probe)
  lines <- vapply(seq_along(urls), function(i) {
    paste0("  ", urls[[i]], "\n    ", probes[[i]]$status)
  }, character(1))

  ok_idx <- which(vapply(probes, function(p) isTRUE(p$ok), logical(1)))
  if (length(ok_idx) > 0L) {
    p <- probes[[ok_idx[[1]]]]
    return(describe_fetched_yaml_without_usable_steps(
      header,
      source_label = urls[[ok_idx[[1]]]],
      parsed = p$parsed,
      probe = p
    ))
  }

  paste0(
    header, "\n\n",
    if (length(local_notes)) paste0(paste(local_notes, collapse = "\n"), "\n\n") else "",
    "Tried study replication.yml:\n",
    paste(lines, collapse = "\n"),
    "\n\nIf the status is HTTP 404/403, make the study repository public ",
    "(or otherwise readable by anonymous raw.githubusercontent.com), ",
    "check repo:/study_ref, then retry."
  )
}

#' Diagnose missing steps for a package-backed study
#' @keywords internal
package_study_steps_unavailable_message <- function(meta, ctx = NULL) {
  repo <- package_repo_slug(meta, ctx)
  ref <- package_repo_ref(meta)
  pkg <- as.character(meta$paper$package[[1]] %||% "")
  header <- paste0(
    "Could not load replication steps for this study.\n\n",
    "Package-backed study ", if (nzchar(pkg)) paste0("(", pkg, ") ") else "",
    "needs replication.yml from ", repo, "@", ref, "."
  )
  if (is.null(repo) || !nzchar(as.character(repo)) ||
      identical(as.character(repo), "replicate-anything/registry")) {
    return(paste0(
      header, "\n\n",
      "No package repository slug is set (expected repo: or paper.package_repo)."
    ))
  }
  urls <- package_replication_yaml_urls(repo, ref)
  probes <- lapply(urls, yaml_url_probe)
  lines <- vapply(seq_along(urls), function(i) {
    paste0("  ", urls[[i]], "\n    ", probes[[i]]$status)
  }, character(1))
  ok_idx <- which(vapply(probes, function(p) isTRUE(p$ok), logical(1)))
  if (length(ok_idx) > 0L) {
    p <- probes[[ok_idx[[1]]]]
    return(describe_fetched_yaml_without_usable_steps(
      header,
      source_label = urls[[ok_idx[[1]]]],
      parsed = p$parsed,
      probe = p
    ))
  }
  paste0(
    header, "\n\n",
    "Tried package replication.yml:\n",
    paste(lines, collapse = "\n"),
    "\n\nIf the status is HTTP 404/403, make the package repository public ",
    "(or otherwise readable), check package_repo/package_ref, then retry."
  )
}

#' Explain a successfully fetched yaml that still yields no listable steps
#' @keywords internal
describe_fetched_yaml_without_usable_steps <- function(
  header,
  source_label,
  parsed,
  probe = NULL
) {
  n_steps <- length(parsed$steps %||% list())
  if (n_steps == 0L) {
    if (!is.null(parsed$prep) || !is.null(parsed$replications)) {
      return(paste0(
        header, "\n\n",
        "Fetched ", source_label, " but it still uses legacy prep:/replications: ",
        "blocks. Convert to a unified steps: DAG (see folder_replication skill)."
      ))
    }
    return(paste0(
      header, "\n\n",
      "Fetched ", source_label, " successfully, but it has no steps: block ",
      "(empty stub / incomplete study yaml)."
    ))
  }
  normalize_err <- tryCatch(
    {
      normalize_study_steps(parsed)
      NULL
    },
    error = function(e) e
  )
  if (!is.null(normalize_err)) {
    return(paste0(
      header, "\n\n",
      "Fetched ", source_label, " (", n_steps, " raw step(s)), but yaml ",
      "normalize failed:\n",
      conditionMessage(normalize_err)
    ))
  }
  paste0(
    header, "\n\n",
    "Fetched ", source_label, " with ", n_steps,
    " step(s), but none are listable display tables/figures",
    if (!is.null(probe) && nzchar(probe$status %||% "")) {
      paste0(" [", probe$status, "]")
    } else {
      ""
    },
    "."
  )
}

#' Run a replication and return a result or error object
#'
#' Like \code{\link{render_for_display}} but never throws; failures are
#' returned as \code{simpleError} objects.
#'
#' @inheritParams render_for_display
#' @return A replication result list, a display-ready object, or an error.
#'
#' @examples
#' \dontrun{
#' try_render_for_display("10.1177/00491241211036161", "fig_1")
#' }
#'
#' @keywords internal
try_render_for_display <- function(
  doi,
  what,
  language = NULL,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  force = FALSE
) {
  tryCatch(
    render_for_display(
      doi,
      what,
      language = language,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      force = force
    ),
    error = function(e) e
  )
}
