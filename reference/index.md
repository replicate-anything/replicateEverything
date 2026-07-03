# Package index

## Package

Package overview and help search entry point.

- [`replicateEverything`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  [`replicateEverything-package`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  : replicateEverything: Reproduce Empirical Research Results

## Shiny demo

Browse studies and run replications interactively.

- [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  : Run the bundled Shiny demo app
- [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
  : Copy the bundled Shiny app into a deploy directory

## Registry

Add and validate package-backed studies.

- [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md)
  : Validate a package-backed replication study
- [`add_paper()`](https://replicate-anything.github.io/replicateEverything/reference/add_paper.md)
  : Add a package-backed study to the replication registry
- [`is_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/is_package_replication.md)
  : Whether replication metadata refers to an installed R package
- [`is_folder_study_replication()`](https://replicate-anything.github.io/replicateEverything/reference/is_folder_study_replication.md)
  : Whether replication metadata refers to a folder-backed external
  study repo
- [`is_study_package_error()`](https://replicate-anything.github.io/replicateEverything/reference/is_study_package_error.md)
  : Whether an error is a missing study replication package
- [`print(`*`<package_replication_check>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/print.package_replication_check.md)
  [`print(`*`<folder_replication_check>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/print.package_replication_check.md)
  [`print(`*`<replication_check>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/print.package_replication_check.md)
  : Print a replication checklist result
- [`study_package_install_info()`](https://replicate-anything.github.io/replicateEverything/reference/study_package_install_info.md)
  : Install instructions for a package-backed study
- [`study_package_install_message()`](https://replicate-anything.github.io/replicateEverything/reference/study_package_install_message.md)
  : User-facing message for installing a study replication package

## Registry audit

Run all registry replications and inspect results.

- [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  : Audit all registry replications
- [`audit_everything_qmd()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything_qmd.md)
  : Path to the registry Quarto audit report
- [`write_registry_audit_record()`](https://replicate-anything.github.io/replicateEverything/reference/write_registry_audit_record.md)
  : Write audit results into the registry repository
- [`load_registry_audit_summary()`](https://replicate-anything.github.io/replicateEverything/reference/load_registry_audit_summary.md)
  : Load the registry audit summary
- [`registry_audit_summary_path()`](https://replicate-anything.github.io/replicateEverything/reference/registry_audit_summary_path.md)
  : Path to the registry audit summary JSON
- [`registry_audit_rds_path()`](https://replicate-anything.github.io/replicateEverything/reference/registry_audit_rds_path.md)
  : Path to the full registry audit RDS snapshot

## Discovery

Find papers and inspect replication metadata.

- [`get_doi_metadata()`](https://replicate-anything.github.io/replicateEverything/reference/get_doi_metadata.md)
  : Retrieve metadata for a DOI

- [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  : Search replicated papers

- [`normalize_doi()`](https://replicate-anything.github.io/replicateEverything/reference/normalize_doi.md)
  : Normalize a DOI

- [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md)
  : Resolve a DOI or local study query into a canonical DOI

- [`is_local_doi_query()`](https://replicate-anything.github.io/replicateEverything/reference/is_local_doi_query.md)
  : Detect whether a DOI argument requests the local working-directory
  study

- [`find_local_study_root()`](https://replicate-anything.github.io/replicateEverything/reference/find_local_study_root.md)
  :

  Find a folder-backed study root containing `replication.yml`

- [`configure_local_monorepo()`](https://replicate-anything.github.io/replicateEverything/reference/configure_local_monorepo.md)
  : Configure options for a local replicate-anything monorepo

- [`configure_study_folder()`](https://replicate-anything.github.io/replicateEverything/reference/configure_study_folder.md)
  : Register a server-local study folder for a DOI

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
- [`find_stata_executable()`](https://replicate-anything.github.io/replicateEverything/reference/find_stata_executable.md)
  : Locate a Stata executable
- [`replication_code_language_for()`](https://replicate-anything.github.io/replicateEverything/reference/replication_code_language_for.md)
  : Code language for a replication (for Shiny syntax highlighting)
- [`load_replication_for_display()`](https://replicate-anything.github.io/replicateEverything/reference/load_replication_for_display.md)
  : Load or run a replication for display
- [`resolve_replication_display()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_replication_display.md)
  : Resolve display output for an already-selected result
- [`stata_result_path()`](https://replicate-anything.github.io/replicateEverything/reference/stata_result_path.md)
  : Extract the output file path from a Stata replication result
- [`smcl_to_html()`](https://replicate-anything.github.io/replicateEverything/reference/smcl_to_html.md)
  : Convert a Stata SMCL file to HTML for display

## Folder-backed studies

Build artifacts and sync folder-backed study repos.

- [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
  : Build display artifacts for a folder-backed study
- [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
  : Validate a folder-backed replication study
- [`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_folder_paper.md)
  : Prepare a folder-backed study for registry sync
- [`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_folder_paper.md)
  : Copy prepared registry files into the registry repository
- [`add_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/add_folder_paper.md)
  : Add a folder-backed study to the replication registry
- [`write_folder_registry_stub()`](https://replicate-anything.github.io/replicateEverything/reference/write_folder_registry_stub.md)
  : Write registry stub files into a study repository

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
- [`artifact_display_missing()`](https://replicate-anything.github.io/replicateEverything/reference/artifact_display_missing.md)
  : Whether display content is missing or empty
- [`resolve_display_value()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_display_value.md)
  : Resolve a replication result envelope to a display-ready value
