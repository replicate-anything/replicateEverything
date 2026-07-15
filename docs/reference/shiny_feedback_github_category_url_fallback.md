# Hardcoded GitHub new-issue URL when package helpers are unavailable

Used by the Shiny Feedback tab when `shiny_feedback_github_category_url`
is missing from a stale worker namespace (no dynamic package lookup).

## Usage

``` r
shiny_feedback_github_category_url_fallback(
  category,
  repo = SHINY_FEEDBACK_GITHUB_REPO
)
```

## Arguments

- category:

  Allowlisted category.

- repo:

  GitHub `owner/repo` slug.

## Value

Character URL.
