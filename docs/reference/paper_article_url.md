# Resolve a human-facing URL for a published article

Some publisher DOI links (notably older Cambridge Core / APSR entries)
do not resolve reliably. Study metadata may therefore include an
explicit landing page via `paper.article_url` (or `paper.landing_url`).
When no override is set, the function falls back to
`https://doi.org/...`.

## Usage

``` r
paper_article_url(doi = NULL, paper = NULL, meta = NULL)
```

## Arguments

- doi:

  Optional DOI string or URL.

- paper:

  Optional `paper` list from `replication.yml` or the registry stub.

- meta:

  Optional full parsed metadata (uses `meta$paper`).

## Value

Character URL, or `NULL` when no link can be formed.

## Examples

``` r
if (FALSE) { # \dontrun{
paper_article_url(
  doi = "10.1017/S0003055403000534",
  paper = list(
    article_url = paste0(
      "https://www.cambridge.org/core/journals/",
      "american-political-science-review/article/abs/",
      "ethnicity-insurgency-and-civil-war/",
      "B1D5D0E7C782483C5D7E102A61AD6605"
    )
  )
)
} # }
```
