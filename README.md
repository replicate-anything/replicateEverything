# replicateEverything


# replicateEverything

A platform for **reproducing academic research results programmatically
and simply**.

The package allows users to reproduce figures and tables from academic
papers using a standardized way by structuring the replication
repository in special way and adding it to a registry.

The goal is to make research **transparent, modular, and easily
reproducible**.

------------------------------------------------------------------------

## Overview

`replicateEverything` provides a simple interface to:

- search replication-ready papers
- retrieve replication repositories
- reproduce figures and tables
- run full paper replications

The system is built around a **registry architecture** where replication
repositories are indexed and accessed dynamically, making it easier for
academics papers to be **replicated in one line of code.**

------------------------------------------------------------------------

## Installation

Install the development version from GitHub by using `remotes` and
`devtools`.

``` r
if (!requireNamespace("replicateEverything", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  remotes::install_github("replicate-anything/replicateEverything")
}
```

# Load Package

Load the package in your environment.

``` r
library(replicateEverything)
```

## How the Package Works

The package in this very early version allows users to search for papers
in the repository, find the replication repository for a paper, talk
look at the list of existing replications, reproduce a specific result
(e.g. **Fig.1**), reproduce all outputs (i.e. **Fig.1**, **Fig.2**,
**Table 1**, etc).

## Functions

The following fuctions allows you do execute the aim of the package.

### Search Papers

To search papers, you should run the command below. You have to specify
closely associated words with the paper.

``` r
# first option 
search_papers("causes")
```

                            doi                                     title
    1 10.1177/00491241211036161 Bounding Causes of Effects With Mediators
                 authors year                             journal
    1 Macartan Humphreys 2022 Sociological Methods &amp; Research
                             repo
    1 replicate-anything/registry

``` r
# second option 
search_papers("effects")
```

                            doi
    1 10.1177/00491241211036161
    2     10.1515/jci-2024-0040
                                                                                              title
    1                                                     Bounding Causes of Effects With Mediators
    2 Bounds on the fixed effects estimand in the presence of heterogeneous assignment propensities
                 authors year                             journal
    1 Macartan Humphreys 2022 Sociological Methods &amp; Research
    2                    2025         Journal of Causal Inference
                             repo
    1 replicate-anything/registry
    2 replicate-anything/registry

``` r
# third option
search_papers("mediators")
```

                            doi                                     title
    1 10.1177/00491241211036161 Bounding Causes of Effects With Mediators
                 authors year                             journal
    1 Macartan Humphreys 2022 Sociological Methods &amp; Research
                             repo
    1 replicate-anything/registry

You can use many **key words** to search from the **title** of a paper
to see if it is in the directory.

### Find Replication Repository

