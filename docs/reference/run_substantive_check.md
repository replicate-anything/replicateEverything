# Run a study substantive check on a replication result

Run a study substantive check on a replication result

## Usage

``` r
run_substantive_check(
  object,
  doi,
  what,
  study_root = NULL,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- object:

  Analysis object returned by
  [`render_replication()`](https://replicate-anything.github.io/replicateEverything/reference/render_replication.md).

- doi:

  Study DOI or registry handle.

- what:

  Replication step id.

- study_root:

  Optional study repository root. Resolved from `doi` when omitted.

- repo:

  Optional registry repo slug.

- folder:

  Optional registry folder name.

## Value

List with `checked` (logical), `ok` (logical or `NA`), and `message`
(character).
