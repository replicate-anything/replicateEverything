# Epilogue notes for R scripts that define make\_\* but never call it

R-only: commented yaml-implied load \\\rightarrow\\ make \\\rightarrow\\
format recipe. Stata/Python scripts omit this (no fake R call chains).

## Usage

``` r
replication_code_display_epilogue(rep, lines, meta = NULL)
```
