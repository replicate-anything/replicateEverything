# Collect upstream transform step ids required by display steps

Collect upstream transform step ids required by display steps

## Usage

``` r
collect_required_prep_ids(meta, replications)
```

## Arguments

- meta:

  Parsed replication metadata.

- replications:

  List of display step entries.

## Value

Character vector of ancestor step ids in DAG order.
