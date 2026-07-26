# Load the Shiny Studies cache (session-memoized by file mtime)

Prefers a local registry checkout's `shiny_studies.json`, then the
GitHub raw URL. Memoized in-process keyed by path + mtime so Shiny tab
switches do not rebuild.

## Usage

``` r
load_shiny_studies_cache(registry_root = NULL, force = FALSE)
```

## Arguments

- registry_root:

  Optional registry root. Defaults to
  `getOption("replicateEverything.registry_root")` or
  [`auto_detect_registry_root()`](https://replicate-anything.github.io/replicateEverything/reference/auto_detect_registry_root.md).

- force:

  If `TRUE`, bypass the session memo.

## Value

List with `studies`, `n`, `generated_at`, `schema_version`, and `source`
/ `mtime`.

## Examples

``` r
if (FALSE) { # \dontrun{
cache <- load_shiny_studies_cache()
length(cache$studies)
} # }
```
