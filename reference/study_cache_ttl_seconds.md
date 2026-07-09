# Seconds a study-cache freshness check stays valid within a session

Configurable via `options(replicateEverything.study_cache_ttl)`. A value
of `0` disables the session skip so every resolution re-checks the
remote.

## Usage

``` r
study_cache_ttl_seconds()
```

## Value

Numeric seconds (defaults to 300).
