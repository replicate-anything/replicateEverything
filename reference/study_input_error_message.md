# User-facing hint when a DOI or study-path lookup fails

User-facing hint when a DOI or study-path lookup fails

## Usage

``` r
study_input_error_message(
  kind = c("path", "cwd", "empty", "doi", "generic"),
  path = NULL,
  input = NULL
)
```

## Arguments

- kind:

  Failure kind: `path`, `cwd`, `empty`, `doi`, or `generic`.

- path:

  Optional path string entered by the user.

- input:

  Optional raw input string.

## Value

Multi-line character message.
