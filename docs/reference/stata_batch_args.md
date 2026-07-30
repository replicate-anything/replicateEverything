# Stata command-line arguments for non-interactive do-file execution

Windows: `/q do file.do`. Unix/Linux/macOS: `-b -q file.do`.

## Usage

``` r
stata_batch_args(do_path)
```

## Arguments

- do_path:

  Path to the do-file.

## Value

Character vector of arguments for
[`system2()`](https://rdrr.io/r/base/system2.html).

## Details

On Windows we deliberately avoid `/e` and `/b`. Those flags put Stata
into batch mode, which *silently ignores* `shell` / `winexec` ("request
ignored because of batch mode"). That breaks any study that shells out
(Hahn LBD `shell Rscript`, Wolfram, etc.). StataCorp's recommended
workaround is a normal `do` launch with `exit, clear STATA` at the end
of the generated runner (see
[`stata_runner_lines()`](https://replicate-anything.github.io/replicateEverything/reference/stata_runner_lines.md)).
`/q` suppresses the logo. The GUI is kept off the desktop via processx
`windows_hide` (and a best-effort `window manage minimize` in the
runner). Paths with spaces are shortened on Windows when possible.
