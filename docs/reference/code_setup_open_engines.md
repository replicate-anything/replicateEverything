# Engines to mention in the local setup open instruction

Uses the active replication language for the current table or figure;
falls back to the sole declared study language when the active language
is unknown.

## Usage

``` r
code_setup_open_engines(language, study_engines = NULL)
```

## Arguments

- language:

  Active replication language (`r`, `stata`, `python`).

- study_engines:

  Declared study languages from `replication.yml`.
