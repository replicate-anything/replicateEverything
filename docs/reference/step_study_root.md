# Study repository root for executing one step

Inherited steps run in the base repo unless their `code` path exists
only in the extension study (e.g. overridden `tab_1_format`).

## Usage

``` r
step_study_root(step, meta, ctx)
```
