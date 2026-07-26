# Structured data-unavailability class from yaml (e.g. proprietary)

Reads `data_unavailable:` (or legacy `unavailable_reason:` /
`requires_data:`) on an incomplete step. Tokens are lower-case
(`proprietary`, `restricted`, `missing`, ...).

## Usage

``` r
step_data_unavailable(entry)
```
