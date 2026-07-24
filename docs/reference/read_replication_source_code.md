# Read raw replication runner code (no inlining)

Read raw replication runner code (no inlining)

## Usage

``` r
read_replication_source_code(
  doi,
  what,
  language = NULL,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Character. DOI of the paper, registry handle, or local study path.
  Pass `"local"` to read code from the study in the current working
  directory — no registry lookup is needed; see
  [`resolve_doi_input()`](https://replicate-anything.github.io/replicateEverything/reference/resolve_doi_input.md).

- what:

  Character. Replication identifier (logical id).

- language:

  Optional `"R"` or `"stata"`.

- repo:

  Optional repository slug.

- folder:

  Optional registry folder name from `index.csv`.

## Value

Character vector of lines from the runner script.
