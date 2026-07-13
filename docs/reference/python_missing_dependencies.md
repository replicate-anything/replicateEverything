# Dependencies not importable by the target Python

Probes with `python -c "import ..."`. Tries all imports at once first
(fast path when everything is already installed); only when that fails
does it probe each dependency individually to identify the missing ones.
This lets callers skip `pip install` entirely when packages are already
present – avoiding redundant local installs and spurious failures on
locked-down servers that forbid `pip`.

## Usage

``` r
python_missing_dependencies(python, deps)
```

## Arguments

- python:

  Path to the Python executable.

- deps:

  Character vector of PyPI dependency specs.

## Value

Character subset of `deps` that are not importable.
