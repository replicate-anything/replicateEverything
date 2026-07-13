# Resolve GitHub repo slug for a package-backed replication

Used when no local sibling package is found. Set `paper.package_repo` or
top-level `repo` in `replication.yml` (GitHub slug, e.g.
`replicate-anything/rep-10.1371_journal.pone.0278337`).

## Usage

``` r
package_repo_slug(meta, ctx)
```

## Arguments

- meta:

  Parsed replication.yml contents.

- ctx:

  Paper context from
  [`paper_context()`](https://replicate-anything.github.io/replicateEverything/reference/paper_context.md).

## Value

Character repo slug.
