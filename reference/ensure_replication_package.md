# Load or install a study replication package

Tries, in order: local sibling package (when configured), installed
package (upgrade from GitHub when outdated), then fresh GitHub install
from
[`package_repo_slug()`](https://replicate-anything.github.io/replicateEverything/reference/package_repo_slug.md).

## Usage

``` r
ensure_replication_package(package, meta = NULL, ctx = NULL)
```

## Arguments

- package:

  R package name.

- meta:

  Parsed replication.yml contents.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).
