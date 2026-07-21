# replicateEverything 0.6.10

## get_code modes and usage tip

* [get_code()] gains `mode = c("definitions", "run")` (default
  `"definitions"`). `"run"` ungates an `sys.nframe() == 0` footer or appends a
  yaml-implied load → make → format expression so `eval(parse(text = ...))`
  can produce the object (study root as working directory).
* Calling [get_code()] prints a short tip tailored by engine and step type
  (R: prefer [run_replication()], `mode = "run"` then eval, or Source the
  manual footer; Stata/Python: analogous guidance without assuming R).
  Suppress with `options(replicateEverything.quiet_get_code = TRUE)`.

# replicateEverything 0.6.9

## Live Run by default

* [run_replication()] now defaults to **`force = TRUE`**: the requested step
  always recomputes. Display / [load_artifact()] still use precomputed
  `outputs/` files. Set `force = FALSE` to reuse existing **upstream**
  outputs when present; the target step still runs live.
* [execute_study_plan()] never skips the target step as "Using existing
  output" (that message is only for non-target ancestors when
  `force = FALSE`).

# replicateEverything 0.6.8

## Display paths from `outputs:` only

* Folder-backed (and package) studies declare display products under
  **`outputs:`** only. The redundant **`artifact:`** field is no longer
  documented; [study_artifact_rel_path()] prefers the first displayable
  `outputs:` path (html/png/rds/svg) and treats `artifact:` as a deprecated
  fallback for older yaml.
* Skills, README, Shiny Contribute examples, and fixtures updated accordingly.

# replicateEverything 0.6.7

## Registry stubs from study yaml (no study-local handoff)

* [sync_study_to_registry()] builds the registry stub from the study root
  `replication.yml` and writes **only** into the registry checkout
  (`studies/<folder>.yml` + rebuilt `index.csv`). Study repos no longer need a
  `registry/` or `inst/registry/` handoff folder.
* [prepare_study_for_registry()] validates / optionally builds outputs; does not
  write study-local stubs by default (`write_handoff = TRUE` keeps the legacy
  path). [add_folder_paper()] / [add_paper()] likewise sync without writing
  handoff into the study.
* Folder stubs include `study_handle` (and related fields) when the study has no
  article DOI. Skill `include_study_in_registry.md` updated.
* [check_replication()] live Run for folder studies uses `study_handle` when
  there is no article DOI (fixes length-zero DOI lookup). Analysis objects are
  kept unformatted so substantive checks receive models, not HTML.

# replicateEverything 0.6.6

## Shiny welcome modal reactive-context fix

* Fixed crash on session start: `session$onFlushed` called `invalidateLater()` and read `session$clientData` outside a reactive consumer. Delay is armed with `isolate(welcome_defer_until(...))`; `invalidateLater` and the modal run only inside `observe()`. Deep-link queue writes use `isolate()`; one-shot flags are a plain environment (safe from nested callbacks).

# replicateEverything 0.6.4

## Audit runtime categories and Shiny Run advice

* [audit_everything()] records `runtime_category` (`short` / `medium` / `slow`) from elapsed seconds (thresholds: &lt;30s, &lt;5min, else slow).
* Shiny **Run** uses the registry `audit_latest.rds` snapshot when available: button tooltips and the live-run progress message advise expected time.

## Table/figure code display path

* Shiny Code tab annotates entry scripts with upstream prep/input notes and, when missing, an expected `make_*()` → format path.
* [check_replication()] flags R table/figure scripts that define `make_*` but never call it (scripts should show the executable replication path, not only helpers).

## Re-enable Shiny feedback via baked deploy options

* [save_local_shiny()] defaults to `feedback_enabled = TRUE` and bakes `live_run` / feedback into `deploy-options.R` **and** a marker block in the materialized `app.R` (no `local.R` required).
* [run_shiny_app()] keeps feedback off for interactive use; Live Run remains available.
* In-app form follows `feedback_enabled` when `feedback_in_app_enabled` is unset. See `inst/shiny/FEEDBACK_TODO.md`.

# replicateEverything 0.6.3

## Shiny feedback — safe mode for stale workers

