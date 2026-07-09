# Stata SSC package names declared for a generic dependency probe

Optional `stata_packages:` list in `replication.yml`. Used when no
`stata_deps_probe` script is declared; checks `which <pkg>` only.

## Usage

``` r
stata_deps_package_names(meta = NULL, study_root = NULL)
```

## Arguments

- meta:

  Parsed replication metadata.

## Value

Character vector of package names.
