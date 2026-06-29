# Package index

## Discovery

Find papers and inspect replication metadata.

- [`get_doi_metadata()`](https://replicate-anything.github.io/replicateEverything/reference/get_doi_metadata.md)
  : Retrieve metadata for a DOI
- [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  : Search replicated papers
- [`normalize_doi()`](https://replicate-anything.github.io/replicateEverything/reference/normalize_doi.md)
  : Normalize a DOI
- [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
  : Load the replication registry index
- [`find_repo()`](https://replicate-anything.github.io/replicateEverything/reference/find_repo.md)
  : Find the repository for a paper replication
- [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  : List available replications for a paper
- [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  : Retrieve replication code for a paper
- [`replication_index_diagnostics()`](https://replicate-anything.github.io/replicateEverything/reference/replication_index_diagnostics.md)
  : Report where the replication index was sought (for debugging Shiny)

## Run replications

Render tables and figures from registry scripts.

- [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md)
  : Render a single replication
- [`render_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/render_for_display.md)
  : Render a replication and apply formatting for display
- [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  : Run a single replication
- [`replicate_paper()`](https://replicate-anything.github.io/replicateEverything/reference/replicate_paper.md)
  : Replicate all results from a paper
- [`validate_replication()`](https://replicate-anything.github.io/replicateEverything/reference/validate_replication.md)
  : Validate that a replication can be rendered
- [`create_replication_template()`](https://replicate-anything.github.io/replicateEverything/reference/create_replication_template.md)
  : Create a replication template
- [`self_run()`](https://replicate-anything.github.io/replicateEverything/reference/self_run.md)
  : Run a replication script footer when executed directly
- [`load_local_replication_data()`](https://replicate-anything.github.io/replicateEverything/reference/load_local_replication_data.md)
  : Load replication data from local paths (for self-contained scripts)

## Artifacts

Precomputed outputs for Display in the Shiny app.

- [`get_artifact_path()`](https://replicate-anything.github.io/replicateEverything/reference/get_artifact_path.md)
  : Get artifact URL or local path for a replication
- [`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md)
  : Load a precomputed artifact for a replication
- [`save_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/save_artifact.md)
  : Save a replication result as an artifact file
- [`artifact_available()`](https://replicate-anything.github.io/replicateEverything/reference/artifact_available.md)
  : Check whether a precomputed artifact is available
- [`validate_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/validate_artifact.md)
  : Validate that a precomputed artifact exists
- [`validate_paper_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/validate_paper_artifacts.md)
  : Validate all artifacts for a paper

## Display helpers

Format analysis output for HTML tables and plots.

- [`format_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/format_for_display.md)
  : Apply an optional format function to an analysis object
- [`normalize_html_table()`](https://replicate-anything.github.io/replicateEverything/reference/normalize_html_table.md)
  : Decode HTML entities in kableExtra / modelsummary table output
- [`replication_object()`](https://replicate-anything.github.io/replicateEverything/reference/replication_object.md)
  : Extract a plain object from a replication result envelope
- [`replication_error_message()`](https://replicate-anything.github.io/replicateEverything/reference/replication_error_message.md)
  : Format a replication error for user-facing display
- [`try_render_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/try_render_for_display.md)
  : Run a replication and return a result or error object
