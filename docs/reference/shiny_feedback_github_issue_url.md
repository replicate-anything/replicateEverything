# Build a GitHub new-issue URL for Shiny feedback

Build a GitHub new-issue URL for Shiny feedback

## Usage

``` r
shiny_feedback_github_issue_url(
  category,
  text,
  email = NULL,
  repo = "replicate-anything/replicateEverything"
)
```

## Arguments

- category:

  Allowlisted category (`bug`, `feature`, `other`).

- text:

  Sanitized plain-text body.

- email:

  Optional sanitized contact email.

- repo:

  GitHub `owner/repo` slug.

## Value

Character URL, or `""` when the category is invalid.
