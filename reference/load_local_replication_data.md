# Load replication data from local paths (for self-contained scripts)

Used at the bottom of replication scripts so they can be run directly
from the paper folder without the package orchestrator.

## Usage

``` r
load_local_replication_data(data_paths, paper_dir = getwd())
```

## Arguments

- data_paths:

  Character vector of paths relative to the paper folder.

- paper_dir:

  Paper root directory. Defaults to current working directory.

## Value

A data frame, list, or other object.

## Examples

``` r
tmp <- tempfile()
dir.create(tmp)
dir.create(file.path(tmp, "data"))
write.csv(
  data.frame(x = 1:3, y = 4:6),
  file.path(tmp, "data", "example.csv"),
  row.names = FALSE
)
load_local_replication_data("data/example.csv", paper_dir = tmp)
#> Error in load_local_replication_data("data/example.csv", paper_dir = tmp): could not find function "load_local_replication_data"
```
