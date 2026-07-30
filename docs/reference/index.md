# Package index

## Package

Package overview.

- [`replicateEverything`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  [`replicateEverything-package`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  : replicateEverything: Reproduce Empirical Research Results

## Run & inspect

Run tables and figures and read the code behind them.

- [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  : Run a single replication or all replications for a paper
- [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  : Retrieve replication code for a paper
- [`describe_study_dag()`](https://replicate-anything.github.io/replicateEverything/reference/describe_study_dag.md)
  : Text representation of the study DAG for Shiny / CLI

## Discovery

Find studies and inspect replication metadata.

- [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
  : Load the replication registry index
- [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  : Search replicated papers
- [`get_study()`](https://replicate-anything.github.io/replicateEverything/reference/get_study.md)
  : Resolve a study handle (metadata once)
- [`summary_study()`](https://replicate-anything.github.io/replicateEverything/reference/summary_study.md)
  : Summarize a study by DOI / handle (constructs then summarizes)
- [`summary(`*`<replicate_study>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/summary.replicate_study.md)
  : Study overview (metadata, steps, related, gaps)
- [`print(`*`<replicate_study>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/print.replicate_study.md)
  : Compact print for a study descriptor
- [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  : List available replications for a paper
- [`paper_article_url()`](https://replicate-anything.github.io/replicateEverything/reference/paper_article_url.md)
  : Resolve a human-facing URL for a published article
- [`paper_source_repository()`](https://replicate-anything.github.io/replicateEverything/reference/paper_source_repository.md)
  : Resolve paper.source_repository (with legacy aliases)
- [`paper_source_repositories()`](https://replicate-anything.github.io/replicateEverything/reference/paper_source_repositories.md)
  : Resolve all paper.source_repository credits
- [`source_repository_kind()`](https://replicate-anything.github.io/replicateEverything/reference/source_repository_kind.md)
  : Classify a source-repository credit for display icons
- [`source_repository_href()`](https://replicate-anything.github.io/replicateEverything/reference/source_repository_href.md)
  : Browse URL for a source-repository credit
- [`registry_source_repository_gaps()`](https://replicate-anything.github.io/replicateEverything/reference/registry_source_repository_gaps.md)
  : Studies in a registry missing paper.source_repository

## Contribute: build & check

Bake precomputed outputs and validate a study repo before registration.

- [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
  : Build display outputs for a study repository
- [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  : Validate a folder-backed replication study
- [`check_and_bake_study()`](https://replicate-anything.github.io/replicateEverything/reference/check_and_bake_study.md)
  : Build outputs and validate a study (contributor)
- [`fetch_dataverse_file()`](https://replicate-anything.github.io/replicateEverything/reference/fetch_dataverse_file.md)
  : Fetch a Dataverse file into a study-relative path (surgical pull)
- [`materialize_declared_data()`](https://replicate-anything.github.io/replicateEverything/reference/materialize_declared_data.md)
  : Materialize remotely declared study data into the study root
- [`lookup_study_replication_timing()`](https://replicate-anything.github.io/replicateEverything/reference/lookup_study_replication_timing.md)
  : Look up last known bake seconds for a step id
- [`read_study_replication_timings()`](https://replicate-anything.github.io/replicateEverything/reference/read_study_replication_timings.md)
  : Read study bake timings
- [`record_study_replication_timing()`](https://replicate-anything.github.io/replicateEverything/reference/record_study_replication_timing.md)
  : Record a successful bake / run timing for one step

## Maintainer: registry ops

Register studies, sync stubs, rebuild the index, and audit the registry.

- [`register_study()`](https://replicate-anything.github.io/replicateEverything/reference/register_study.md)
  : Validate then sync a study into the registry (maintainer)

- [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
  : Sync a study into the registry repository (maintainer)

- [`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md)
  : Refresh the registry index and optionally rerun the full audit
  (maintainer)

- [`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md)
  : Compile registry index.csv from study stub yaml files

- [`build_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/build_shiny_studies_cache.md)
  : Build and write the Shiny Studies cache artifact

- [`load_shiny_studies_cache()`](https://replicate-anything.github.io/replicateEverything/reference/load_shiny_studies_cache.md)
  : Load the Shiny Studies cache (session-memoized by file mtime)

- [`studies_table_data()`](https://replicate-anything.github.io/replicateEverything/reference/studies_table_data.md)
  : Filter / sort studies from the precomputed Shiny cache

- [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  : Audit all registry replications

- [`audit_result_status()`](https://replicate-anything.github.io/replicateEverything/reference/audit_result_status.md)
  : User-facing status label for one audit result row

- [`seed_registry_audit_jobs()`](https://replicate-anything.github.io/replicateEverything/reference/seed_registry_audit_jobs.md)
  : Seed / refresh audit jobs CSV from bake timings, artifacts, and
  prior RDS

- [`refresh_registry_audit_summary()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry_audit_summary.md)
  :

  Rebuild `audit_summary.json` from the full audit jobs CSV

## Maintainer: setup & diagnostics

Probe and install study dependencies; local monorepo and deploy
diagnostics.

- [`configure_local_monorepo()`](https://replicate-anything.github.io/replicateEverything/reference/configure_local_monorepo.md)
  : Configure options for a local replicate-anything monorepo
- [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
  : Check yaml-declared dependencies against this machine (no installs)
- [`install_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_dependencies.md)
  : Install declared dependencies for a study, or for the whole registry
- [`maintainer_dependency_hint()`](https://replicate-anything.github.io/replicateEverything/reference/maintainer_dependency_hint.md)
  : Maintainer guidance when dependencies or executables are missing
- [`package_build_info()`](https://replicate-anything.github.io/replicateEverything/reference/package_build_info.md)
  : Package version and build identity
- [`package_deploy_diagnostics()`](https://replicate-anything.github.io/replicateEverything/reference/package_deploy_diagnostics.md)
  : Diagnose Shiny deployment and installed package identity
- [`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md)
  : Build precomputed outputs
- [`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md)
  : Validate precomputed outputs

## Shiny app

Launch the bundled Shiny demo locally.

- [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  : Run the bundled Shiny demo app
- [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
  : Copy the bundled Shiny app into a deploy directory

## AI skills

Read bundled AI agent skill files (onboarding, Dataverse, registry
include).

- [`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md)
  : List bundled AI skills
- [`ai_skill()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill.md)
  : Read a bundled AI skill
- [`ai_skill_path()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill_path.md)
  : Get the path to a bundled AI skill
