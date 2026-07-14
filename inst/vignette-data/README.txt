Vignette snapshot data
======================

This directory holds static assets used when building package vignettes and
pkgdown articles, so builds do not need a live registry or monorepo checkout.

Jiang and Yang (2026) — Figure 4
--------------------------------

Save the Figure 4 PNG from a local run of:

  replicateEverything::run_replication(
    doi = "10.1017/s0003055426101749",
    what = "fig_4"
  )

as:

  inst/vignette-data/jiang_fig_4.png

(relative to the replicateEverything package root).

The why-replicateEverything vignette displays this file via knitr::include_graphics().
