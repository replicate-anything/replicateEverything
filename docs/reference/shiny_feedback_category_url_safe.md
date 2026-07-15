# Safe GitHub category URL (package helper or hardcoded fallback)

Never errors when `shiny_feedback_github_category_url` is missing.

## Usage

``` r
shiny_feedback_category_url_safe(category, repo = SHINY_FEEDBACK_GITHUB_REPO)
```

## Arguments

- category:

  Allowlisted category.

- repo:

  GitHub `owner/repo` slug.

## Value

Character URL.
