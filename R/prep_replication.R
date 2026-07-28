#' Whether a yaml entry is a pipeline / prep step
#'
#' @param rep Replication or prep entry from \code{replication.yml}.
#' @return Logical scalar.
#' @keywords internal
is_prep_entry <- function(rep) {
  type <- tolower(as.character(rep$type %||% ""))
  if (type %in% c("table", "figure", "format")) {
    return(FALSE)
  }
  if (type %in% c("step", "prep", "pipeline", "transform")) {
    return(TRUE)
  }
  has_outputs <- (!is.null(rep$outputs) && length(rep$outputs) > 0L)
  has_outputs && is.null(rep$type)
}

#' List pipeline prep steps for a paper
#'
#' Superseded by [list_replications()] with `include = "pipeline"`.
#'
#' @inheritParams list_replications
#' @return A list of prep step entries.
#' @keywords internal
list_prep_steps <- function(doi, repo = NULL, folder = NULL) {
  list_replications(doi, repo = repo, folder = folder, include = "pipeline")
}

#' Resolve a prep step output path on disk
#'
#' @param prep Prep entry from \code{replication.yml}.
#' @param ctx Paper context from \code{paper_context()}.
#' @param meta Optional parsed replication metadata.
#' @keywords internal
prep_output_path <- function(prep, ctx, meta = NULL) {
  p <- step_primary_output_path(prep, ctx, meta = meta)
  if (!is.null(p) && nzchar(p)) {
    return(p)
  }
  outs <- step_primary_declared_output_rels(prep)
  if (length(outs) == 0L || !nzchar(as.character(outs[[1]] %||% ""))) {
    return(NULL)
  }
  out <- as.character(outs[[1]])
  resolve_registry_file(out, ctx, meta = meta, local_only = TRUE)
}

#' Whether a prep step output already exists
#'
#' @inheritParams prep_output_path
#' @keywords internal
prep_output_ready <- function(prep, ctx, meta = NULL) {
  path <- prep_output_path(prep, ctx, meta = meta)
  !is.null(path) && nzchar(path) && file.exists(path)
}

#' Find a prep entry by id
#'
#' @param meta Parsed replication metadata.
#' @param step_id Prep step identifier.
#' @keywords internal
find_prep_entry <- function(meta, step_id) {
  step_id <- as.character(step_id)
  pipeline <- collect_study_step_entries(meta)
  pipeline <- pipeline[vapply(pipeline, is_prep_entry, logical(1))]
  matches <- pipeline[vapply(pipeline, function(x) {
    identical(as.character(x$id), step_id)
  }, logical(1))]
  if (length(matches) == 0L) {
    stop("Prep step ", step_id, " not found in metadata", call. = FALSE)
  }
  matches[[1]]
}

#' Collapse and optionally truncate a yaml blurb for Display captions
#'
#' @param text Character scalar.
#' @param max_chars Maximum length before ellipsis (default 140).
#' @return Single-line character scalar.
#' @keywords internal
short_prep_display_blurb <- function(text, max_chars = 140L) {
  txt <- trimws(gsub("\\s+", " ", as.character(text %||% ""), perl = TRUE))
  if (!nzchar(txt)) {
    return("")
  }
  max_chars <- as.integer(max_chars[[1]] %||% 140L)
  if (!is.finite(max_chars) || max_chars < 24L) {
    max_chars <- 140L
  }
  if (nchar(txt) <= max_chars) {
    return(txt)
  }
  paste0(substr(txt, 1L, max_chars - 1L), "\u2026")
}

#' Caption for a prep / transform step in Shiny and reports
#'
#' Prefers a short \code{path_note:} when present, otherwise a truncated
#' \code{description:}, so Display banners stay readable.
#'
#' @param prep Prep step entry from \code{replication.yml}.
#' @return Character string like \code{`Analysis data` step (Rename ...)}.
#' @keywords internal
prep_step_display_caption <- function(prep) {
  if (is.null(prep) || !is.list(prep)) {
    return("pipeline step")
  }
  id <- as.character(prep$id %||% "step")
  label <- trimws(as.character(prep$label %||% id))
  note <- short_prep_display_blurb(
    prep$path_note[[1]] %||% prep$path_note %||% ""
  )
  desc <- short_prep_display_blurb(
    prep$description %||% prep$desc %||% ""
  )
  blurb <- if (nzchar(note)) note else desc
  step_name <- paste0("`", label, "` step")
  if (nzchar(blurb) && !identical(blurb, label)) {
    return(paste0(step_name, " (", blurb, ")"))
  }
  step_name
}

