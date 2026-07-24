#' GitHub zip download URL for a study repository
#' @param repo_slug Character scalar \code{org/repo}.
#' @param ref Branch or tag name (default \code{main}).
#' @return Character scalar URL, or \code{NA_character_} when \code{repo_slug} is empty.
#' @keywords internal
github_repo_zip_url <- function(repo_slug, ref = "main") {
  slug <- trimws(as.character(repo_slug %||% ""))
  ref <- trimws(as.character(ref %||% "main"))
  if (!nzchar(slug)) {
    return(NA_character_)
  }
  paste0("https://github.com/", slug, "/archive/refs/heads/", ref, ".zip")
}

#' Display name for a replication engine
#' @keywords internal
engine_display_name <- function(engine) {
  switch(
    tolower(as.character(engine %||% "")),
    r = "R",
    stata = "Stata",
    python = "Python",
    engine
  )
}

#' Engines to mention in the local setup open instruction
#'
#' Uses the active replication language for the current table or figure; falls
#' back to the sole declared study language when the active language is unknown.
#'
#' @param language Active replication language (\code{r}, \code{stata}, \code{python}).
#' @param study_engines Declared study languages from \code{replication.yml}.
#' @keywords internal
code_setup_open_engines <- function(language, study_engines = NULL) {
  lang <- tolower(as.character(language %||% ""))
  if (nzchar(lang) && lang %in% c("r", "stata", "python")) {
    return(lang)
  }
  declared <- unique(tolower(as.character(study_engines %||% character(0))))
  declared <- declared[declared %in% c("r", "stata", "python")]
  if (length(declared) >= 1L) {
    return(declared[[1L]])
  }
  "r"
}

#' Plain-text instruction for which program to open locally
#' @keywords internal
code_setup_open_instruction <- function(language, study_engines = NULL) {
  engines <- code_setup_open_engines(language, study_engines)
  names <- vapply(engines, engine_display_name, character(1))
  if (length(names) == 1L) {
    return(paste0("Open ", names[[1L]], " in the root folder of the repository."))
  }
  if (length(names) == 2L) {
    return(paste0(
      "Open ",
      names[[1L]],
      " or ",
      names[[2L]],
      " in the root folder of the repository."
    ))
  }
  paste0(
    "Open ",
    paste(names, collapse = ", "),
    " in the root folder of the repository."
  )
}

#' Declared dependency summary for one engine (yaml only — no probe)
#' @keywords internal
declared_engine_requirements <- function(meta, engine) {
  engine <- tolower(as.character(engine))
  switch(
    engine,
    r = list(
      ok = NA,
      required = study_declared_r_packages(meta),
      missing = character(0)
    ),
    stata = list(
      ok = NA,
      required = stata_deps_package_names(meta),
      missing = character(0),
      probe = stata_deps_probe_label("", meta = meta)
    ),
    python = list(
      ok = NA,
      required = study_declared_python_packages(meta),
      missing = character(0)
    ),
    list(ok = NA, required = character(0), missing = character(0))
  )
}

#' One human-readable requirements line for an engine
#' @keywords internal
format_code_setup_requirement_line <- function(engine, dep, probed = FALSE) {
  label <- engine_display_name(engine)
  if (is.null(dep)) {
    return(paste0(label, ": none declared."))
  }
  required <- dep$required %||% character(0)
  missing <- dep$missing %||% character(0)
  if (identical(engine, "stata") && length(required) == 0L) {
    probe <- dep$probe %||% ""
    if (nzchar(probe)) {
      required <- probe
    }
  }
  if (isTRUE(probed)) {
    if (isTRUE(dep$ok)) {
      if (length(required) > 0L) {
        return(paste0(label, ": all satisfied (", paste(required, collapse = ", "), ")."))
      }
      return(paste0(label, ": all satisfied."))
    }
    if (length(missing) > 0L && !isTRUE(dep$ok)) {
      req_text <- if (length(required) > 0L) {
        paste(required, collapse = ", ")
      } else {
        "see replication.yml"
      }
      return(paste0(
        label,
        ": missing ",
        paste(missing, collapse = ", "),
        " (declared: ",
        req_text,
        ")."
      ))
    }
  }
  if (length(required) > 0L) {
    return(paste0(label, ": ", paste(required, collapse = ", "), "."))
  }
  if (identical(engine, "stata")) {
    return(paste0(label, ": Stata installation required (see replication.yml)."))
  }
  paste0(label, ": none declared.")
}

