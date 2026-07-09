# Report progress to UIs (Shiny) and the R console

Invokes `getOption("replicateEverything.progress")` when set, and also
emits a [`message()`](https://rdrr.io/r/base/message.html) so console
users see the same text.

## Usage

``` r
replicate_progress(msg)
```

## Arguments

- msg:

  Character status line.