#' Whether a prep output path is a marker sink (.done / stamp), not a table
#' @keywords internal
is_prep_marker_sink <- function(path) {
  if (is.null(path) || !nzchar(as.character(path[[1]] %||% ""))) {
    return(FALSE)
  }
  base <- basename(as.character(path[[1]]))
  ext <- tolower(tools::file_ext(base))
  identical(base, ".done") ||
    identical(base, ".stamp") ||
    identical(toupper(base), "DONE") ||
    identical(ext, "done")
}

#' Optional product paths declared for Display (products: / display_products:)
#' @keywords internal
prep_declared_product_rels <- function(prep) {
  if (is.null(prep) || !is.list(prep)) {
    return(character(0))
  }
  raw <- prep$products %||% prep$display_products %||% NULL
  if (is.null(raw) || length(raw) == 0L) {
    return(character(0))
  }
  rels <- unique(as.character(unlist(raw, use.names = FALSE)))
  rels <- trimws(rels)
  rels[nzchar(rels)]
}

#' Cheap row/column note for a tabular file when inexpensive
#' @keywords internal
cheap_tabular_file_note <- function(path, max_bytes = 8e6) {
  if (is.null(path) || !file.exists(path)) {
    return(NULL)
  }
  sz <- file.size(path)
  if (!is.finite(sz) || sz > max_bytes) {
    return(paste0(basename(path), " (", format(sz, big.mark = ","), " bytes)"))
  }
  ext <- tolower(tools::file_ext(path))
  if (identical(ext, "csv")) {
    preview <- tryCatch(
      utils::read.csv(path, nrows = 1L, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    n_lines <- tryCatch(
      length(readLines(path, warn = FALSE)),
      error = function(e) NA_integer_
    )
    if (!is.null(preview) && is.finite(n_lines)) {
      return(sprintf(
        "%s (%d rows x %d cols)",
        basename(path),
        max(0L, as.integer(n_lines) - 1L),
        ncol(preview)
      ))
    }
  }
  if (identical(ext, "dta") && requireNamespace("haven", quietly = TRUE)) {
    preview <- tryCatch(
      haven::read_dta(path, n_max = 1L),
      error = function(e) NULL
    )
    if (!is.null(preview)) {
      return(sprintf(
        "%s (%d+ rows x %d cols; preview)",
        basename(path),
        nrow(preview),
        ncol(preview)
      ))
    }
  }
  if (identical(ext, "rds")) {
    obj <- tryCatch(readRDS(path), error = function(e) NULL)
    if (is.data.frame(obj)) {
      return(sprintf(
        "%s (%d rows x %d cols)",
        basename(path),
        nrow(obj),
        ncol(obj)
      ))
    }
  }
  paste0(basename(path), " (", format(sz, big.mark = ","), " bytes)")
}

#' Inventory files under a prep output directory (shallow)
#' @keywords internal
list_prep_output_dir_notes <- function(dir, max_n = 12L) {
  if (is.null(dir) || !dir.exists(dir)) {
    return(character(0))
  }
  files <- list.files(dir, full.names = TRUE, all.files = FALSE, no.. = TRUE)
  files <- files[!grepl("(^|[\\\\/])_probe([\\\\/]|$)", files)]
  files <- files[basename(files) != ".done"]
  if (length(files) == 0L) {
    return(character(0))
  }
  files <- sort(files)
  show <- files[seq_len(min(length(files), as.integer(max_n)))]
  notes <- vapply(show, function(p) {
    if (dir.exists(p)) {
      n <- length(list.files(p, recursive = TRUE, all.files = FALSE))
      paste0(basename(p), "/ (", n, " files)")
    } else {
      cheap_tabular_file_note(p) %||% basename(p)
    }
  }, character(1))
  if (length(files) > length(show)) {
    notes <- c(notes, paste0("... and ", length(files) - length(show), " more"))
  }
  notes
}

#' Human Display summary for transform / prep sinks (.done, dirs, products)
#'
#' Prefer this over dumping marker-file text. Uses optional yaml
#' \code{products:} / \code{display_products:}, the output directory inventory,
#' and a completion stamp from \code{.done} when present.
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param prep Prep / transform step entry.
#' @param path Primary output path (often a \code{.done} marker).
#' @return A \code{prep_output_preview} with a multi-line \code{note}.
#' @keywords internal
summarize_prep_transform_sink <- function(meta, ctx, prep, path = NULL) {
  id <- as.character(prep$id %||% "step")
  label <- trimws(as.character(prep$label %||% id))
  lines <- character(0)

  stamp <- NULL
  if (!is.null(path) && file.exists(path) && is_prep_marker_sink(path)) {
    stamp_lines <- tryCatch(
      readLines(path, warn = FALSE, encoding = "UTF-8", n = 3L),
      error = function(e) character(0)
    )
    stamp_lines <- trimws(stamp_lines)
    stamp_lines <- stamp_lines[nzchar(stamp_lines)]
    if (length(stamp_lines)) {
      stamp <- stamp_lines[[1]]
    }
  }

  header <- if (!is.null(stamp) && nzchar(stamp)) {
    paste0(label, " — ", stamp)
  } else if (!is.null(path) && file.exists(path)) {
    paste0(
      label, " — output ready (",
      format(file.info(path)$mtime, "%d %b %Y %H:%M:%S"),
      ")"
    )
  } else {
    paste0(label, " — transform / prep step")
  }
  lines <- c(lines, header)

  path_note <- short_prep_display_blurb(
    prep$path_note[[1]] %||% prep$path_note %||% "",
    max_chars = 220L
  )
  if (nzchar(path_note)) {
    lines <- c(lines, paste0("Note: ", path_note))
  }

  if (!is.null(path) && nzchar(path)) {
    rel_marker <- tryCatch(
      prep_manifest_output_path(path, ctx$local_path %||% ctx$folder %||% NULL),
      error = function(e) path
    )
    lines <- c(lines, paste0("Marker / primary output: ", rel_marker %||% path))
  }

  product_rels <- prep_declared_product_rels(prep)
  if (length(product_rels)) {
    lines <- c(lines, "Products:")
    root <- ctx$local_path %||% NULL
    for (rel in product_rels) {
      abs <- if (!is.null(root) && nzchar(root)) {
        file.path(root, rel)
      } else {
        resolve_registry_file(rel, ctx, meta = meta, local_only = TRUE)
      }
      if (!is.null(abs) && dir.exists(abs)) {
        n <- length(list.files(abs, recursive = TRUE, all.files = FALSE))
        lines <- c(lines, sprintf("  %s/ (%d files)", rel, n))
      } else if (!is.null(abs) && file.exists(abs)) {
        note <- cheap_tabular_file_note(abs)
        lines <- c(lines, paste0("  ", rel, if (!is.null(note)) paste0(" — ", note) else ""))
      } else {
        lines <- c(lines, paste0("  ", rel, " (not on disk here)"))
      }
    }
  }

  out_dir <- NULL
  if (!is.null(path) && file.exists(path)) {
    out_dir <- if (dir.exists(path)) path else dirname(path)
  }
  dir_notes <- list_prep_output_dir_notes(out_dir)
  if (length(dir_notes) && length(product_rels) == 0L) {
    lines <- c(lines, "Output directory:")
    lines <- c(lines, paste0("  ", dir_notes))
  }

  ins <- as.character(unlist(prep$inputs %||% list(), use.names = FALSE))
  ins <- trimws(ins)
  ins <- ins[nzchar(ins)]
  if (length(ins)) {
    show <- ins[seq_len(min(6L, length(ins)))]
    lines <- c(lines, paste0("Key inputs: ", paste(show, collapse = "; ")))
    if (length(ins) > length(show)) {
      lines <- c(lines, paste0("  ... and ", length(ins) - length(show), " more inputs"))
    }
  }

  structure(
    list(
      path = path %||% NA_character_,
      note = paste(lines, collapse = "\n"),
      label = label,
      products = product_rels
    ),
    class = c("prep_transform_summary", "prep_output_preview")
  )
}

#' Resolve a prep display value to a kable-ready preview when possible
#'
#' Accepts a data frame, \code{replication_result}, or
#' \code{prep_output_preview} and returns a data frame head when the backing
#' file is tabular.
#'
#' @param obj Artifact, replication result, or preview object.
#' @param n Maximum preview rows.
#' @keywords internal
resolve_prep_display_object <- function(obj, n = 6L) {
  if (inherits(obj, "error")) {
    return(obj)
  }
  if (is.list(obj) && !is.data.frame(obj) && !is.null(obj$object)) {
    obj <- replicate_fn_result_object(obj)
  }
  if (is.data.frame(obj)) {
    return(utils::head(obj, n))
  }
  if (inherits(obj, "dataverse_deposit_summary")) {
    return(obj)
  }
  if (inherits(obj, "dataverse_file_access_summary")) {
    return(obj)
  }
  if (inherits(obj, "prep_output_preview")) {
    path <- obj$path %||% NULL
    if (!is.null(path) && nzchar(path) && file.exists(path)) {
      ext <- tolower(tools::file_ext(path))
      if (ext %in% c("rds", "csv", "dta")) {
        preview <- tryCatch(preview_data_file(path, n = n), error = function(e) NULL)
        if (is.data.frame(preview)) {
          return(preview)
        }
      }
    }
    return(obj)
  }
  obj
}

#' Summarize an RDS prep output for display
#'
#' @param path Local RDS path.
#' @param obj Object read from \code{path}.
#' @keywords internal
summarize_rds_prep_output <- function(path, obj) {
  lines <- c(
    paste0("RDS output: ", basename(path)),
    paste0("Size: ", format(file.size(path), big.mark = ","), " bytes")
  )
  if (is.data.frame(obj)) {
    lines <- c(
      lines,
      paste0("Data frame: ", nrow(obj), " rows x ", ncol(obj), " columns")
    )
  } else if (is.list(obj)) {
    nms <- names(obj)
    if (length(nms)) {
      lines <- c(lines, paste0("List with ", length(nms), " named elements:"))
      preview_n <- min(12L, length(nms))
      for (nm in nms[seq_len(preview_n)]) {
        el <- obj[[nm]]
        if (is.data.frame(el)) {
          lines <- c(lines, paste0("  ", nm, ": ", nrow(el), " rows x ", ncol(el), " columns"))
        } else {
          lines <- c(
            lines,
            paste0("  ", nm, ": ", paste(class(el), collapse = "/"))
          )
        }
      }
      if (length(nms) > preview_n) {
        lines <- c(lines, paste0("  ... and ", length(nms) - preview_n, " more"))
      }
    } else {
      lines <- c(lines, paste0("List length: ", length(obj)))
    }
  } else {
    lines <- c(lines, paste0("Class: ", paste(class(obj), collapse = "/")))
  }
  structure(
    list(path = path, note = paste(lines, collapse = "\n")),
    class = "prep_output_preview"
  )
}

#' Preview a processed data file (head rows)
#'
#' @param path Local file path.
#' @param n Maximum rows to read.
#' @keywords internal
preview_data_file <- function(path, n = 6L) {
  if (!file.exists(path)) {
    stop("Processed data file not found: ", path, call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("csv")) {
    return(utils::read.csv(path, nrows = n, stringsAsFactors = FALSE))
  }
  if (ext %in% c("dta") && requireNamespace("haven", quietly = TRUE)) {
    return(haven::read_dta(path, n_max = n))
  }
  if (ext %in% c("rds")) {
    obj <- readRDS(path)
    if (is.data.frame(obj)) {
      return(utils::head(obj, n))
    }
    return(summarize_rds_prep_output(path, obj))
  }
  structure(
    list(path = path, note = "Preview not available for this file type."),
    class = "prep_output_preview"
  )
}

#' Run a single prep step
#'
#' Executes a pipeline step (Stata, R, or Python), writes \code{output} when
#' configured, and returns a preview object (typically the head of a data frame).
#'
#' @inheritParams run_replication
#' @param what Prep step id (e.g. \code{"construct_analysis_dataset"}).
#' @return A data preview, file path character vector, or replication result.
#' @keywords internal
run_prep_step <- function(
  doi,
  what,
  install_deps = FALSE,
  repo = NULL,
  folder = NULL,
  force = FALSE
) {
  doi <- prepare_doi_for_replication(doi)
  meta <- get_replication_meta(doi, repo = repo, folder = folder)
  ctx <- paper_context(doi, repo = repo, folder = folder)
  prep <- find_prep_entry(meta, what)

  if (!force && prep_output_ready(prep, ctx, meta = meta)) {
    path <- prep_output_path(prep, ctx, meta = meta)
    message("Using existing processed file: ", path)
    return(preview_data_file(path))
  }

  result <- render_replication(
    doi,
    what,
    install_deps = install_deps,
    repo = repo,
    folder = folder
  )
  invisible(replicate_fn_result_object(result))
}

#' @keywords internal
replicate_fn_result_object <- function(result) {
  if (inherits(result, "replication_result")) {
    return(result$object)
  }
  result
}

#' Parent ids for a step (`parents:` only)
#'
#' @param rep Step entry.
#' @keywords internal
replication_requires_prep <- function(rep) {
  if (!is.null(rep[["requires"]]) || !is.null(rep[["depends_on"]])) {
    stop(
      "Step '", as.character(rep$id %||% "?"),
      "' uses requires:/depends_on:; use parents: only.",
      call. = FALSE
    )
  }
  step_parent_ids(rep)
}

#' Collect upstream transform step ids required by display steps
#'
#' @param meta Parsed replication metadata.
#' @param replications List of display step entries.
#' @return Character vector of ancestor step ids in DAG order.
#' @keywords internal
collect_required_prep_ids <- function(meta, replications) {
  if (length(replications) == 0L) {
    return(character(0))
  }
  steps <- normalize_study_steps(meta)
  graph <- study_step_graph(steps)
  needed <- character(0)
  for (rep in replications) {
    tid <- as.character(rep$id %||% "")
    if (nzchar(tid) && tid %in% graph$ids) {
      needed <- union(needed, step_ancestors(tid, graph))
    }
  }
  pipeline <- steps[vapply(steps, function(x) {
    is_pipeline_step_type(x$type %||% "")
  }, logical(1))]
  pipeline_ids <- vapply(pipeline, function(x) as.character(x$id), character(1))
  ordered <- needed[needed %in% pipeline_ids]
  ordered[order(match(ordered, pipeline_ids))]
}

#' Prep / transform steps to run before building display artifacts
#'
#' When \code{display_reps} is \code{NULL}, returns every transform step.
#' Otherwise returns only ancestors required by the given display steps.
#'
#' @param meta Parsed replication metadata.
#' @param display_reps Optional list of table/figure entries being built.
#' @keywords internal
prep_steps_for_build <- function(meta, display_reps = NULL) {
  steps <- tryCatch(normalize_study_steps(meta), error = function(e) list())
  all_prep <- steps[vapply(steps, function(x) {
    is_pipeline_step_type(x$type %||% "")
  }, logical(1))]
  if (length(all_prep) == 0L) {
    return(list())
  }
  if (is.null(display_reps)) {
    return(all_prep)
  }
  required_ids <- collect_required_prep_ids(meta, display_reps)
  if (length(required_ids) == 0L) {
    return(list())
  }
  all_prep[vapply(all_prep, function(x) {
    as.character(x$id) %in% required_ids
  }, logical(1))]
}

#' Relative path for prep output in build manifests
#' @keywords internal
prep_manifest_output_path <- function(path, root = NULL) {
  if (is.null(path) || length(path) == 0L || !nzchar(as.character(path[[1]]))) {
    return(NULL)
  }
  path <- normalizePath(as.character(path[[1]]), winslash = "/", mustWork = FALSE)
  if (!is.null(root) && nzchar(root)) {
    root <- normalizePath(root, winslash = "/", mustWork = FALSE)
    prefix <- paste0(root, "/")
    if (startsWith(path, prefix)) {
      return(sub(paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root), "/?"), "", path))
    }
  }
  path
}

#' Run pipeline prep steps during artifact builds
#'
#' @param meta Parsed replication metadata.
#' @param ctx Paper context.
#' @param doi Normalized DOI.
#' @param prep_steps List of prep entries to run.
#' @param install_deps Passed to \code{render_replication()}.
#' @param force Re-run prep even when outputs already exist.
#' @param study_root Optional study or package root for portable manifest paths.
#' @return List with \code{statuses} (named list) and \code{failures}.
#' @keywords internal
run_build_prep_steps <- function(
  meta,
  ctx,
  doi,
  prep_steps,
  install_deps = FALSE,
  force = FALSE,
  study_root = NULL
) {
  statuses <- list()
  failures <- character(0)
  if (length(prep_steps) == 0L) {
    return(list(statuses = statuses, failures = failures))
  }

  for (prep in prep_steps) {
    step_id <- as.character(prep$id)
    message("Running prep step: ", step_id, " ...")
    status <- tryCatch({
      if (!force && prep_output_ready(prep, ctx, meta = meta)) {
        path <- prep_output_path(prep, ctx, meta = meta)
        list(
          status = "cached",
          output = prep_manifest_output_path(path, study_root)
        )
      } else {
        result <- render_replication(
          doi,
          step_id,
          install_deps = install_deps,
          repo = ctx$repo %||% NULL,
          folder = ctx$folder %||% NULL
        )
        path <- result$output_path %||% prep_output_path(prep, ctx, meta = meta)
        list(
          status = "ok",
          output = prep_manifest_output_path(path, study_root),
          source = result$source %||% "prep"
        )
      }
    }, error = function(e) {
      msg <- if (!is.null(study_root) && nzchar(study_root)) {
        portable_path_in_text(conditionMessage(e), study_root)
      } else {
        conditionMessage(e)
      }
      failures <<- c(failures, paste0(step_id, ": ", msg))
      list(status = "error", message = msg)
    })
    statuses[[step_id]] <- status
  }

  list(statuses = statuses, failures = failures)
}

#' Run missing upstream DAG steps before a display replication
#'
#' When a study uses the unified \code{steps:} block, display steps declare
#' \code{parents:} rather than legacy \code{requires:}. This runs any ancestor
#' transform steps whose outputs are not yet present.
#'
#' @param meta Parsed metadata.
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param doi Study DOI or handle.
#' @param install_deps Passed to step runners.
#' @param force Re-run steps even when outputs exist.
#' @param repo Optional registry repo slug.
#' @param folder Optional registry folder.
#' @keywords internal
ensure_study_ancestor_steps <- function(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE,
  repo = NULL,
  folder = NULL
) {
  steps <- normalize_study_steps(meta)
  if (length(steps) == 0L) {
    return(invisible(NULL))
  }
  target_id <- as.character(rep$id %||% "")
  if (!nzchar(target_id)) {
    return(invisible(NULL))
  }
  graph <- study_step_graph(steps)
  if (!target_id %in% graph$ids) {
    return(invisible(NULL))
  }
  ancestors <- topological_step_sort(step_ancestors(target_id, graph), graph)
  if (length(ancestors) == 0L) {
    return(invisible(NULL))
  }
  step_by_id <- setNames(steps, vapply(steps, function(x) as.character(x$id), character(1)))
  repo <- repo %||% ctx$repo %||% NULL
  folder <- folder %||% ctx$folder %||% NULL
  for (step_id in ancestors) {
    step <- step_by_id[[step_id]]
    run_ctx <- step_run_context(step, meta, ctx)
    if (!isTRUE(force) && step_outputs_ready(step, run_ctx, meta = meta)) {
      next
    }
    message("Running upstream step: ", step_id)
    render_replication_step(
      doi,
      step_id,
      meta = meta,
      ctx = ctx,
      install_deps = install_deps,
      repo = repo,
      folder = folder,
      skip_prep = TRUE,
      force = force
    )
  }
  invisible(NULL)
}

#' Ensure prep dependencies exist before running a replication
#'
#' @param meta Parsed metadata.
#' @param rep Replication entry.
#' @param ctx Paper context.
#' @param doi Study DOI or handle.
#' @param install_deps Passed to prep runners.
#' @param force Re-run prep even when outputs exist.
#' @keywords internal
ensure_prep_dependencies <- function(
  meta,
  rep,
  ctx,
  doi,
  install_deps = FALSE,
  force = FALSE
) {
  req <- replication_requires_prep(rep)
  if (length(req) == 0L) {
    return(invisible(NULL))
  }
  for (step_id in req) {
    prep <- find_prep_entry(meta, step_id)
    if (!force && prep_output_ready(prep, ctx, meta = meta)) {
      next
    }
    message("Running required prep step: ", step_id)
    render_replication(
      doi,
      step_id,
      install_deps = install_deps,
      repo = ctx$repo %||% NULL,
      folder = ctx$folder %||% NULL
    )
  }
  invisible(NULL)
}
