# Package index

## Package

Package overview.

- [`replicateEverything`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  [`replicateEverything-package`](https://replicate-anything.github.io/replicateEverything/reference/replicateEverything-package.md)
  : replicateEverything: Reproduce Empirical Research Results

## Discovery

Find papers and inspect replication metadata.

- [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
  : Load the replication registry index
- [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md)
  : Search replicated papers
- [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  [`list_replication_groups()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md)
  : List available replications for a paper
- [`print(`*`<replication_list>`*`)`](https://replicate-anything.github.io/replicateEverything/reference/print.replication_list.md)
  : Compact print method for replication step lists
- [`paper_article_url()`](https://replicate-anything.github.io/replicateEverything/reference/paper_article_url.md)
  : Resolve a human-facing URL for a published article

## Run replications

Run tables and figures from registry scripts.

- [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  : Run a single replication or all replications for a paper

- [`describe_study_dag()`](https://replicate-anything.github.io/replicateEverything/reference/describe_study_dag.md)
  : Text representation of the study DAG for Shiny / CLI

- [`study_dag_display()`](https://replicate-anything.github.io/replicateEverything/reference/study_dag_display.md)
  : Step display data for Shiny (components of paths of id / label /
  description)

- [`study_dag_facets()`](https://replicate-anything.github.io/replicateEverything/reference/study_dag_facets.md)
  : Faceted pipeline groups for Shiny (split multi-branch components)

- [`study_output_dir()`](https://replicate-anything.github.io/replicateEverything/reference/study_output_dir.md)
  [`study_artifact_dir()`](https://replicate-anything.github.io/replicateEverything/reference/study_output_dir.md)
  :

  Display output directory for a study (legacy name:
  [`study_artifact_dir()`](https://replicate-anything.github.io/replicateEverything/reference/study_output_dir.md))

- [`migrate_legacy_steps_yaml()`](https://replicate-anything.github.io/replicateEverything/reference/migrate_legacy_steps_yaml.md)
  : Migrate legacy prep/replications yaml to a unified steps block
  (character yaml)

- [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  : Retrieve replication code for a paper

- [`run_prep_step()`](https://replicate-anything.github.io/replicateEverything/reference/run_prep_step.md)
  : Run a single prep step

- [`list_prep_steps()`](https://replicate-anything.github.io/replicateEverything/reference/list_prep_steps.md)
  : List pipeline prep steps for a paper

## Shiny demo

Browse studies and run replications interactively.

- [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  : Run the bundled Shiny demo app
- [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
  : Copy the bundled Shiny app into a deploy directory

## Contribute

Validate studies and prepare registry handoff files in the study repo.

- [`build_study_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_artifacts.md)
  : Build display artifacts for a folder-backed study
- [`build_package_artifacts()`](https://replicate-anything.github.io/replicateEverything/reference/build_package_artifacts.md)
  : Build display artifacts for a package-backed study
- [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_folder_replication.md)
  : Validate a folder-backed replication study
- [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_package_replication.md)
  : Validate a package-backed replication study
- [`prepare_study_for_registry()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md)
  [`prepare_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md)
  : Prepare a study repository for registry handoff (contributor)
- [`ai_skills()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skills.md)
  : List bundled AI skills
- [`ai_skill()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill.md)
  : Read a bundled AI skill
- [`ai_skill_path()`](https://replicate-anything.github.io/replicateEverything/reference/ai_skill_path.md)
  : Get the path to a bundled AI skill

## Maintainer setup

Probe and install study dependencies; sync studies into the registry.

- [`configure_local_monorepo()`](https://replicate-anything.github.io/replicateEverything/reference/configure_local_monorepo.md)
  : Configure options for a local replicate-anything monorepo
- [`package_build_info()`](https://replicate-anything.github.io/replicateEverything/reference/package_build_info.md)
  : Package version and build identity
- [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
  : Check yaml-declared dependencies against this machine (no installs)
- [`install_study_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_study_dependencies.md)
  : Install dependencies for one folder-backed or registry study
- [`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md)
  : Install dependencies for every study in the registry index
- [`maintainer_dependency_hint()`](https://replicate-anything.github.io/replicateEverything/reference/maintainer_dependency_hint.md)
  : Maintainer guidance when dependencies or executables are missing
- [`replication_kind()`](https://replicate-anything.github.io/replicateEverything/reference/replication_kind.md)
  : Classify a registry study by materials layout
- [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
  [`sync_folder_paper()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
  : Sync a prepared study into the registry repository (maintainer)
- [`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md)
  : Compile registry index.csv from study stub yaml files
- [`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md)
  : Refresh the registry index and optionally rerun the full audit
  (maintainer)

## Registry audit

Run all registry replications and inspect results.

- [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  : Audit all registry replications
- [`check_glm_table_benchmark()`](https://replicate-anything.github.io/replicateEverything/reference/check_glm_table_benchmark.md)
  : Compare replicated GLM tables to published benchmarks
