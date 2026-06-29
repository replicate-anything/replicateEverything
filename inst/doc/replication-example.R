## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  fig.width = 8,
  fig.height = 6,
  dpi = 150
)

## ----setup--------------------------------------------------------------------
library(replicateEverything)


## ----fig_1_example, echo=FALSE, fig.width=6, fig.height=4, out.width="70%", fig.align="center", eval = FALSE----
# 
# suppressPackageStartupMessages(
#   library(DiagrammeR)
# )
# 
# DiagrammeR::grViz("
# digraph {
#   Registry -> 'Replication Repositories'
#   'Replication Repositories' -> replicateEverything
# }
# ")
# 

## ----eval = FALSE-------------------------------------------------------------
# run_replication(
#   "10.1177/00491241211036161",
#   "fig_1"
# )

## ----eval = FALSE-------------------------------------------------------------
# replicate_paper("10.1177/00491241211036161")

