# Current commit SHA for a GitHub repository ref

Queries the GitHub API for the commit SHA of `ref`. Used to decide
whether a cached study checkout is stale. Returns `NA_character_` when
the SHA cannot be determined (offline, rate-limited, or missing ref), in
which case callers keep any existing cache rather than failing.

## Usage

``` r
github_ref_sha(repo, ref = "main")
```

## Arguments

- repo:

  GitHub slug `org/repo`.

- ref:

  Branch, tag, or commit.

## Value

Character SHA or `NA_character_`.
