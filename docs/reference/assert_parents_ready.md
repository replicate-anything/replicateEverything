# Check that immediate parents have outputs (given = parents semantics)

Check that immediate parents have outputs (given = parents semantics).
`force` is ignored for readiness: it only recomputes the target in
`execute_study_plan()`, not whether parent sinks must exist.

## Usage

``` r
assert_parents_ready(target_id, graph, ctx, meta, force = FALSE)
```
