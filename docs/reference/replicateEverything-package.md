# replicateEverything: Reproduce Empirical Research Results

The `replicateEverything` package provides tools for discovering and
executing computational replications of empirical research papers. It
connects to a public replication registry containing metadata,
replication scripts, and processed datasets required to reproduce
figures and tables from published studies.

## Workflow

A typical workflow using the package is:

1.  Browse the registry with
    [`load_index()`](https://replicate-anything.github.io/replicateEverything/reference/load_index.md)
    or
    [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md).

2.  Inspect available replications using
    [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md).

3.  Run a single table or figure with `run_replication(doi, "fig_1")`.

4.  Reproduce all results with `run_replication(doi, "everything")`.

5.  View replication code with
    [`get_code()`](https://replicate-anything.github.io/replicateEverything/reference/get_code.md).

6.  Launch the bundled Shiny demo with
    [`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md),
    or deploy it with
    [`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md).

7.  Contribute a study with
    [`build_study_outputs()`](https://replicate-anything.github.io/replicateEverything/reference/build_study_outputs.md),
    [`check_replication()`](https://replicate-anything.github.io/replicateEverything/reference/check_replication.md),
    [`prepare_study_for_registry()`](https://replicate-anything.github.io/replicateEverything/reference/prepare_study_for_registry.md),
    and
    [`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)
    (maintainer).

8.  Audit the full registry with
    [`audit_everything()`](https://replicate-anything.github.io/replicateEverything/reference/audit_everything.md).

See
[`vignette("meet-the-functions")`](https://replicate-anything.github.io/replicateEverything/articles/meet-the-functions.md)
for a tour of every main function.

## Shiny demo

A live instance runs at <https://shiny2.wzb.eu/ipi/replicate/>. The
package ships a demo app in `inst/shiny/`. Use
[`run_shiny_app()`](https://replicate-anything.github.io/replicateEverything/reference/run_shiny_app.md)
to launch it from an installed build, or
[`save_local_shiny()`](https://replicate-anything.github.io/replicateEverything/reference/save_local_shiny.md)
to copy `app.R` and `www/` into a Shiny Server directory.

## Registry

Replication metadata and materials are stored in the public registry:
<https://github.com/replicate-anything/registry>.

## See also

Useful links:

- <https://github.com/replicate-anything/replicateEverything>

- <https://replicate-anything.github.io/replicateEverything/>

- Report bugs at
  <https://github.com/replicate-anything/replicateEverything/issues>

## Author

**Maintainer**: Vermon Washington <vermon.washington@wzb.eu>

Authors:

- Vermon Washington <vermon.washington@wzb.eu>

- Macartan Humphreys <macartan.humphreys@wzb.eu>

- Cord Masche <cord.masche@wzb.eu>
