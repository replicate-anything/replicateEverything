#' Step types excluded from the analytical DAG display
#' @keywords internal
non_analytical_step_types <- function() {
  c("format")
}

#' Whether a step type is a display sink (table / figure)
#' @keywords internal
is_display_step_type <- function(type) {
  type <- tolower(as.character(type %||% ""))
  type %in% c("table", "figure")
}

#' Whether a step type is a pipeline / transform step
#' @keywords internal
is_pipeline_step_type <- function(type) {
  type <- tolower(as.character(type %||% ""))
  type %in% c("step", "prep", "pipeline", "transform")
}

#' Parent ids declared on a step entry (`parents:` only)
#' @keywords internal
step_parent_ids <- function(step) {
  if (!is.null(step$requires) || !is.null(step$depends_on)) {
    stop(
      "Step '", as.character(step$id %||% "?"),
      "' uses requires:/depends_on:; use parents: only.",
      call. = FALSE
    )
  }
  parents <- step$parents %||% list()
  if (length(parents) == 0L) {
    return(character(0))
  }
  vapply(parents, function(x) as.character(x), character(1))
}

#' Normalize a single step entry to a common internal shape
#' @keywords internal
normalize_step_entry <- function(step) {
  if (is.null(step$id) || !nzchar(as.character(step$id))) {
    stop("Every step must have a non-empty id.", call. = FALSE)
  }
  forbidden <- intersect(names(step), c("artifact", "output", "stata_output"))
  if (length(forbidden) > 0L) {
    stop(
      "Step '", as.character(step$id),
      "' uses ", paste0(forbidden, collapse = "/"),
      ":; use outputs: only.",
      call. = FALSE
    )
  }
  id <- as.character(step$id)
  type <- tolower(as.character(step$type %||% "step"))
  if (type %in% c("prep", "pipeline")) {
    type <- "transform"
  }
  parents <- step_parent_ids(step)
  out <- step
  out$id <- id
  out$type <- type
  out$parents <- as.list(parents)
  out
}

#' Return normalized study steps from the required `steps:` block
#'
#' @param meta Parsed replication metadata.
#' @return List of step entries.
#' @keywords internal
normalize_study_steps <- function(meta) {
  if (!is.null(meta$prep) || !is.null(meta$replications)) {
    stop(
      "replication.yml must use a unified steps: DAG. ",
      "Legacy prep: / replications: blocks are not supported.",
      call. = FALSE
    )
  }
  raw <- meta$steps %||% NULL
  if (is.null(raw) || length(raw) == 0L) {
    stop(
      "replication.yml must declare a non-empty steps: block.",
      call. = FALSE
    )
  }
  lapply(raw, normalize_step_entry)
}

#' Collect runnable step entries (excludes format children from flat list)
#' @keywords internal
collect_study_step_entries <- function(meta) {
  steps <- normalize_study_steps(meta)
  steps[vapply(steps, function(x) {
    !identical(as.character(x$type), "format")
  }, logical(1))]
}

#' Format child step for an analytical step id, if any
#' @keywords internal
format_child_step <- function(meta, step_id) {
  steps <- normalize_study_steps(meta)
  fmt_id <- paste0(step_id, "_format")
  matches <- steps[vapply(steps, function(x) {
    identical(as.character(x$id), fmt_id) ||
      (identical(as.character(x$type), "format") &&
        identical(as.character(x$parent %||% ""), step_id))
  }, logical(1))]
  if (length(matches) == 0L) {
    return(NULL)
  }
  matches[[1]]
}

#' Relative input paths declared for a step
#' @keywords internal
step_declared_input_paths <- function(step) {
  collect <- character(0)
  for (field in c("inputs", "data")) {
    val <- step[[field]] %||% NULL
    if (is.null(val) || length(val) == 0L) {
      next
    }
    if (is.character(val)) {
      collect <- c(collect, val)
    } else {
      collect <- c(collect, vapply(val, function(x) as.character(x), character(1)))
    }
  }
  unique(collect[nzchar(collect)])
}

#' Normalize a repo-relative path for comparisons
#' @keywords internal
normalize_repo_rel_path <- function(path) {
  path <- gsub("\\\\", "/", trimws(as.character(path)))
  sub("/+$", "", path)
}

#' Whether a path is raw study data (under \code{data/}, not a step output)
#' @keywords internal
is_root_data_path <- function(path, produced_outputs = character(0)) {
  path <- normalize_repo_rel_path(path)
  if (!nzchar(path)) {
    return(FALSE)
  }
  produced <- unique(normalize_repo_rel_path(produced_outputs))
  if (path %in% produced) {
    return(FALSE)
  }
  if (any(vapply(produced, function(out) {
    nzchar(out) && (path == out || startsWith(path, paste0(out, "/")))
  }, logical(1)))) {
    return(FALSE)
  }
  startsWith(path, "data/") || path == "data"
}

#' All output paths declared across steps
#' @keywords internal
study_produced_output_paths <- function(steps) {
  unique(unlist(lapply(steps, step_declared_output_paths), use.names = FALSE))
}

