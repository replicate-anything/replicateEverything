# Load only function definitions from a replication script

Skips top-level execution (data load + pipe / legacy interactive
footers) when the package sources the file. Also evaluates safe
top-level constants referenced by sourced helper functions. Authors only
need pure `make_*` / `format_*` definitions;
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
supplies the execute recipe from `replication.yml`.

## Usage

``` r
source_replication_functions(path, env, install_deps = FALSE, visited = NULL)
```

## Arguments

- path:

  Path to an R script.

- env:

  Environment in which to define functions.

- install_deps:

  Logical. Passed to dependency retry helper.

- visited:

  Optional environment memoizing normalized paths already sourced.