* **Feedback tab** no longer crashes when Shiny workers hold a stale package namespace (e.g. missing `shiny_feedback_github_category_url` on 0.6.2 workers). GitHub issue links use hardcoded fallbacks.
* **In-app feedback form** (text box + submit) disabled by default; enable with `options(replicate_shiny.feedback_in_app_enabled = TRUE)` once workers reload reliably.
* **Defaults** — `save_local_shiny()` and `write_shiny_deploy_options()` now set `feedback_enabled = FALSE`; CSV logging requires an explicit opt-in.
* See `inst/shiny/FEEDBACK_TODO.md` for re-enable steps.

# replicateEverything 0.6.2

## Shiny feedback and deploy config

* **Feedback tab** — server-side CSV logging (`data/feedback.csv` by default), GitHub issue links, sanitization, and cooldown. Helpers live in `R/shiny_feedback.R`.
* **Deploy config** — `save_local_shiny()` writes `deploy-options.R` with `replicate_shiny.live_run`, `replicate_shiny.feedback_enabled`, and `replicate_shiny.feedback_file`. Startup order is always `deploy-options.R` then `local.R` (manual `run_shiny_app()` and Shiny Server/proxy sessions).
* **Path resolution** — feedback CSV paths resolve against `replicate_shiny.app_dir` / `SHINY_APP_DIR`, not `getwd()` when they differ.
* **Feedback tab footer** — when logging is enabled, shows the resolved CSV path for debugging.
* **[package_deploy_diagnostics()]** — prints installed package version, library path, `.libPaths()`, deploy `BUNDLE_SHA`, and whether key functions exist; use on the Shiny host before/after `save_local_shiny()`.
* **Deploy stamp** — `deploy-options.R` records package version, SHA, and install path at deploy time; Shiny footer shows loaded `lib` path and warns when deploy stamp differs from runtime library.

# replicateEverything 0.6.1

## Maintainer helpers and Shiny polish

* **[build_outputs()]** — registry-wide or single-study batch build of precomputed table/figure outputs (`doi = "everywhere"`, `location`, `only_missing`, `force_prep`). Mirrors [validate_outputs()] dispatch.
* **[validate_outputs()]** — exported maintainer check that declared outputs exist on disk without running live replications.
* **Code links** — `R/code_links.R` resolves `code:` file references in replication scripts; Shiny code viewer renders clickable links; [check_replication()] runs **`check_code_links()`** and reports broken links.
* **Author display** — `R/author_display.R` parses comma-separated author lists and formats study labels (`format_author_label()`, `format_authors_summary()`) for Shiny dropdowns and details.
* **Dataverse prep display** — prep steps that fetch a deposit show a structured summary in Shiny when no HTML artifact exists (`load_prep_step_display()`).
* **Server path fixes** — code-link resolution tolerates materialized study caches and Shiny reactive state; paths outside the study root are flagged instead of breaking the viewer.

# replicateEverything 0.6.0

## Public API cleanup

* **Unified contribute API:** [build_study_outputs()] replaces [build_study_artifacts()] and [build_package_artifacts()]; [check_replication()] replaces [check_folder_replication()] and [check_package_replication()]; [validate_outputs()] replaces `validate_artifact()`, `validate_paper_artifacts()`, `validate_study_artifacts()`, and `validate_registry_artifacts()`. Use `doi = "everywhere"` and `what = "everything"` for registry-wide checks. The kind-specific functions remain internal.
* Removed deprecated exports: `list_replication_groups()`, `list_prep_steps()`, `prepare_folder_paper()`, and `sync_folder_paper()`.
* Internal (no longer in Reference): `print(<replication_list>)`, [study_dag_display()], [study_dag_facets()], [study_output_dir()], [migrate_legacy_steps_yaml()], [run_prep_step()], and [replication_kind()].
* [refresh_registry()] moved to the **Registry audit** reference section.

## Step DAG and conditional replication

