# replicateEverything: Reproduce Empirical Research Results

The `replicateEverything` package provides tools for discovering and
executing computational replications of empirical research papers. It
connects to a public replication registry containing metadata,
replication scripts, and processed datasets required to reproduce
figures and tables from published studies.

## Workflow

A typical workflow using the package is:

1.  Retrieve metadata for a paper using
    [`get_doi_metadata()`](https://replicate-anything.github.io/replicateEverything/reference/get_doi_metadata.md).

2.  Search the replication registry using
    [`search_papers()`](https://replicate-anything.github.io/replicateEverything/reference/search_papers.md).

3.  Create a template for contributing a replication using
    [`create_replication_template()`](https://replicate-anything.github.io/replicateEverything/reference/create_replication_template.md).

4.  Inspect available replications using
    [`list_replications()`](https://replicate-anything.github.io/replicateEverything/reference/list_replications.md).

5.  Run a single replication using
    [`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md).

6.  Reproduce all results from a paper using
    [`replicate_paper()`](https://replicate-anything.github.io/replicateEverything/reference/replicate_paper.md).

## Examples

Retrieve metadata for a paper:

get_doi_metadata("10.1177/00491241211036161")

Search the registry:

search_papers("causal")

Create a replication template:

create_replication_template("10.1177/00491241211036161")

List replications:

list_replications("10.1177/00491241211036161")

Run a single replication:

run_replication("10.1177/00491241211036161","fig_1")

Replicate an entire paper:

replicate_paper("10.1177/00491241211036161")

## Registry

Replication metadata and materials are stored in the public registry:
<https://github.com/replicate-anything/registry>.

## See also

Useful links:

- <https://github.com/replicate-anything/replicateEverything>

- <https://replicate-anything.github.io/replicateEverything/>

- Report bugs at
  <https://github.com/replicate-anything/replicateEverything/issues>

## Author

**Maintainer**: Vermon Washington <vermon.washington@wzb.eu>

Authors:

- Macartan Humphreys <macartan.humphreys@wzb.eu>
