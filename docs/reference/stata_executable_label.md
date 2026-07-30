# Human-readable label for a resolved Stata executable path

Derives a short "Stata \<version\> \<edition\>" label from the install
path (e.g. `.../Stata17/StataMP-64.exe` -\> `"Stata 17 MP"`), so
check/install messages make it obvious at a glance whether they resolved
the same Stata. The raw path (always reported alongside) is the ground
truth for programmatic comparison.

## Usage

``` r
stata_executable_label(path)
```

## Arguments

- path:

  Absolute path to a Stata executable, or `NULL`.

## Value

Character scalar, e.g. `"Stata 17 MP (C:/.../StataMP-64.exe)"` or
`"(Stata not found)"`.
