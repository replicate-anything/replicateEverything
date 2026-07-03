# Convert a Stata SMCL file to HTML for display

Uses Stata's `translate` command when available; otherwise wraps raw
SMCL in a monospace block.

## Usage

``` r
smcl_to_html(smcl_path)
```

## Arguments

- smcl_path:

  Path to an `.smcl` file.

## Value

Character scalar containing HTML.
