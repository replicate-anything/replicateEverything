# Resolve Shiny deploy destination directory

When `dest` is a relative path that already matches the tail of
[`getwd()`](https://rdrr.io/r/base/getwd.html) (e.g. cwd is
`.../shiny_apps/replicate` and `dest` is `"shiny_apps/replicate"`),
returns [`getwd()`](https://rdrr.io/r/base/getwd.html) so files are not
written into a nested subfolder.

## Usage

``` r
resolve_shiny_deploy_dest(dest = getwd())
```

## Arguments

- dest:

  Target directory; default current working directory.

## Value

Normalized absolute path.
