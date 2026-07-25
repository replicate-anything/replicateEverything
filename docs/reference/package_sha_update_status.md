# Classify local vs remote package SHAs

Classify local vs remote package SHAs

## Usage

``` r
package_sha_update_status(local_sha, remote_sha)
```

## Arguments

- local_sha:

  Installed `RemoteSha` (or other build SHA).

- remote_sha:

  Latest GitHub commit SHA for the tracked ref.

## Value

One of `"current"`, `"outdated"`, or `"unknown"`.
