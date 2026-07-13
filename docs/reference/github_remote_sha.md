# Latest commit SHA for a GitHub repo ref

Uses the GitHub REST API (not `remotes`) so version checks work on
servers where
[`remotes::remote_sha()`](https://remotes.r-lib.org/reference/install_remote.html)
fails on temp paths.

## Usage

``` r
github_remote_sha(repo, ref = "main")
```

## Arguments

- repo:

  GitHub slug `org/repo`.

- ref:

  Branch, tag, or commit.
