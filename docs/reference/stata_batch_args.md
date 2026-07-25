# Stata command-line arguments for non-interactive do-file execution

Windows: `/e /i /q do file.do`. Unix/Linux/macOS: `-b -q file.do`.

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

On Windows, `/e` exits when the job finishes (no end-of-job OK click).
`/i` suppresses the Stata taskbar icon (Stata Getting Started with
Windows (GSW) manual B.5). Without `/i`, the icon appears for the whole
run; clicking it opens "cancel the batch job?", which injects
`--Break--` / `r(1)` and then cascades "Would you like the batch job to
continue?" dialogs as nested do-files unwind. `/q` suppresses the logo.
Paths with spaces are shortened on Windows when possible.
