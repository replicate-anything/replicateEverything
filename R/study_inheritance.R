#' Study extension / step inheritance helpers
#'
#' Extension studies declare \code{paper.extends} and reference upstream steps
#' with \code{inherit:}. Inherited steps execute in the base study repository;
#' extension steps run locally and may read base \code{outputs/}.
#'
#' @name study_inheritance
#' @keywords internal
NULL

#' Whether merged metadata includes a base study extension
#' @keywords internal
study_has_extension <- function(meta) {
  !is.null(meta$.extends_context)
}

#' Parse an inherit reference (\code{repo/step} or \code{step})
#' @keywords internal
parse_inherit_reference <- function(ref, default_repo = NULL) {
  ref <- trimws(as.character(ref))
  if (!nzchar(ref)) {
    stop("inherit: must be a non-empty step id or repo/step reference.", call. = FALSE)
  }
  if (grepl("/", ref, fixed = TRUE)) {
    parts <- strsplit(ref, "/", fixed = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) < 2L) {
      stop("Invalid inherit reference: ", ref, call. = FALSE)
    }
    return(list(repo = parts[[1]], step_id = parts[[2]]))
  }
  list(repo = default_repo, step_id = ref)
}

#' Repo folder name from a GitHub slug
#' @keywords internal
study_repo_folder_name <- function(repo_slug) {
  repo_slug <- as.character(repo_slug)
  repo_slug <- sub("^https?://github.com/", "", repo_slug, ignore.case = TRUE)
  repo_slug <- sub("^replicate-anything/", "", repo_slug, ignore.case = TRUE)
  basename(repo_slug)
}

