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
  : List available replications for a paper
- [`paper_article_url()`](https://replicate-anything.github.io/replicateEverything/reference/paper_article_url.md)
  : Resolve a human-facing URL for a published article

## Run replications

Run tables and figures from registry scripts.

- [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
  : Run a single replication or all replications for a paper
- [`describe_study_dag()`](https://replicate-anything.github.io/replicateEverything/reference/describe_study_dag.md)
  : Text representation of the study DAG for Shiny / CLI
- [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md)
  : Retrieve replication code for a paper

## Shiny demo

Browse studies and run replications interactively.

- [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
  : Run the bundled Shiny demo app
- [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
  : Copy the bundled Shiny app into a deploy directory

## Contribute

Validate studies and prepare registry handoff files in the study repo.

- [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md)
  : Build display outputs for a study repository
- [`check_folder_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  [`check_package_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md)
  : Validate a folder-backed replication study
- [`prepare_study_for_registry()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md)
  : Validate a study repository before registry onboarding (contributor)
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
- [`package_deploy_diagnostics()`](https://replicate-anything.github.io/replicateEverything/reference/package_deploy_diagnostics.md)
  : Diagnose Shiny deployment and installed package identity
- [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
  : Check yaml-declared dependencies against this machine (no installs)
- [`install_study_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_study_dependencies.md)
  : Install dependencies for one folder-backed or registry study
- [`install_registry_dependencies()`](https://replicate-anything.github.io/replicateEverything/reference/install_registry_dependencies.md)
  : Install dependencies for every study in the registry index
- [`maintainer_dependency_hint()`](https://replicate-anything.github.io/replicateEverything/reference/maintainer_dependency_hint.md)
  : Maintainer guidance when dependencies or executables are missing
- [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
  : Sync a study into the registry repository (maintainer)
- [`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md)
  : Compile registry index.csv from study stub yaml files
- [`build_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_outputs.md)
  : Build precomputed outputs
- [`validate_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/validate_outputs.md)
  : Validate precomputed outputs

## Registry audit

Run all registry replications and inspect results.

- [`refresh_registry()`](https://replicate-anything.github.io/replicateEverything/reference/refresh_registry.md)
  : Refresh the registry index and optionally rerun the full audit
  (maintainer)
- [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md)
  : Audit all registry replications
