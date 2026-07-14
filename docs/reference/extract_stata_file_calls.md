# Extract Stata file calls from code lines

Extract Stata file calls from code lines

## Usage

``` r
extract_stata_file_calls(lines)
```

## Arguments

- lines:

  Character vector of code lines (may include comments).

## Value

Data frame with columns `line`, `command`, `path`, `match_start`,
`match_end`.
