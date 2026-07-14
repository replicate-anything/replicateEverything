# Keep Stata path globals rooted in the study directory

Code linking resolves `do` paths against `study_root`. If `maindir` (or
paths derived from it) point outside that root — e.g. a materialized
cache directory — links are marked `outside_root` and rendered with
strikethrough in Shiny.

## Usage

``` r
clamp_stata_path_globals_to_study(globals, study_root)
```
