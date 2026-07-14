# Render code lines with clickable file links for Shiny

Render code lines with clickable file links for Shiny

## Usage

``` r
render_code_html_with_links(
  lines,
  language = c("stata", "r"),
  study_root,
  source_path = NULL,
  globals = NULL
)
```

## Arguments

- lines:

  Character vector of code lines.

- language:

  `"stata"` or `"r"`.

- study_root:

  Study root directory.

- source_path:

  Relative path of the file within the study (for relative resolution).

- globals:

  Named Stata globals.

## Value

List with `html`, `links` (JSON-ready list), `lines`.