* Unified **`steps:`** block in `replication.yml` replaces separate `prep:` / `replications:` (legacy blocks still compile automatically).
* [run_replication()] gains **`given`** (`"parents"`, `"nothing"`, or a character vector of assumed-complete steps) and **`force`**. Default `given = "parents"` requires immediate parent outputs to exist and errors if missing.
* Shiny shows a **faceted** pipeline (Tables / figures / standalone paths) with hover labels; step **labels** name outputs.
* Study products live under **`outputs/`** (step-named paths); **`artifacts/`** is no longer used for folder-backed studies.
* **`language`** is optional in [run_replication()] when a replication has only one engine.
* Shiny: collapsible study details (expand after DOI); simplified pipeline key; **Pipeline** tab per object.
* Shiny: fixed study deep links (`?doi=...`) — wait for browser URL before parsing; skip welcome modal when opening a shared link.
* Removed legacy path fallbacks (`artifacts/`, `data/processed/` as implicit output locations). Study repos must declare and write **`outputs/`** paths explicitly.
* Format steps are **`type: format`** children of tables/figures; run via `format = TRUE` unless `format = FALSE`.
* [configure_local_monorepo()] wires registry + sibling study folders for local dev.
* [study_output_dir()] is the preferred name for the display output directory; [study_artifact_dir()] is now internal.
* **Step inheritance** — extension studies declare `paper.extends` and `inherit:` steps; inherited pipeline steps run in the base repo, extension analyses read base `outputs/`. New vignette: `vignette("reanalysis-studies")`. Worked example: Fearon & Laitin reanalysis (`rep-10.1017-S0003055403000534--alt-1`).
* Studies without an article DOI may use **`paper.study_handle`** (registry handle) instead of `paper.doi`.
* **`paper.article_url`** — optional publisher landing page when `https://doi.org/...` fails; [paper_article_url()] and Shiny bibliography links use it. Registry `index.csv` carries `article_url` when set in the stub.
* [list_replications()] gains **`grouped`**, **`include`** (`"display"`, `"pipeline"`, `"all"`), consolidating [list_replication_groups()] and [list_prep_steps()] (both deprecated).
* New overview vignette: **`vignette("why-replicateEverything")`** (first article on the site).
* [list_replications()] gains a compact **print method** (`replication_list` class). `given` defaults to `"nothing"` when `what = "everything"`.
* [audit_everything()] runs published-value checks from `tests/substantive/<step_id>.R` when present (`substantive = TRUE` by default). [check_replication()] reports substantive coverage and runs defined checks when `full_replication = TRUE`. New helper: [check_glm_table_benchmark()] for logit tables. Filter audits with **`collections =`** (e.g. `"APSR"`) or `dois =`.
* Package website: serve from **`docs/` on `main`**; run `Rscript scripts/build_pkgdown.R` locally and commit the full `docs/` tree (not CI). pkgdown CI workflow is manual-only (`workflow_dispatch`).
* Live replication and Shiny **Run** now execute missing **upstream DAG steps** (`parents:`) before tables and figures; Shiny loads merged study metadata for pipeline graphs and handle-only registry entries.
* **Output convention:** transform steps write flat `outputs/<step_id>.<ext>` (e.g. `outputs/analysis_data.rds`); data steps appear in the Shiny sidebar with Display/Run and `head()` kable preview; pipeline labels add **(R)** / **(Stata)** when the same table label appears twice.
* **Registry handoff:** [prepare_study_for_registry()] (contributor) validates a folder- or package-backed study and writes short yaml to `registry/` or `inst/registry/`. [sync_study_to_registry()] and [refresh_registry()] (maintainer) install stubs, rebuild `index.csv`, and optionally rerun [audit_everything()]. New skill: `include_study_in_registry.md`.

# replicateEverything 0.5.1

## Registry index and Shiny

* Registry `index.csv` supports **`collections`**, **`maintainer_name`**, **`maintainer_email`**, and precompiled **`languages`** so the Studies tab does not fetch each study repo on load.
* Shiny study selector uses **bibliographic labels** (`Acemoglu et al (2001)`) sorted by first author and year.
* Studies tab: **collection tags column** (APSR, PED, WB, IPI; max three per row) with legend; **maintainer** link on study details (`[maintainer]` hover).
* Registry study stubs (`studies/*.yml`) now carry **`maintainer`**, **`collections`**, and **`languages`**; [build_registry_index()] compiles `index.csv` from stubs alone.
* Button renamed to **Check system compatibility**.

