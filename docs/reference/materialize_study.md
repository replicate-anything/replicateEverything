# Materialize study materials for maintainer probes and installs

Folder studies are cloned/cached locally; package studies are loaded or
installed from GitHub.

## Usage

``` r
materialize_study(meta, ctx)
```

## Arguments

- meta:

  Parsed replication metadata.

- ctx:

  Paper context.

## Value

List with `kind`, `root`, `meta`, and optional `package`.
