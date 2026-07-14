# Build a code dependency graph from an entry script

Parses `do`/`source` calls recursively. Cached paths are not re-read.

## Usage

``` r
build_code_file_graph(
  entry_path,
  study_root,
  language = c("stata", "r"),
  read_fn = NULL,
  cache = NULL
)
```

## Arguments

- entry_path:

  Relative path within study root.

- study_root:

  Absolute study root.

- language:

  `"stata"` or `"r"`.

- read_fn:

  Function(path) -\> lines; defaults to `readLines`.

- cache:

  Optional environment for memoization.

## Value

List with `nodes` (path -\> lines), `edges` (from -\> to paths),
`globals`.
