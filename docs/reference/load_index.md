# Load the replication registry index

Returns `index.csv` from the configured registry root or from GitHub.
When the index has no `handle` column, one is derived from each row's
`folder` field.

## Usage

``` r
load_index()
```

## Value

A data frame containing replication metadata (`folder`, `doi`, `title`,
`journal`, `year`, `authors`, `repo`, and `handle` when present).

## Examples

``` r
if (FALSE) { # \dontrun{
head(load_index()[, c("handle", "doi", "title")])
} # }
```
