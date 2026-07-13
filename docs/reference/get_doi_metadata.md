# Retrieve metadata for a DOI

Fetches bibliographic metadata for a research paper using its DOI. The
function queries a DOI resolver and returns basic metadata including the
paper title, journal, publication year, and authors.

## Usage

``` r
get_doi_metadata(doi)
```

## Arguments

- doi:

  Character. DOI of the paper.

## Value

A list containing:

- title:

  Title of the paper

- journal:

  Journal name

- year:

  Publication year

- authors:

  Vector of author names

## Details

Fetches bibliographic metadata from a DOI resolver. Used when preparing
registry stubs and study metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
get_doi_metadata("10.1177/00491241211036161")
} # }
```
