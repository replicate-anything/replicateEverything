# Whether script lines call make\_() outside its definition

Used to verify table/figure scripts expose an executable replication
path (footer that builds and optionally formats the display object).

## Usage

``` r
script_has_make_call(lines, what)
```

## Arguments

- lines:

  Character vector of script lines.

- what:

  Replication identifier.

## Value

Logical scalar.
