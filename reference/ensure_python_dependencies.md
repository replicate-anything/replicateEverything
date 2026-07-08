# Ensure Python pip dependencies for a replication entry

Installs packages listed under entry-level `dependencies` (engine
`python` only) or a `requirements` file path when
`install_missing = TRUE`.

## Usage

``` r
ensure_python_dependencies(
  replication_meta,
  paper_meta = NULL,
  ctx = NULL,
  meta = NULL,
  install_missing = FALSE
)
```