The way the package is set up now, researchers will have to outline
their Github repository is an aligned way to allows it to be merge into
the [Registry](https://github.com/replicate-anything/registry). More
details on this later. However, you can use the `find_repo` function and
the paper’s `DOI` to located and look up a paper’s repository from the
registry.

``` r
# find repo
find_repo("10.1177/00491241211036161")
```

    [1] "replicate-anything/registry"

### List Repository

The `list_replications` function allows you to look up **structures** in
an uploaded repository. It also allows you to see some important $id$
that are subsequently used in key replication functions in the package,
for example `fig_1`.

``` r
list_replications("10.1177/00491241211036161")
```

    [1] "https://raw.githubusercontent.com/replicate-anything/registry/main/papers/10.1177_00491241211036161/replication.yml"

    [[1]]
    [[1]]$id
    [1] "fig_1"

    [[1]]$type
    [1] "figure"

    [[1]]$description
    [1] "Example figure"

    [[1]]$data
    [1] "processed/fig_1.csv"

    [[1]]$code
    [1] "code/fig_1.R"

### Run Replication

The `run_replication` function allows you to run **single** replication
for a specific table or figure. This must have already be specified in
the root directory on Github. More details on this later when discussing
directory.

``` r
run_replication(
  "10.1177/00491241211036161",
  "fig_1"
)
```

    [1] "fig_1"

    Using repository: replicate-anything/registry

    Replication type: figure

    Ignoring unknown labels:
    • shape : "ρ"

![](README_files/figure-commonmark/unnamed-chunk-6-1.png)

### Replicate Paper

This is the **single most important function** in this
`replicateEverything` package. It allows you to replicate an entire
paper. With a single line of code, you can be able to generate all
figures at one go. See how it works below:

#### option A

``` r
replicate_paper("10.1177/00491241211036161")
```

    Replicating: Bounding Causes of Effects With Mediators

    Running: fig_1

    Ignoring unknown labels:
    • shape : "ρ"

![](README_files/figure-commonmark/unnamed-chunk-7-1.png)

## System Architecture

``` mermaid

flowchart LR
  A[Registry] --> B(Replication Repositories)
  B --> C{replicateEverything}
```

### Registry

The registry indexes all replication repositories. See an example entry:

    #| include: false

        "doi": "10.1257/aer.20221688",
        "title": "Market Design and Moral Behavior",
        "authors": ["Bartling", "Fehr"],
        "year": 2024,
        "journal": "American Economic Review",
        "repo": "replicate-anything/aer-replications"

### Repositories Structures

Every replication repository **MUST** follows a standardized structure.
All data must be store in `processed` folder. All code must be stored in
the `code` folder.


    papers/
       DOI/
          replication.yml
          processed/
             fig_1.csv
             tab_1.csv
          code/
             fig_1.R
             tab_1.R

#### Example

See the example below for structure of a repo for a single figure. This
should similarly work for a single table as well. The repo should have
the data and code as seen below.


    papers/
       10.1257_aer.20221688/
          replication.yml
          processed/
             fig_1.csv
          code/
             fig_1.R

## Metadata Specification

Each paper must include a metadata file.

    replication.yml

### Example

Ideally, make sure to include if a table has `dependencies`.


    paper:
      title: Market Design and Moral Behavior
      authors:
        - Bartling, Björn
        - Fehr, Ernst
      year: 2024
      doi: 10.1257/aer.20221688
      journal: American Economic Review

    replications:

      - id: fig_1
        type: figure
        description: Example figure
        data: processed/fig_1.csv
        code: code/fig_1.R

      - id: tab_1
        type: table
        description: Example table
        data: processed/tab_1.csv
        code: code/tab_1.R
        dependencies:
          - dplyr
          - gt

## Contributor’s Workflow

### Step 1: Get DOI Metatdata

``` r
get_doi_metadata("10.1177/00491241211036161")
```

    $title
    [1] "Bounding Causes of Effects With Mediators"

    $journal
    [1] "Sociological Methods &amp; Research"

    $year
    [1] 2022

    $authors
    [1] "Philip Dawid"       "Macartan Humphreys" "Monica Musio"      

### Step 2: Create Template

This create a folder on your local machine. Now, you will have to upload
the final processed data used for generating the figure as well as the
code in their exact areas. Read the `Writing Scripts` section below for
how to include the `generate` function into your code.

``` r
#create a local folder 
create_replication_template("10.1177/00491241211036161")
```

    Replication template created at: 10.1177_00491241211036161

``` r
#see what is in there. 
list_replications("10.1177/00491241211036161")
```

    [1] "https://raw.githubusercontent.com/replicate-anything/registry/main/papers/10.1177_00491241211036161/replication.yml"

    [[1]]
    [[1]]$id
    [1] "fig_1"

    [[1]]$type
    [1] "figure"

    [[1]]$description
    [1] "Example figure"

    [[1]]$data
    [1] "processed/fig_1.csv"

    [[1]]$code
    [1] "code/fig_1.R"

### Step 3: Clone the Registry Repository from Github

Now, clone the Git repo:

    git clone https://github.com/replicate-anything/registry

### Step 4: Move local folder to Github cloned repo

At this point, you would have added your data and code to the folder on
your local machine. A good text would be to make sure that you ensure
that the code runs in your `R console`.

    mv 10.1257_app.20230717 registry/papers/

### Step 5: Commit and Push

Commit your changes in the folder and then push them to remotes.

    git add .
    git commit -m "Add replication for 10.1257/app.20230717"
    git push

### Step 6: Open a Pull Request.

That’s it! Thank you for embracing a **transparent, modular, and easily
reproducible** research culture.

## Writing Replication Scripts

Replications Scripts **must** define the `generate` function. For
figure, use `generate_figure` and for table, use `generate_table`.

### Figures


    generate_figure <- function(data){

      ggplot2::ggplot(data, ggplot2::aes(group,value)) +
        ggplot2::geom_col()

    }

### Tables


    generate_table <- function(data){

      dplyr::summarise(data, mean_value = mean(value))

    }

This allows the the `package` to automatically: \* download the datasets
\* loads dependencies \* sources the script \* runs the function

## Contributing to a Repository

This is a very important aspect in our quest to create a reprocible
research culture so please follow the instructions below keenly:

1.  Fork the replication repository

2.  Add a new paper directory

3.  Provide metadata and scripts

4.  Submit a pull request

See example below:

    papers/10.xxxx_xxxx/

## Developer Workflow

Start by cloning the repository:

    git clone https://github.com/replicate-anything/replicateEverything

Install the dependencies:

    devtools::install()

Run package checks:

    devtools::check()

## Report Bugs

To report bugs or fixes, please create an issues
[here](https://github.com/replicate-anything/replicateEverything/issues).

# Project Status

This idea was conceived and inspired by [Macartan
Humphreys](https://macartan.github.io), Director of the IPI Research
Unit at [WZB](https://www.wzb.eu) in 2024. The project is under active
development at the moment. All feedback are welcome. Feel free to [email
me](mailto:vermon.washington@wzb.eu) or
[Marcatan](mailto:macartan.humphreys@zwb.eu).
