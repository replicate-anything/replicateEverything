# Build and write the Shiny Studies cache artifact

Writes `registry/shiny_studies.json` with one record per study: citation
fields, collections, languages/engines, notes flags (data unavailable /
missing engine), related upstream/downstream (dois, titles, urls),
article and study/repo urls, plus a baked `ui` block (select /
collection choices) so Shiny startup does not reassemble dropdowns.
Intended for the Shiny Studies tab — no live yaml fetch at list time.

## Usage

``` r
build_shiny_studies_cache(registry_root, index = NULL, metas = NULL)
```

## Arguments

- registry_root:

  Path to the registry repository.

- index:

  Optional index data frame (defaults to compiling from stubs).

- metas:

  Optional list of stub metas aligned with `index` rows.

## Value

Invisibly, a list with `path`, `n`, and `cache`.

## Details

Called from
[`build_registry_index()`](https://replicate-anything.github.io/replicateEverything/reference/build_registry_index.md).
Gap flags come from stub `notes:` (written by
[`sync_study_to_registry()`](https://replicate-anything.github.io/replicateEverything/reference/sync_study_to_registry.md)),
declared languages (mathematica → missing engine), and the latest audit
snapshot when present.

## Examples

``` r
if (FALSE) { # \dontrun{
build_shiny_studies_cache("../registry")
} # }
```
