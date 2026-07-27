# Materialize remotely declared study data into the study root

Fetches files listed under `dataverse.files` / `data_files:` into their
declared local `path`s when missing. Not a pipeline step — call
automatically before runs, or explicitly for smoke checks.

## Usage

``` r
materialize_declared_data(
  meta,
  study_root = NULL,
  ctx = NULL,
  force = FALSE,
  paths = NULL
)
```

## Arguments

- meta:

  Parsed replication metadata, or a study root path / DOI that
  `get_replication_meta()` can resolve.

- study_root:

  Local study repository root. When `NULL`, uses `ctx$local_root` /
  [`ensure_study_folder_local()`](https://replicate-anything.github.io/replicateEverything/reference/ensure_study_folder_local.md).

- ctx:

  Optional paper context.

- force:

  Re-download existing files.

- paths:

  Optional character vector of relative paths to materialize; when set,
  only matching declared entries are fetched.

## Value

Invisibly, character vector of absolute paths written or already
present.

## Examples

``` r
if (FALSE) { # \dontrun{
# Blair et al. APSR: surgical Dataverse file wiring in replication.yml
materialize_declared_data("10.1017/S0003055422000284")
materialize_declared_data("10.1017/S0003055403000534")
} # }
```