## Bug fixes

* Shiny footer shows package and app **commit SHA** (`pkg` / `app`) instead of the library install path, so it is easy to see when a deployed `app.R` is stale relative to the installed package. `save_local_shiny()` writes `BUNDLE_SHA` into the deploy directory; a warning banner appears when `app` and `pkg` SHAs differ.
* Fixed Shiny footer crash (`do.call(tag, ...)` — second argument must be a list) from malformed tag construction in `app_build_footer_ui()`.
* `stata_packages:` — auto install and probe from SSC (including `reghdfe` / GitHub conflict handling). Custom `stata_dependencies:` / `stata_deps_probe:` `.do` files are optional for rare cases only.
* Shiny dependency-error UI no longer calls internal `replication_error_message()` as a global function.

## New functions

* [package_build_info()] — version plus GitHub `RemoteSha` or bundled `BUNDLE_SHA`.

# replicateEverything 0.5.0

## Policy

* Exported maintainer API: [check_study_compatibility()], [install_study_dependencies()] (folder + package registry studies), [install_registry_dependencies()], [replication_kind()], [study_artifact_dir()], and [maintainer_dependency_hint()].

## Bug fixes

* Stata dependency checks are **study-declared** via `stata_deps_probe:` (check-only `.do` in the study repo) or `stata_packages:` (generic `which`-only probe). The package no longer hardcodes ftools/reghdfe/estout. Live Run probes only; `install_stata_deps.do` runs only when `options(replicateEverything.install_stata_deps = TRUE)` (e.g. `build_study_artifacts(install_deps = TRUE)`).
* Stata dependency probe and study `install_stata_deps.do` load tests use `help reghdfe` instead of bare `reghdfe` where applicable (study probe script). Invoking `reghdfe` with no data returns r(301) even when installed. When satisfied (as on a typical dev machine), the install script is skipped and Shiny shows "Stata dependencies OK — skipped install". Install runs only when the probe fails. Progress lines are reported via `replicate_progress()` / `options(replicateEverything.progress)` for Shiny's "Working:" banner.
* Stata batch runs honour `timeout` when the suggested **processx** package is installed; overdue runs are killed so Shiny can recover instead of freezing indefinitely. Tune with `options(replicateEverything.stata_timeout)`, `stata_deps_probe_timeout` (default 120s), and `stata_deps_install_timeout` (default 600s). Set `options(replicateEverything.install_stata_deps = FALSE)` to skip study Stata installs entirely.
* Shiny artifact loading no longer passes `install_deps = TRUE` (only live Run installs dependencies).
* Study cache downloads unzip on the same filesystem as the cache directory (not system `/tmp`), so moving the extracted repo into the cache is atomic on Linux servers where `/tmp` and the Samba/NFS cache are on different mounts. The cross-device `file.rename` fallback also uses a single recursive copy and suppresses the EXDEV warning.
* Study Stata dependency scripts (`install_stata_deps.do` etc.) now run at most once per study per session instead of before every prep step and table, so repeated live runs no longer re-trigger a slow SSC reinstall/recompile. A missing-dependency retry still forces a re-run. Set `options(replicateEverything.install_stata_deps = FALSE)` to skip study dependency installation entirely when you manage Stata packages yourself.
* Cached GitHub study checkouts now refresh when the remote commit changes. `materialize_folder_study_from_github()` records the downloaded commit SHA and compares it against the current remote SHA (via the GitHub API); a stale cache (e.g. one built before new data files were committed) is re-downloaded automatically. When the remote SHA cannot be determined (offline or rate-limited) the existing cache is kept. This fixes live Stata/Python runs failing with "file not found" for data that exists in the repo but was missing from an out-of-date server cache. The remote check is on-demand (only when a study is actually run/fetched from GitHub) and is skipped for a short, per-session window after a study is confirmed fresh, so repeated resolutions within one run make at most one API call per study; tune with `options(replicateEverything.study_cache_ttl = <seconds>)` (default 300; 0 to always check).
* Python replications now run from the resolved study folder (the local sibling or the materialized GitHub clone) instead of falling back to the R working directory. On a Shiny server this fixes `FileNotFoundError` where `REPLICATE_STUDY_ROOT` pointed at the app directory (e.g. `ShinyApps/replicate/data/raw/...`) rather than the study repo clone. The Python process now also runs with its working directory set to the study root, matching Stata.
* Python dependency probing uses `importlib.util.find_spec` per package, prefers the Windows `py -0p` launcher installs over Store stubs, and skips `WindowsApps` aliases on PATH. Compatibility UI shows the full Python path probed.
* Renamed bundled skill `APSR_to_replicateEverything` → `dataverse_to_replicateEverything` (Harvard Dataverse deposits generally; `collections: APSR` only when metadata cites *American Political Science Review*). Step 1b now requires downloading the author README from the deposit before scaffolding.

