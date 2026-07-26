# Whether the Shiny app appears to be running on the WZB IPI host

Returns `TRUE` when any checked path contains the durable host marker
`/wzb/samba/user/ipi/` (covers both the package library and
`ShinyApps/replicate`). Override with `REPLICATE_SHINY_FEEDBACK=1`
(force on) or `=0` (force off) for local testing.

## Usage

``` r
shiny_running_on_wzb()
```

## Value

Logical scalar.
