# Load only function definitions from a replication script

Skips the self-run footer so top-level execution (data load + pipe) does
not run when the package sources the file.

## Usage

``` r
source_replication_functions(path, env, install_deps = FALSE)
```

## Arguments

- path:

  Path to an R script.

- env:

  Environment in which to define functions.

- install_deps:

  Logical. Passed to dependency retry helper.