## Breaking changes

* Removed deprecated `replicate_paper()` and `create_replication_template()`. Use `run_replication(doi, "everything")` and the folder/package replication checklists instead.
* Pre-built vignette HTML is shipped again in `inst/doc/` so installs that skip vignette builds still include all articles.

## Documentation

* `get_code()` appears under **Run replications** in the pkgdown reference index.
* **Meet the functions** vignette reorganized into consumer and contributor sections.
* Bundled AI skills under `inst/ai/skills/` with `ai_skills()`, `ai_skill_path()`, and `ai_skill()`.

# replicateEverything 0.4.0

## Public API

* Slim export surface (~14 functions): discovery, run, Shiny, contribute, and audit helpers only.
* `run_replication(doi, what = "everything")` replaces `replicate_paper()` for full-paper runs.
* Registry `index.csv` includes a `handle` column; `search_papers()` and run functions accept handles (e.g. `"bounding-causes"`).
* `validate_replication()` and other internal helpers are no longer exported.
* New vignette: [Meet the functions](articles/meet-the-functions.html).

# replicateEverything 0.3.0

## Folder-backed study workflow

* `build_study_artifacts()` — run replications and write `outputs/` + `manifest.json` from a study repo.
* `check_folder_replication()` — pre-merge checklist (layout, yaml, code/data paths, artifacts, tests).
* `prepare_folder_paper()` — build artifacts, validate, write `registry/replication.yml` + `registry/index.csv` in study repo.
* `sync_folder_paper()` — copy prepared stub files into a registry checkout.
* `add_folder_paper()` — validate and register a folder-backed study stub in the registry.
* `audit_everything()` — registry-wide audit (Quarto report: `audit_everything.qmd` in the registry repo).
* Vignettes: [Registry audit](audit.html) and [Stata replications](stata-replications.html).
* Improved artifact error hints for folder-backed studies.

# replicateEverything 0.2.0

## Major features

* Connect to the public [replication registry](https://github.com/replicate-anything/registry) to discover and run computational replications by DOI.
* Run a single figure or table with `run_replication()` / `render_replication()`, or reproduce an entire paper with `replicate_paper()`.
* Load, validate, and save precomputed artifacts (`load_artifact()`, `save_artifact()`, `validate_outputs()`).
* Optional display pipeline via registered `format_*` functions (`format_for_display()`, `render_for_display()`).
* Package-backed replications: install and call standalone study packages from the registry or a local monorepo.
* Contributor tooling: `create_replication_template()` scaffolds a new replication folder with `replication.yml`, data, and code stubs.
* Registry search and metadata helpers: `search_papers()`, `load_index()`, `get_doi_metadata()`, `list_replications()`, `get_code()`.
* Local registry development via `options(replicateEverything.registry_root = ...)` and `options(replicateEverything.index = ...)`.

## Documentation

* Vignette: "Replication Examples Using Code".
* pkgdown site at https://replicate-anything.github.io/replicateEverything/.

## Notes

* Network-dependent examples and tests are wrapped in `\dontrun{}` or skipped on CRAN.
* Optional dependency installation during replication runs is opt-in via `install_deps = TRUE`.
