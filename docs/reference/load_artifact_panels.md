# Load every displayable panel for a replication

Returns a single loaded artifact when there is one panel, or a character
vector / list of loaded panels when `outputs:` lists several displayable
sinks (png/html/svg/xlsx). Prep/transform steps use
[`load_artifact()`](https://replicate-anything.github.io/replicateEverything/reference/load_artifact.md)
(via
[`load_prep_step_display()`](https://replicate-anything.github.io/replicateEverything/reference/load_prep_step_display.md))
so `.done`/ `.dta`/`.csv` sinks are summarized or previewed instead of
falling through to remote `outputs/<id>.html` HTTP 404s.

## Usage

``` r
load_artifact_panels(doi, what, repo = NULL, folder = NULL, language = NULL)
```

## Arguments

- doi:

  Character. DOI of the paper.

- what:

  Character. Replication identifier (logical id, e.g. `"tab_1"`).

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

- language:

  Optional `"R"` or `"stata"`.