#' Raw \code{data/} inputs for a step (excludes outputs from upstream steps)
#' @keywords internal
step_root_data_inputs <- function(step, produced_outputs = character(0)) {
  ins <- step_declared_input_paths(step)
  ins[vapply(ins, is_root_data_path, produced_outputs = produced_outputs, FUN.VALUE = logical(1))]
}

#' Display label for one or more raw data paths
#' @keywords internal
format_data_roots_label <- function(paths) {
  paths <- paths[nzchar(paths)]
  if (length(paths) == 0L) {
    return("")
  }
  bases <- basename(paths)
  if (length(bases) == 1L) {
    return(bases[[1]])
  }
  paste0("(", paste(bases, collapse = ", "), ")")
}

#' Virtual DAG node for raw data roots feeding a step
#' @keywords internal
dag_data_roots_node <- function(paths) {
  paths <- unique(normalize_repo_rel_path(paths))
  paths <- paths[nzchar(paths)]
  list(
    id = paste0("__data__:", paste(paths, collapse = "|")),
    label = format_data_roots_label(paths),
    description = paste(paths, collapse = "\n"),
    type = "data",
    kind = "data"
  )
}

#' Collect non-format step entries for indexes and Shiny lists
#' @param meta Parsed replication metadata.
#' @keywords internal
study_step_entries <- function(meta) {
  collect_study_step_entries(meta)
}

#' Relative output paths declared for a step (`outputs:` only)
#' @keywords internal
step_declared_output_paths <- function(step) {
  outs <- step$outputs %||% NULL
  if (!is.null(outs) && length(outs) > 0L) {
    return(vapply(outs, function(x) as.character(x), character(1)))
  }
  id <- as.character(step$id)
  type <- tolower(as.character(step$type %||% ""))
  if (type %in% c("step", "prep", "pipeline", "transform")) {
    return(c(
      paste0("outputs/", id, ".rds"),
      paste0("outputs/", id, ".dta"),
      paste0("outputs/", id, ".csv")
    ))
  }
  c(
    paste0("outputs/", id, ".html"),
    paste0("outputs/", id, ".png")
  )
}

#' Primary declared output paths for readiness checks (files and dirs)
#' @keywords internal
step_primary_declared_output_rels <- function(step) {
  step_declared_output_paths(step)
}

#' Repo-relative path variants for one declared output (outputs-only)
#' @keywords internal
step_output_rel_variants <- function(rel, step_id = "") {
  rel <- normalize_repo_rel_path(rel)
  if (!nzchar(rel)) {
    return(character(0))
  }
  rel
}

#' All repo-relative output paths to probe for a step
#' @keywords internal
step_output_rel_candidates <- function(step) {
  step_primary_declared_output_rels(step)
}

#' Resolve one declared output to a ready local path, if any
#' @keywords internal
resolve_step_output_path <- function(rel, step, ctx, meta = NULL) {
  p <- resolve_study_file(rel, ctx, meta = meta, local_only = TRUE, step = step)
  if (output_path_ready(p)) {
    return(p)
  }
  NULL
}

#' Resolve declared output paths to local files
#' @keywords internal
step_resolved_output_paths <- function(step, ctx, meta = NULL) {
  rels <- step_output_rel_candidates(step)
  paths <- vapply(rels, function(rel) {
    resolve_study_file(rel, ctx, meta = meta, local_only = TRUE, step = step)
  }, character(1))
  unique(paths[nzchar(paths)])
}

#' Whether a path exists and is non-empty (directory must contain files)
#' @keywords internal
output_path_ready <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(FALSE)
  }
  if (dir.exists(path)) {
    contents <- list.files(path, all.files = FALSE, no.. = TRUE)
    return(length(contents) > 0L)
  }
  TRUE
}

#' Whether all declared outputs for a step exist locally
#' @keywords internal
step_outputs_ready <- function(step, ctx, meta = NULL) {
  rels <- step_primary_declared_output_rels(step)
  file_rels <- rels[grepl("\\.[^/]+$", rels)]
  dir_rels <- rels[grepl("/$", rels) & !grepl("\\.[^/]+$", rels)]
  if (length(file_rels) == 0L && length(dir_rels) == 0L) {
    file_rels <- rels
  }
  if (length(file_rels) > 0L) {
    ready <- vapply(file_rels, function(rel) {
      !is.null(resolve_step_output_path(rel, step, ctx, meta = meta))
    }, logical(1))
    if (!all(ready)) {
      return(FALSE)
    }
  }
  if (length(dir_rels) == 0L) {
    return(length(file_rels) > 0L)
  }
  all(vapply(dir_rels, function(rel) {
    p <- resolve_study_file(rel, ctx, meta = meta, local_only = TRUE, step = step)
    output_path_ready(p)
  }, logical(1)))
}

#' Primary output path for a step (first ready or first declared)
#' @keywords internal
step_primary_output_path <- function(step, ctx, meta = NULL) {
  rels <- step_primary_declared_output_rels(step)
  for (rel in rels) {
    p <- resolve_step_output_path(rel, step, ctx, meta = meta)
    if (!is.null(p)) {
      return(p)
    }
  }
  if (length(rels) > 0L) {
    return(resolve_study_file(rels[[1]], ctx, meta = meta, local_only = TRUE, step = step))
  }
  NULL
}
