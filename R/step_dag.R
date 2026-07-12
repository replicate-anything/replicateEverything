#' Build a step DAG index from normalized steps
#' @keywords internal
study_step_graph <- function(steps) {
  ids <- vapply(steps, function(x) as.character(x$id), character(1))
  if (anyDuplicated(ids)) {
    stop("Duplicate step ids in study DAG.", call. = FALSE)
  }
  parents <- setNames(
    lapply(steps, function(x) {
      if (identical(as.character(x$type), "format")) {
        p <- as.character(x$parent %||% "")
        if (nzchar(p)) return(p) else return(character(0))
      }
      step_parent_ids(x)
    }),
    ids
  )
  types <- setNames(
    vapply(steps, function(x) as.character(x$type), character(1)),
    ids
  )
  labels <- setNames(
    vapply(steps, function(x) {
      lab <- as.character(x$label %||% x$id)
      if (nzchar(lab)) lab else as.character(x$id)
    }, character(1)),
    ids
  )
  descriptions <- setNames(
    vapply(steps, function(x) as.character(x$description %||% ""), character(1)),
    ids
  )
  format_children <- setNames(
    vapply(steps, function(x) {
      if (!identical(as.character(x$type), "format")) {
        return("")
      }
      as.character(x$parent %||% "")
    }, character(1)),
    ids
  )
  format_children <- format_children[nzchar(format_children)]
  list(
    steps = steps,
    ids = ids,
    parents = parents,
    types = types,
    labels = labels,
    descriptions = descriptions,
    format_children = format_children
  )
}

#' Validate a study step DAG
#' @keywords internal
validate_study_step_graph <- function(graph) {
  ids <- graph$ids
  errors <- character(0)
  for (id in ids) {
    for (p in graph$parents[[id]]) {
      if (!p %in% ids) {
        errors <- c(errors, paste0("Step '", id, "' references unknown parent '", p, "'."))
      }
    }
    if (identical(graph$types[[id]], "format")) {
      parent <- graph$format_children[[id]] %||% graph$parents[[id]][[1]]
      if (is.null(parent) || !nzchar(parent)) {
        errors <- c(errors, paste0("Format step '", id, "' must declare parent."))
      } else if (!parent %in% ids) {
        errors <- c(errors, paste0("Format step '", id, "' parent '", parent, "' not found."))
      }
    }
  }
  tryCatch({
    for (id in ids) {
      step_ancestors(id, graph)
    }
  }, error = function(e) {
    errors <<- c(errors, conditionMessage(e))
  })
  if (length(errors) > 0L) {
    stop(paste(errors, collapse = "\n"), call. = FALSE)
  }
  invisible(graph)
}

#' Ancestors of a step (transitive parents, excluding format nodes as parents)
#' @keywords internal
step_ancestors <- function(step_id, graph) {
  visited <- character(0)
  queue <- graph$parents[[step_id]] %||% character(0)
  out <- character(0)
  while (length(queue) > 0L) {
    node <- queue[[1L]]
    queue <- queue[-1L]
    if (node %in% out) {
      next
    }
    if (node %in% visited) {
      stop("Cycle detected in step DAG at '", node, "'.", call. = FALSE)
    }
    visited <- c(visited, node)
    if (identical(graph$types[[node]], "format")) {
      next
    }
    out <- c(out, node)
    queue <- unique(c(graph$parents[[node]] %||% character(0), queue))
  }
  out
}

#' Direct analytical parents (excludes format)
#' @keywords internal
step_direct_parents <- function(step_id, graph) {
  graph$parents[[step_id]] %||% character(0)
}

#' Normalize the given argument
#' @keywords internal
normalize_given_argument <- function(given) {
  if (is.null(given) || length(given) == 0L) {
    return("parents")
  }
  if (length(given) == 1L && is.character(given)) {
    g <- tolower(trimws(given))
    if (g %in% c("parents", "nothing")) {
      return(g)
    }
  }
  if (is.character(given)) {
    return(unique(trimws(given[nzchar(trimws(given))])))
  }
  stop("given must be 'parents', 'nothing', or a character vector of step ids.", call. = FALSE)
}

#' Expand given to a set of step ids assumed complete
#' @keywords internal
resolve_given_set <- function(given, target_id, graph) {
  given <- normalize_given_argument(given)
  if (identical(given, "parents")) {
    return(step_direct_parents(target_id, graph))
  }
  if (identical(given, "nothing")) {
    return(character(0))
  }
  unique(given)
}