#' Resolve a local checkout for a study repo slug
#' @keywords internal
resolve_study_repo_local_root <- function(repo_slug) {
  folder <- study_repo_folder_name(repo_slug)
  if (!nzchar(folder)) {
    return(NULL)
  }
  roots <- unique(c(
    getOption("replicateEverything.study_folders_root", NULL),
    sibling_monorepo_root(),
    Sys.getenv("REPLICATE_MONOREPO_ROOT", unset = "")
  ))
  roots <- roots[nzchar(roots) & dir.exists(roots)]
  for (monorepo in roots) {
    candidate <- file.path(monorepo, folder)
    if (dir.exists(candidate) && file.exists(file.path(candidate, "replication.yml"))) {
      return(normalizePath(candidate, winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

#' Load base study replication.yml for an extension
#' @keywords internal
load_extended_base_meta <- function(extends) {
  repo <- as.character(extends$repo[[1]] %||% extends$repo)
  ref <- as.character(extends$ref[[1]] %||% extends$ref %||% "main")
  local_root <- resolve_study_repo_local_root(repo)
  if (!is.null(local_root)) {
    yml <- file.path(local_root, "replication.yml")
    if (file.exists(yml)) {
      meta <- yaml::read_yaml(yml)
      meta$.local_root <- local_root
      return(meta)
    }
  }
  for (url in folder_study_yaml_urls(repo, ref)) {
    parsed <- read_yaml_url(url)
    if (!is.null(parsed)) {
      parsed$.local_root <- resolve_study_repo_local_root(repo)
      return(parsed)
    }
  }
  stop(
    "Could not load base study for extends.repo = ", repo,
    call. = FALSE
  )
}

#' Build paper context for the base study of an extension
#' @keywords internal
extended_base_paper_context <- function(extends, base_meta = NULL) {
  doi <- extends$doi %||% base_meta$paper$doi %||% NULL
  if (!is.null(doi) && nzchar(as.character(doi[[1]] %||% doi))) {
    ctx <- paper_context(normalize_doi(doi))
    if (is.null(ctx$local_root) || !dir.exists(ctx$local_root)) {
      local_root <- base_meta$.local_root %||% resolve_study_repo_local_root(extends$repo)
      if (!is.null(local_root)) {
        ctx$local_root <- local_root
      }
    }
    ctx$materials_repo <- as.character(extends$repo[[1]] %||% extends$repo)
    return(ctx)
  }
  local_root <- base_meta$.local_root %||% resolve_study_repo_local_root(extends$repo)
  list(
    doi = NA_character_,
    repo = DEFAULT_REGISTRY_REPO,
    folder = study_repo_folder_name(extends$repo),
    base_url = registry_url(
      paste0("https://raw.githubusercontent.com/", extends$repo),
      paste0(ref <- as.character(extends$ref[[1]] %||% extends$ref %||% "main"), "/")
    ),
    local_root = local_root,
    registry_stub_path = NULL,
    registry_local_root = NULL,
    materials_repo = as.character(extends$repo[[1]] %||% extends$repo),
    is_folder_study = TRUE,
    is_package_study = FALSE
  )
}

#' Mark a step as inherited from a base study
#' @keywords internal
tag_inherited_step <- function(step, base_repo, base_step_id) {
  step$.inherited <- TRUE
  step$.base_repo <- base_repo
  step$.base_step_id <- base_step_id
  step
}

#' Whether a step runs in the base study repository
#' @keywords internal
is_inherited_step <- function(step) {
  isTRUE(step$.inherited)
}

#' Expand inherit entries and merge with base steps
#' @keywords internal
merge_extended_study_steps <- function(extension_meta, base_meta, extends) {
  default_repo <- study_repo_folder_name(extends$repo)
  base_steps <- normalize_study_steps(base_meta)
  base_by_id <- setNames(base_steps, vapply(base_steps, function(x) x$id, character(1)))

  ext_raw <- extension_meta$steps %||% list()
  if (length(ext_raw) == 0L && length(base_steps) == 0L) {
    return(list())
  }

  merged <- list()
  for (entry in ext_raw) {
    if (!is.null(entry$inherit)) {
      ref <- parse_inherit_reference(entry$inherit, default_repo = default_repo)
      base_step <- base_by_id[[ref$step_id]]
      if (is.null(base_step)) {
        stop(
          "Inherited step '", ref$step_id, "' not found in base study ",
          extends$repo, ".",
          call. = FALSE
        )
      }
      step <- base_step
      if (!is.null(entry$id) && nzchar(as.character(entry$id))) {
        if (!identical(as.character(entry$id), ref$step_id)) {
          stop(
            "inherit: step id mismatch (inherit references '", ref$step_id,
            "' but entry id is '", entry$id, "').",
            call. = FALSE
          )
        }
      }
      for (field in c("label", "description", "parents", "code", "format", "parent")) {
        val <- entry[[field]] %||% NULL
        if (!is.null(val) && length(val) > 0L) {
          step[[field]] <- val
        }
      }
      step <- tag_inherited_step(step, ref$repo, ref$step_id)
      merged[[step$id]] <- normalize_step_entry(step)
      next
    }
    if (is.null(entry$id)) {
      stop("Extension steps must have id (or inherit:).", call. = FALSE)
    }
    step <- normalize_step_entry(entry)
    if (isTRUE(step$.inherited)) {
      next
    }
    if (identical(as.character(step$id), "") || is.null(step$id)) {
      stop("Extension steps must have id.", call. = FALSE)
    }
    merged[[step$id]] <- step
  }

  unname(merged)
}

#' Merge extension metadata with its base study
#' @keywords internal
merge_extended_study_meta <- function(meta, ctx = NULL) {
  extends <- meta$paper$extends %||% meta$extends %||% NULL
  if (is.null(extends) || length(extends) == 0L) {
    return(meta)
  }
  if (is.null(extends$repo) || !nzchar(as.character(extends$repo[[1]] %||% extends$repo))) {
    stop("paper.extends.repo is required for extension studies.", call. = FALSE)
  }

  base_meta <- load_extended_base_meta(extends)
  base_ctx <- extended_base_paper_context(extends, base_meta)
  steps <- merge_extended_study_steps(meta, base_meta, extends)

  meta$steps <- steps

  for (field in c(
    "languages",
    "python_dependencies",
    "stata_deps_probe",
    "stata_dependencies",
    "stata_packages"
  )) {
    val <- meta[[field]] %||% NULL
    if (is.null(val) || length(val) == 0L) {
      base_val <- base_meta[[field]] %||% NULL
      if (!is.null(base_val) && length(base_val) > 0L) {
        meta[[field]] <- base_val
      }
    }
  }

  meta$.extends <- extends
  meta$.extends_context <- list(
    repo = as.character(extends$repo[[1]] %||% extends$repo),
    ref = as.character(extends$ref[[1]] %||% extends$ref %||% "main"),
    doi = if (!is.null(extends$doi)) normalize_doi(extends$doi) else NA_character_,
    local_root = base_ctx$local_root,
    base_url = base_ctx$base_url,
    materials_repo = base_ctx$materials_repo,
    folder = base_ctx$folder
  )
  meta
}

#' Local root of the base study for an extension, if any
#' @keywords internal
extended_study_base_root <- function(meta) {
  ctx <- meta$.extends_context %||% NULL
  if (is.null(ctx)) {
    return(NULL)
  }
  root <- ctx$local_root %||% NULL
  if (!is.null(root) && nzchar(root) && dir.exists(root)) {
    return(root)
  }
  resolve_study_repo_local_root(ctx$repo)
}

#' Paper context to use when running or checking a step
#' @keywords internal
step_run_context <- function(step, meta, ctx) {
  if (is_inherited_step(step)) {
    base <- meta$.extends_context %||% list()
    base_root <- base$local_root %||% extended_study_base_root(meta)
    if (!is.null(base_root) && nzchar(base_root)) {
      ctx <- modifyList(ctx, list(
        local_root = base_root,
        base_url = base$base_url %||% ctx$base_url,
        materials_repo = base$materials_repo %||% ctx$materials_repo,
        is_folder_study = TRUE
      ))
    }
  }
  ctx
}

#' Study repository root for executing one step
#'
#' Inherited steps run in the base repo unless their \code{code} path exists
#' only in the extension study (e.g. overridden \code{tab_1_format}).
#' @keywords internal
step_study_root <- function(step, meta, ctx) {
  run_ctx <- step_run_context(step, meta, ctx)
  root <- run_ctx$local_root
  if (!is.null(root) && nzchar(root) && dir.exists(root)) {
    return(normalizePath(root, winslash = "/", mustWork = FALSE))
  }
  ensure_study_folder_local(meta, run_ctx)
}

#' Context for sourcing step code (extension-local overrides on inherited steps)
#' @keywords internal
step_code_context <- function(step, meta, ctx) {
  if (!is_inherited_step(step)) {
    return(ctx)
  }
  code_rel <- as.character(step$code[[1]] %||% step$code %||% "")
  if (!nzchar(code_rel)) {
    return(step_run_context(step, meta, ctx))
  }
  ext_root <- ctx$local_root
  if (!is.null(ext_root) && file.exists(file.path(ext_root, code_rel))) {
    return(ctx)
  }
  step_run_context(step, meta, ctx)
}

#' Resolve a repo-relative path, including base-study outputs for extensions
#' @keywords internal
resolve_study_file <- function(path, ctx, meta = NULL, local_only = FALSE, step = NULL) {
  if (!is.null(step)) {
    ctx <- step_run_context(step, meta, ctx)
  }
  hit <- resolve_registry_file(path, ctx, meta = meta, local_only = TRUE)
  if (!is.null(hit) && file.exists(hit)) {
    return(hit)
  }
  base_root <- extended_study_base_root(meta)
  if (!is.null(base_root) && !identical(base_root, ctx$local_root)) {
    base_path <- file.path(base_root, path)
    if (file.exists(base_path)) {
      return(base_path)
    }
    if (isTRUE(local_only)) {
      return(base_path)
    }
  }
  if (isTRUE(local_only)) {
    return(hit)
  }
  resolve_registry_file(path, ctx, meta = meta, local_only = FALSE)
}
