# List bundled AI skills

Returns skill names (without `.md`) for markdown files shipped under
`inst/ai/skills/` in the installed package.

## Usage

``` r
ai_skills(package = "replicateEverything")
```

## Arguments

- package:

  Optional package name. Defaults to `replicateEverything`.

## Value

A character vector of available AI skill names.

## Examples

``` r
if (FALSE) { # \dontrun{
ai_skills()
} # }
```
