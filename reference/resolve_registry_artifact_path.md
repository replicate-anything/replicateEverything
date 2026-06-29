# Resolve a precomputed artifact under the registry paper folder

Package-backed studies may ship display artifacts in
`registry/papers/.../artifacts/` even when code lives in the study
package.

## Usage

``` r
resolve_registry_artifact_path(what, ctx, rep = NULL, doi = NULL)
```

## Arguments

- what:

  Replication id.

- ctx:

  Paper context.

- rep:

  Optional replication entry.

- doi:

  Optional DOI for caching.