#' Human-readable requirement lines for the Code tab setup box
#'
#' Uses a \code{study_system_compatibility} audit when supplied; otherwise reads
#' declared packages from \code{replication.yml}.
#'
#' @param meta Parsed replication metadata.
#' @param audit Optional compatibility audit from [check_study_compatibility()].
#' @param engines Character vector of engines to include (defaults to all declared).
#' @keywords internal
code_setup_requirements_lines <- function(meta, audit = NULL, engines = NULL) {
  declared <- study_declared_languages(meta)
  if (is.null(engines) || length(engines) == 0L) {
    engines <- declared
  } else {
    engines <- unique(tolower(as.character(engines)))
    engines <- engines[engines %in% declared]
    if (length(engines) == 0L) {
      engines <- declared
    }
  }
  probed <- !is.null(audit) &&
    is.null(audit$error) &&
    !is.null(audit$dependencies)
  deps <- if (probed) {
    audit$dependencies
  } else {
    stats::setNames(
      lapply(engines, function(eng) declared_engine_requirements(meta, eng)),
      engines
    )
  }
  if (probed && !is.null(deps$package) && !isTRUE(deps$package$ok)) {
    pkg <- deps$package$required %||% deps$package$missing %||% "study package"
    return(c(
      paste0("Study package: install ", paste(pkg, collapse = ", "), " first."),
      "Run check_study_compatibility(<doi>) locally to probe R, Python, and Stata."
    ))
  }
  lines <- vapply(
    engines,
    function(eng) {
      format_code_setup_requirement_line(eng, deps[[eng]], probed = probed)
    },
    character(1)
  )
  if (!probed) {
    lines <- c(
      lines,
      "Run check_study_compatibility(<doi>) after cloning to verify packages on your machine."
    )
  } else if (isTRUE(audit$ready)) {
    lines <- c(lines, "This server reports all declared dependencies satisfied.")
  } else if (isTRUE(audit$install_needed)) {
    lines <- c(
      lines,
      "Some dependencies are missing on this server; install locally before running the code."
    )
  }
  unname(lines)
}

#' Prep / data notes for the Code tab setup box
#' @keywords internal
code_setup_prep_notes <- function(meta, step_id = NULL) {
  notes <- character(0)
  dv <- meta$dataverse %||% NULL
  if (!is.null(dv) && length(dv) > 0L) {
    server <- as.character(dv$server %||% "dataverse.harvard.edu")
    dataset <- as.character(dv$dataset %||% dv$doi %||% "")
    notes <- c(
      notes,
      paste0(
        "Data come from Harvard Dataverse (",
        server,
        if (nzchar(dataset)) paste0(", ", dataset) else "",
        "). Run upstream prep steps before table or figure code."
      )
    )
  }
  step_id <- trimws(as.character(step_id %||% ""))
  if (nzchar(step_id)) {
    steps <- normalize_study_steps(meta)
    if (length(steps) > 0L) {
      graph <- study_step_graph(steps)
      if (step_id %in% graph$ids) {
        anc <- step_ancestors(step_id, graph)
        transform <- anc[
          vapply(anc, function(id) identical(graph$types[[id]], "transform"), logical(1))
        ]
        if (length(transform) > 0L) {
          labels <- vapply(
            transform,
            function(id) as.character(graph$labels[[id]] %||% id),
            character(1)
          )
          notes <- c(
            notes,
            paste0("Run prep step(s) first: ", paste(labels, collapse = "; "), ".")
          )
        }
      }
    }
  }
  unique(notes)
}

#' Resolve study repository slug for setup instructions
#' @keywords internal
code_setup_repo_slug <- function(meta, ctx = NULL) {
  if (is.null(ctx) && !is.null(meta)) {
    ctx <- list()
  }
  kind <- replication_kind(meta, ctx)
  slug <- if (identical(kind, "package")) {
    package_repo_slug(meta, ctx)
  } else if (identical(kind, "folder")) {
    study_repo_slug(meta, ctx)
  } else {
    as.character(meta$repo %||% meta$paper$study_repo %||% ctx$materials_repo %||% "")
  }
  slug <- as.character(slug[[1L]] %||% slug)
  slug <- trimws(slug)
  if (!nzchar(slug)) {
    return(NA_character_)
  }
  slug
}

