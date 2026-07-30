# Selector language that uniquely identifies one path among siblings

Prefers a language token that appears in this entry's path languages but
not in every sibling (so `"r"` vs `"mathematica"` for Stata+R /
Stata+Mathematica pairs). Falls back to the dispatch engine.

## Usage

``` r
path_selector_language(entry, siblings = list())
```
