# Resolve Shiny feedback CSV to an absolute path

Relative paths are resolved against
[`shiny_deploy_dir()`](https://replicate-anything.github.io/replicateEverything/reference/shiny_deploy_dir.md)
(the Shiny app deploy directory on shiny2.wzb.eu, e.g.
`.../ipi/replicate/data/feedback.csv`), not the process working
directory when they differ.

## Usage

``` r
shiny_feedback_file_path()
```

## Value

Normalized absolute file path.
