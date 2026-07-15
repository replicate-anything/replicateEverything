# GitHub zip download URL for a study repository

GitHub zip download URL for a study repository

## Usage

``` r
github_repo_zip_url(repo_slug, ref = "main")
```

## Arguments

- repo_slug:

  Character scalar `org/repo`.

- ref:

  Branch or tag name (default `main`).

## Value

Character scalar URL, or `NA_character_` when `repo_slug` is empty.
