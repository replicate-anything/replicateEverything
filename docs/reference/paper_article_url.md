# Resolve a human-facing URL for a published article

Some publisher DOI links (notably older Cambridge Core / APSR entries)
do not resolve reliably. Study metadata may therefore include an
explicit landing page via `paper.article_url` (or `paper.landing_url` /
`paper.publisher_url`). When no override is set, the function falls back
to `https://doi.org/...`.

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

## Details

`paper.study_url` is the GitHub study repository and is intentionally
ignored here — use the Shiny Repo column / study materials link for
that.

## Examples

``` r
if (FALSE) { # \dontrun{
# Fearon & Laitin: registry stub supplies paper.article_url
paper_article_url(doi = "10.1017/S0003055403000534")
paper_article_url(doi = "10.1017/S0003055422000284")
paper_article_url(doi = "10.1257/aer.91.5.1369")
st <- get_study("10.1017/S0003055403000534")
paper_article_url(doi = st$doi)
} # }
```