#' Plain-text content for the Shiny Code tab setup box
#'
#' Returns a list of strings suitable for UI rendering and unit tests. Content
#' updates with study, replication step, and engine.
#'
#' @param doi Study DOI or handle.
#' @param repo_slug Optional \code{org/repo} slug (inferred from metadata when omitted).
#' @param language Active replication language.
#' @param study_engines Declared study languages (inferred when omitted).
#' @param meta Optional parsed metadata (loaded from \code{doi} when omitted).
#' @param audit Optional [check_study_compatibility()] result.
#' @param step_id Replication or prep step id.
#' @param repo,folder Optional registry row hints.
#' @return List with \code{title}, \code{step1}, \code{step2}, \code{step2_prep},
#'   \code{step3}, \code{one_liner}, \code{repo_slug}, \code{repo_url}, and
#'   \code{zip_url}.
#' @keywords internal
code_setup_box_content <- function(
  doi = NULL,
  repo_slug = NULL,
  language = "r",
  study_engines = NULL,
  meta = NULL,
  audit = NULL,
  step_id = NULL,
  repo = NULL,
  folder = NULL
) {
  if (is.null(meta) && !is.null(doi) && nzchar(as.character(doi))) {
    meta <- get_replication_meta(doi, repo = repo, folder = folder)
  }
  if (is.null(meta)) {
    stop("Study metadata is required for the Code tab setup box.", call. = FALSE)
  }
  ctx <- if (!is.null(doi) && nzchar(as.character(doi))) {
    tryCatch(paper_context(doi, repo = repo, folder = folder), error = function(e) list())
  } else {
    list()
  }
  if (is.null(study_engines) || length(study_engines) == 0L) {
    study_engines <- study_declared_languages(meta)
  }
  if (is.null(repo_slug) || !nzchar(as.character(repo_slug))) {
    repo_slug <- code_setup_repo_slug(meta, ctx)
  }
  repo_slug <- as.character(repo_slug[[1L]] %||% repo_slug)
  repo_url <- if (nzchar(repo_slug)) {
    paste0("https://github.com/", repo_slug)
  } else {
    NA_character_
  }
  zip_url <- github_repo_zip_url(repo_slug)
  doi_label <- as.character(doi %||% meta$paper$doi %||% meta$paper$study_handle %||% "")
  step1_lines <- c(
    if (nzchar(repo_slug)) {
      c(
        paste0("Clone or download the study repository: ", repo_slug, "."),
        paste0("Browse: ", repo_url),
        paste0("Download zip: ", zip_url)
      )
    } else {
      "Clone or download the study repository (see replication.yml for repo:)."
    },
    code_setup_open_instruction(language, study_engines)
  )
  req_engines <- code_setup_open_engines(language, study_engines)
  req_lines <- code_setup_requirements_lines(meta, audit = audit, engines = req_engines)
  if (nzchar(doi_label)) {
    req_lines <- sub("<doi>", shQuote(doi_label, type = "sh"), req_lines, fixed = TRUE)
    req_lines <- c(
      req_lines,
      paste0(
        "Or install declared dependencies: install_dependencies(",
        shQuote(doi_label, type = "sh"),
        ")."
      )
    )
  }
  prep_notes <- code_setup_prep_notes(meta, step_id = step_id)
  open_engines <- code_setup_open_engines(language, study_engines)
  open_names <- vapply(open_engines, engine_display_name, character(1))

  # Shared tip with get_code() — how to use displayed code; no script-footer advice
  tip_engine <- tolower(as.character(language %||% "r")[[1]])
  tip_rep <- NULL
  tip_type <- NULL
  tip_lines <- NULL
  if (!is.null(step_id) && nzchar(as.character(step_id))) {
    tip_rep <- tryCatch(
      find_replication_entry(meta, step_id, language = language),
      error = function(e) NULL
    )
    if (!is.null(tip_rep)) {
      tip_engine <- tryCatch(
        replication_engine(tip_rep, meta$paper),
        error = function(e) tip_engine
      )
      tip_type <- tip_rep$type %||% NULL
      code_rel <- as.character(tip_rep$code[[1]] %||% tip_rep$code %||% "")
      if (nzchar(code_rel) && !is.null(ctx$local_root)) {
        code_abs <- file.path(ctx$local_root, code_rel)
        if (file.exists(code_abs)) {
          tip_lines <- tryCatch(
            readLines(code_abs, warn = FALSE),
            error = function(e) NULL
          )
        }
      }
    }
  }
  advice <- if (exists("get_code_run_advice", mode = "function", inherits = TRUE)) {
    tryCatch(
      get_code_run_advice(
        engine = tip_engine,
        type = tip_type,
        rep = tip_rep,
        lines = tip_lines,
        doi = doi_label,
        what = step_id
      ),
      error = function(e) character(0)
    )
  } else {
    character(0)
  }
  one_liner <- "Set your working directory to the study repository root, then run or paste the script below."
  step3 <- if (length(advice)) {
    paste(advice, collapse = "\n")
  } else if (length(open_names) == 1L) {
    paste0(
      one_liner,
      " Or paste the code below into your ",
      open_names[[1L]],
      " session."
    )
  } else {
    paste0(
      one_liner,
      " Or paste the code below into your ",
      paste(open_names, collapse = " or "),
      " session."
    )
  }
  list(
    title = "See here for guidance on running this code",
    step1 = step1_lines,
    step2 = req_lines,
    step2_prep = prep_notes,
    step3 = step3,
    one_liner = one_liner,
    repo_slug = repo_slug,
    repo_url = repo_url,
    zip_url = zip_url
  )
}
