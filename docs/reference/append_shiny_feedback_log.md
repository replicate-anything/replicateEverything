# Append one sanitized feedback record to the server CSV log

Writes to `data/feedback.csv` by default (relative to the Shiny app
deploy directory). Creates the parent `data/` directory when needed.
Columns: `timestamp`, `category`, `email`, `text`.

## Usage

``` r
append_shiny_feedback_log(
  category,
  text,
  email = NULL,
  file = shiny_feedback_file_path()
)
```

## Arguments

- category:

  Allowlisted category.

- text:

  Sanitized plain-text feedback.

- email:

  Optional sanitized email.

- file:

  CSV path; default from
  [`shiny_feedback_file_path()`](https://replicate-anything.github.io/replicateEverything/reference/shiny_feedback_file_path.md).

## Value

Logical: `TRUE` when written.
