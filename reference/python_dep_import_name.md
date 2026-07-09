# Map a PyPI dependency spec to its Python import name

Strips version specifiers, extras, and environment markers, then applies
a small set of well-known name overrides (e.g. `scikit-learn` -\>
`sklearn`). Defaults to the distribution name with hyphens converted to
underscores.

## Usage

``` r
python_dep_import_name(dep)
```

## Arguments

- dep:

  Character dependency spec (e.g. `"pandas>=1.5"`).

## Value

Character import name (may be empty).
