#!/usr/bin/env Rscript
# Regenerate registry/replication.yml + registry/index.csv in each study repo
# from the study-root replication.yml (maintainer, collections, languages).

root <- Sys.getenv("REPLICATE_MONOREPO_ROOT", unset = normalizePath("..", winslash = "/", mustWork = FALSE))
if (!dir.exists(root)) {
  stop("Monorepo root not found: ", root)
}

pkg_root <- file.path(root, "replicateEverything")
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("devtools required")
}
devtools::load_all(pkg_root, quiet = TRUE)

study_dirs <- list.dirs(root, recursive = FALSE, full.names = TRUE)
study_dirs <- study_dirs[grepl("^rep[-_]", basename(study_dirs))]
study_dirs <- study_dirs[file.exists(file.path(study_dirs, "replication.yml"))]

for (study_dir in sort(study_dirs)) {
  message("Syncing ", basename(study_dir))
  written <- replicateEverything:::write_folder_registry_stub(study_dir)
  message("  ", written$stub_path)
  message("  ", written$index_path)
}

message("Done.")
