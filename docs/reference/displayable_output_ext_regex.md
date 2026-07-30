# Regex for `outputs:` paths that Shiny Display can open

Includes spreadsheet sinks (Hahn `tab_1`/`tab_2` `.xlsx`) and tabular
prep sinks (`.csv`/`.dta`/`.tab`) so lookup does not fall through to a
non-existent `outputs/<id>.html`. Marker sinks (`.done`) are handled
separately via
[`load_prep_step_display()`](https://replicate-anything.github.io/replicateEverything/reference/load_prep_step_display.md).

## Usage

``` r
displayable_output_ext_regex()
```
