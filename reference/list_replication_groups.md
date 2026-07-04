# List one replication entry per logical group

Returns the default-engine entry for each figure/table group (R when
both engines exist).

## Usage

``` r
list_replication_groups(doi, repo = NULL, folder = NULL, language = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- language:

  Optional `"R"` or `"stata"` for each group.

## Value

List of replication entries.

## Examples

``` r
if (FALSE) { # \dontrun{
list_replication_groups("10.1257/aer.91.5.1369")
list_replication_groups("10.1257/aer.91.5.1369", language = "stata")
} # }
```
