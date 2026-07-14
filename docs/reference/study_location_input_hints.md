# Hints when `check_replication()` cannot resolve a study location string

Detects common DOI / registry-folder / repo-folder mashups (slashes,
dashes, underscores, missing `rep-` prefix) and lists accepted input
forms.

## Usage

``` r
study_location_input_hints(loc)
```

## Arguments

- loc:

  Raw location string from the user.

## Value

Character scalar (may be empty).