#' Validate given is downward-closed (includes all ancestors of each given step)
#' @keywords internal
validate_given_downward_closure <- function(given_ids, graph) {
  if (length(given_ids) == 0L) {
    return(invisible(NULL))
  }
  for (g in given_ids) {
    if (!g %in% graph$ids) {
      stop("given step '", g, "' is not in the study DAG.", call. = FALSE)
    }
    missing <- setdiff(step_ancestors(g, graph), given_ids)
    if (length(missing) > 0L) {
      stop(
        "Invalid given set: step '", g, "' assumes outputs exist, but ancestor(s) ",
        paste(missing, collapse = ", "),
        " are not included in given. ",
        "Every given step must include all of its parents.",
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' Topological sort of a step id set respecting parent edges
#' @keywords internal
topological_step_sort <- function(step_ids, graph) {
  step_ids <- unique(step_ids)
  ordered <- character(0)
  remaining <- step_ids
  while (length(remaining) > 0L) {
    ready <- remaining[vapply(remaining, function(id) {
      parents <- step_ancestors(id, graph)
      all(parents %in% ordered | !parents %in% step_ids)
    }, logical(1))]
    if (length(ready) == 0L) {
      stop("Cannot sort steps (cycle or missing parent).", call. = FALSE)
    }
    ready <- sort(ready)
    ordered <- c(ordered, ready)
    remaining <- setdiff(remaining, ready)
  }
  ordered
}

#' Plan which steps to execute
#' @keywords internal
plan_study_run <- function(target_id, given, format, graph) {
  if (length(graph$ids) == 0L) {
    stop(
      "Study has no steps in metadata (registry stub only?). ",
      "Point R at the monorepo study folder, e.g.\n",
      "  replicateEverything::configure_local_monorepo()\n",
      "or run from the study repo path.",
      call. = FALSE
    )
  }
  if (!target_id %in% graph$ids) {
    stop(
      "Step '", target_id, "' not found in study DAG. ",
      "Available: ", paste(graph$ids, collapse = ", "),
      call. = FALSE
    )
  }
  if (identical(graph$types[[target_id]], "format")) {
    stop("Use the parent step id; format runs via format = TRUE.", call. = FALSE)
  }

  given_ids <- resolve_given_set(given, target_id, graph)
  if (!identical(normalize_given_argument(given), "parents")) {
    validate_given_downward_closure(given_ids, graph)
  }

  ancestors <- step_ancestors(target_id, graph)
  to_run <- setdiff(ancestors, given_ids)
  to_run <- topological_step_sort(to_run, graph)
  to_run <- c(to_run, target_id)

  include_format <- isTRUE(format) || identical(format, "if_available")
  fmt_id <- format_child_for_step(target_id, graph)

  list(
    target_id = target_id,
    given_ids = given_ids,
    step_ids = unique(to_run),
    format_step_id = if (include_format) fmt_id else NULL
  )
}

#' Format child id for a step, if registered
#' @keywords internal
format_child_for_step <- function(step_id, graph) {
  matches <- names(graph$format_children)[graph$format_children == step_id]
  if (length(matches) == 0L) {
    fmt_id <- paste0(step_id, "_format")
    if (fmt_id %in% graph$ids) {
      return(fmt_id)
    }
    return(NULL)
  }
  matches[[1]]
}

#' Check that immediate parents have outputs (given = parents semantics)
#' @keywords internal
assert_parents_ready <- function(target_id, graph, ctx, meta, force = FALSE) {
  if (isTRUE(force)) {
    return(invisible(NULL))
  }
  parents <- step_direct_parents(target_id, graph)
  if (length(parents) == 0L) {
    return(invisible(NULL))
  }
  step_by_id <- setNames(graph$steps, graph$ids)
  missing <- character(0)
  for (p in parents) {
    parent_step <- step_by_id[[p]]
    if (is.null(parent_step)) {
      next
    }
    if (!step_outputs_ready(parent_step, step_run_context(parent_step, meta, ctx), meta = meta)) {
      missing <- c(missing, p)
    }
  }
  if (length(missing) > 0L) {
    stop(
      "Parent step output(s) missing for '", target_id, "': ",
      paste(missing, collapse = ", "),
      ". Run upstream step(s) first, use given = \"nothing\", ",
      "or set force = TRUE to re-run.",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Check that all steps in given set have outputs ready
#' @keywords internal
assert_given_outputs_ready <- function(given_ids, graph, ctx, meta, force = FALSE) {
  if (isTRUE(force) || length(given_ids) == 0L) {
    return(invisible(NULL))
  }
  step_by_id <- setNames(graph$steps, graph$ids)
  missing <- character(0)
  for (g in given_ids) {
    step <- step_by_id[[g]]
    if (is.null(step)) {
      next
    }
    if (!step_outputs_ready(step, step_run_context(step, meta, ctx), meta = meta)) {
      missing <- c(missing, g)
    }
  }
  if (length(missing) > 0L) {
    stop(
      "given step output(s) missing: ",
      paste(missing, collapse = ", "),
      ". Run upstream steps or use given = \"nothing\".",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Weakly connected components of analytical steps for display
#' @keywords internal
study_dag_components <- function(graph) {
  analytical <- graph$ids[!graph$types %in% non_analytical_step_types()]
  if (length(analytical) == 0L) {
    return(list())
  }
  adj <- setNames(vector("list", length(analytical)), analytical)
  for (id in analytical) {
    parents <- graph$parents[[id]]
    parents <- parents[parents %in% analytical]
    adj[[id]] <- parents
  }
  visited <- character(0)
  components <- list()
  for (start in analytical) {
    if (start %in% visited) {
      next
    }
    queue <- start
    comp <- character(0)
    while (length(queue) > 0L) {
      node <- queue[[1L]]
      queue <- queue[-1L]
      if (node %in% comp) {
        next
      }
      comp <- c(comp, node)
      children <- analytical[vapply(analytical, function(x) {
        node %in% (graph$parents[[x]] %||% character(0))
      }, logical(1))]
      queue <- unique(c(queue, graph$parents[[node]] %||% character(0), children))
    }
    comp <- comp[comp %in% analytical]
    visited <- unique(c(visited, comp))
    components[[length(components) + 1L]] <- comp
  }
  components
}

#' Root-to-sink paths within a DAG component (parallel branches, not one linear chain)
#' @keywords internal
study_dag_paths <- function(comp, graph) {
  if (length(comp) == 0L) {
    return(list())
  }
  children <- setNames(vector("list", length(comp)), comp)
  for (id in comp) {
    for (p in graph$parents[[id]] %||% character(0)) {
      if (p %in% comp) {
        children[[p]] <- c(children[[p]], id)
      }
    }
  }
  for (id in comp) {
    children[[id]] <- unique(children[[id]])
  }
  roots <- comp[vapply(comp, function(id) {
    parents <- graph$parents[[id]] %||% character(0)
    length(parents[parents %in% comp]) == 0L
  }, logical(1))]
  sinks <- comp[vapply(comp, function(id) {
    length(children[[id]]) == 0L
  }, logical(1))]
  paths <- list()
  walk <- function(node, current) {
    current <- c(current, node)
    kids <- children[[node]]
    if (length(kids) == 0L || node %in% sinks) {
      paths <<- c(paths, list(current))
      return(invisible(NULL))
    }
    for (child in sort(kids)) {
      walk(child, current)
    }
    invisible(NULL)
  }
  for (root in sort(roots)) {
    walk(root, character(0))
  }
  paths
}

#' Build display node records for one path (optional leading raw-data node)
#' @keywords internal
dag_path_node_records <- function(path_ids, graph, steps, produced_outputs) {
  if (length(path_ids) == 0L) {
    return(list())
  }
  step_by_id <- setNames(steps, vapply(steps, function(x) as.character(x$id), character(1)))
  first_step <- step_by_id[[path_ids[[1]]]]
  out <- list()
  if (!is.null(first_step)) {
    data_roots <- step_root_data_inputs(first_step, produced_outputs)
    if (length(data_roots) > 0L) {
      out[[length(out) + 1L]] <- dag_data_roots_node(data_roots)
    }
  }
  for (id in path_ids) {
    out[[length(out) + 1L]] <- list(
      id = id,
      label = graph$labels[[id]],
      description = graph$descriptions[[id]],
      type = graph$types[[id]],
      kind = "step"
    )
  }
  out
}

#' Format one component as edge-respecting path strings
#' @keywords internal
format_dag_component_paths <- function(comp, graph, steps = graph$steps) {
  paths <- study_dag_paths(comp, graph)
  if (length(paths) == 0L) {
    return(character(0))
  }
  produced <- study_produced_output_paths(steps)
  vapply(paths, function(path_ids) {
    nodes <- dag_path_node_records(path_ids, graph, steps, produced)
    labels <- vapply(nodes, function(n) as.character(n$label), character(1))
    paste(labels, collapse = " \u2192 ")
  }, character(1))
}

#' Step display data for Shiny (components of paths of id / label / description)
#' @param meta Parsed replication metadata.
#' @return A list of components; each component is a list of paths; each path is a
#'   list of step display records.
#' @export
study_dag_display <- function(meta) {
  steps <- normalize_study_steps(meta)
  if (length(steps) == 0L) {
    return(list())
  }
  graph <- study_step_graph(steps)
  validate_study_step_graph(graph)
  components <- study_dag_components(graph)
  produced <- study_produced_output_paths(steps)
  lapply(components, function(comp) {
    paths <- study_dag_paths(comp, graph)
    lapply(paths, function(path_ids) {
      dag_path_node_records(path_ids, graph, steps, produced)
    })
  })
}

#' Last step node on a display path
#' @keywords internal
path_sink_step <- function(path) {
  step_nodes <- path[vapply(path, function(n) identical(n$kind %||% "", "step"), logical(1))]
  if (length(step_nodes) == 0L) {
    return(NULL)
  }
  step_nodes[[length(step_nodes)]]
}

#' Faceted pipeline groups for Shiny (split multi-branch components)
#' @param meta Parsed replication metadata.
#' @return List of facets, each with \code{title} and \code{paths}.
#' @export
study_dag_facets <- function(meta) {
  components <- study_dag_display(meta)
  facets <- list()
  for (comp in components) {
    if (length(comp) == 0L) {
      next
    }
    if (length(comp) == 1L) {
      sink <- path_sink_step(comp[[1]])
      title <- if (is.null(sink)) "Pipeline" else as.character(sink$label)
      facets[[length(facets) + 1L]] <- list(title = title, paths = comp)
      next
    }
    by_sink <- list()
    for (path in comp) {
      sink <- path_sink_step(path)
      key <- if (is.null(sink)) "other" else as.character(sink$id)
      by_sink[[key]] <- c(by_sink[[key]] %||% list(), list(path))
    }
    table_paths <- list()
    rest <- list()
    for (key in names(by_sink)) {
      paths <- by_sink[[key]]
      sink <- path_sink_step(paths[[1]])
      if (!is.null(sink) && identical(as.character(sink$type), "table")) {
        table_paths <- c(table_paths, paths)
      } else {
        title <- if (is.null(sink)) "Pipeline" else as.character(sink$label)
        rest[[title]] <- paths
      }
    }
    if (length(table_paths) > 0L) {
      facets[[length(facets) + 1L]] <- list(title = "Tables", paths = table_paths)
    }
    for (title in names(rest)) {
      facets[[length(facets) + 1L]] <- list(title = title, paths = rest[[title]])
    }
  }
  facets
}

#' Pipeline paths leading to one step (for Shiny Pipeline tab)
#' @param meta Parsed replication metadata.
#' @param step_id Step or replication group id (e.g. \code{"tab_1"}).
#' @return List of paths; each path is a list of display node records.
#' @export
study_dag_for_step <- function(meta, step_id) {
  step_id <- trimws(as.character(step_id %||% ""))
  if (!nzchar(step_id)) {
    return(list())
  }
  steps <- normalize_study_steps(meta)
  if (length(steps) == 0L) {
    return(list())
  }
  graph <- study_step_graph(steps)
  produced <- study_produced_output_paths(steps)
  match_ids <- graph$ids[graph$ids == step_id | graph$labels == step_id]
  if (length(match_ids) == 0L) {
    match_ids <- step_id
  }
  target_id <- match_ids[[1]]
  components <- study_dag_components(graph)
  comp <- NULL
  for (candidate in components) {
    if (target_id %in% candidate) {
      comp <- candidate
      break
    }
  }
  if (is.null(comp)) {
    return(list())
  }
  paths <- study_dag_paths(comp, graph)
  out <- list()
  for (path_ids in paths) {
    if (target_id %in% path_ids) {
      out[[length(out) + 1L]] <- dag_path_node_records(path_ids, graph, steps, produced)
    }
  }
  out
}

#' Text representation of the study DAG for Shiny / CLI
#' @param meta Parsed replication metadata.
#' @return Character vector of component strings.
#' @export
describe_study_dag <- function(meta) {
  steps <- normalize_study_steps(meta)
  graph <- study_step_graph(steps)
  validate_study_step_graph(graph)
  components <- study_dag_components(graph)
  if (length(components) == 0L) {
    return(character(0))
  }
  vapply(components, function(comp) {
    path_strs <- format_dag_component_paths(comp, graph, steps = steps)
    paste0("{", paste(path_strs, collapse = "; "), "}")
  }, character(1))
}

#' Step labels and descriptions keyed by id (for Shiny hover)
#' @keywords internal
study_step_labels <- function(meta) {
  steps <- normalize_study_steps(meta)
  graph <- study_step_graph(steps)
  list(
    labels = graph$labels,
    descriptions = graph$descriptions,
    types = graph$types
  )
}

#' Migrate legacy prep/replications yaml to a unified steps block (character yaml)
#' @param meta Parsed replication metadata or path to replication.yml.
#' @return Character scalar containing a \code{steps:} yaml block.
#' @export
migrate_legacy_steps_yaml <- function(meta) {
  if (is.character(meta) && length(meta) == 1L && file.exists(meta)) {
    meta <- yaml::read_yaml(meta)
  }
  steps <- compile_steps_from_legacy(meta)
  if (length(steps) == 0L) {
    return("steps: []\n")
  }
  yaml::as_yaml(list(steps = steps), line_sep = "\n")
}
