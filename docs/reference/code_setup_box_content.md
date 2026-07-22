# Plain-text content for the Shiny Code tab setup box

Returns a list of strings suitable for UI rendering and unit tests.
Content updates with study, replication step, and engine.

## Usage

``` r
code_setup_box_content(
  doi = NULL,
  repo_slug = NULL,
  language = "r",
  study_engines = NULL,
  meta = NULL,
  audit = NULL,
  step_id = NULL,
  repo = NULL,
  folder = NULL
)
```

## Arguments

- doi:

  Study DOI or handle.

- repo_slug:

  Optional `org/repo` slug (inferred from metadata when omitted).

- language:

  Active replication language.

- study_engines:

  Declared study languages (inferred when omitted).

- meta:

  Optional parsed metadata (loaded from `doi` when omitted).

- audit:

  Optional
  [`check_study_compatibility()`](https://replicate-anything.github.io/replicateEverything/reference/check_study_compatibility.md)
  result.

- step_id:

  Replication or prep step id.

- repo, folder:

  Optional registry row hints.

## Value

List with `title`, `step1`, `step2`, `step2_prep`, `step3`, `one_liner`,
`repo_slug`, `repo_url`, and `zip_url`.
