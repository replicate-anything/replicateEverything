# Run a replication script footer when executed directly

Scripts normally use an `if/else` footer:
`generate_figure <- make_fig_1(read.csv(...))` when run directly, and
`generate_figure <- make_fig_1` when sourced by the package.

## Usage

``` r
self_run(make_fn, data_paths, paper_dir = getwd())
```

## Arguments

- make_fn:

  Function that accepts `data`.

- data_paths:

  Paths relative to the paper folder.

- paper_dir:

  Paper root directory.
