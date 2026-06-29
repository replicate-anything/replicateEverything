# Extract a plain object from a replication result envelope

Extract a plain object from a replication result envelope

## Usage

``` r
replication_object(x)
```

## Arguments

- x:

  A replication result list or raw object.

## Value

The underlying replication object.

## Examples

``` r
result <- list(id = "fig_1", object = data.frame(x = 1), class = "replication_result")
replication_object(result)
#>   x
#> 1 1
```
