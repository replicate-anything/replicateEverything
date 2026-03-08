# Create a replication template

Generates a local folder structure for contributing a new replication to
the replication registry. The template includes metadata, example data,
and example scripts.

## Usage

``` r
create_replication_template(doi)
```

## Arguments

- doi:

  Character. DOI of the paper.

## Value

Creates a folder containing replication scaffolding.

## Examples

``` r
if (FALSE) { # \dontrun{
create_replication_template("10.1177/00491241211036161")
} # }
```
