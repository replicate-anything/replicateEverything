# replicateEverything 0.7.6

## Clear messaging for steps that cannot be created (`incomplete:` / `blocked_reason:`)

* **New:** a step in `replication.yml` may declare `incomplete: true` plus a
  free-text `blocked_reason: "..."` explaining why it cannot be produced in
  this environment (missing proprietary engine such as Mathematica/MATLAB,
  a data file absent from the deposit, etc.). `incomplete:` already existed
  and already excluded a step from [build_study_outputs()] / baking and from
  [audit_everything()]; `blocked_reason:` is new and is now surfaced to
  users instead of the step just silently disappearing:
  * [run_replication()] now stops immediately with
    `"This object cannot be created because of: <reason>"` when asked to run
    a blocked step directly, and *skips* (with a `message()`, not an error)
    blocked steps encountered during `what = "everything"`, so one blocked
    leaf no longer aborts the rest of the DAG.
  * [list_replications()] still lists blocked steps (it always has - they
    are still real tables/figures, just not creatable here) so users can see
    what exists even when it cannot be built.
  * The bundled Shiny app now shows blocked table/figure/data-step pills
    greyed out with a disabled Display/Run button and an "Unavailable"
    badge; hovering (or the button title) surfaces the `blocked_reason`
    text.
* No schema aliases: `incomplete`/`blocked_reason` are the only supported
  field names (no `unavailable:` synonym) to keep `replication.yml` parsing
  simple.

# replicateEverything 0.7.5

## Stata batch runs are now fully non-interactive (no more "would you like the batch job to continue?" dialogs)

* **Bug fix:** `run_stata_do()`'s generated batch runner now wraps the actual
  step do-file in `capture noisily do "..."` instead of a bare `do "..."`. On
  Windows, an uncaught runtime error anywhere in a study's do-file - or in any
  do-file it calls, however deeply nested - previously left the batch Stata
  process (`/e do ...`) in an "interrupted" state that pops a modal "<file>.do
  has been interrupted. Would you like the batch job to continue?" dialog,
  hanging unattended/CI runs until someone clicks through it by hand
  (confirmed on Stata 10-19; happens with both `/e` and `/b` - `/e` only
  suppresses the separate "job finished, click OK" dialog on success).
  `capture` absorbs an error at the level it is applied regardless of nesting
  depth, so wrapping only this one, package-generated call protects every
  Stata study; individual study runners do not need their own `capture`.
  `noisily` keeps the error visible in the log so `stata_log_error()` still
  detects and reports the failure exactly as before - only the do-file-
  aborting side effect (and the dialog it can trigger) is suppressed. The
  same fix was applied to the maintainer-only SSC install scripts generated
  by `stata_deps_install_lines_from_packages()` (a network hiccup during
  `ssc install` had the same failure mode). New `stata_runner_lines()`
  helper factored out for direct unit testing.

# replicateEverything 0.7.4

## Discoverability of `doi = "local"` (cwd study root)

* **Docs:** [list_replications()], [run_replication()], [get_code()], and
  [describe_study_dag()] now document and demonstrate `doi = "local"` /
  `meta = "local"` with `\dontrun` examples — `setwd()` into a checked-out
  study repo (or open its RStudio project), then call the verb directly with
  `"local"`; no registry lookup or DOI is required. [check_replication()],
  [check_and_bake_study()], and [build_study_outputs()] now cross-reference
  the same working-directory study via their `location = "."` default and
  show a manual smoke-check snippet (`list_replications("local")`,
  `describe_study_dag("local")`, `run_replication("local", "<id>")`) ahead of
  the full checklist.
* **Vignettes / skills:** `folder-replication-checklist`,
  `package-replication-checklist`, and `meet-the-functions` vignettes, plus
  `inst/ai/skills/folder_replication.md` and
  `inst/ai/skills/include_study_in_registry.md`, add the same manual
  local smoke-check block before `check_and_bake_study()`. Root `AI.md`'s
  contribute-flow summary was expanded to spell out the smoke-check calls.
* **Shiny app:** the study picker dropdown now pins an explicit
  "Local study (this folder)" choice (value `"local"`) at the top when the
  app's working directory resolves to a study repo (same lookup `doi =
  "local"` uses), and the DOI/path text field's placeholder and inline help
  text spell out that typing or selecting `local` loads that study directly
  — no DOI or registry lookup needed. When no local study is detected (the
  normal production deployment), the extra choice is simply absent and
  remote registry / DOI search is unaffected. New `local_study_select_choice()`
  helper in `inst/shiny/app.R`, covered by two new `testthat` cases in
  `test-shiny-app.R`.

# replicateEverything 0.7.3

## API consolidation: install_dependencies()

* Added `install_dependencies(what = ...)`, a single maintainer entry point
  for dependency setup that mirrors the `build_outputs()` /
  `validate_outputs()` scope pattern: pass a study DOI/handle/path (default
  `"."`) to install for one study, or `what = "everywhere"` to install for
  every study in the registry index.
* Removed the `install_study_dependencies()` and
  `install_registry_dependencies()` exports (net API shrink: 29 → 28 exported
  functions). Both still exist as unexported internals that
  `install_dependencies()` dispatches to — no behavior change, only the
  public entry point moved. No legacy alias was kept.
* Updated all call sites, hint text (`maintainer_dependency_hint()`, Stata/
  code-tab setup messages, Shiny "Missing dependencies" copy), tests,
  `README.md`, the `maintainer-setup` and `meet-the-functions` vignettes,
  `inst/ai/skills/*.md`, and root `AI.md`.
* Reviewed and confirmed (no change needed) three other export-surface
  questions raised in the same audit:
  - `build_study_outputs()` / `check_replication()` / `check_and_bake_study()`
    remain three distinct, justified verbs (bake only; validate only; compose
    both for one-shot contributor onboarding).
    `check_folder_replication()` / `check_package_replication()` are
    `@describeIn check_replication` internals merged into `check_replication`'s
    single Rd topic — never separate exports or reference-index entries.
  - `register_study()` (check + sync in one call) and
    `sync_study_to_registry()` (sync primitive) are kept as a deliberate
    primitive + one-shot-composer pair, the same pattern as
    `check_and_bake_study()` over `build_study_outputs()` +
    `check_replication()` — not duplication.
  - `build_outputs()` (DOI/registry-scoped maintainer dispatcher, mirrors
    `validate_outputs()`) and `build_study_outputs()` (core one-study baker,
    used directly by contributors and internally by `build_outputs()`) serve
    different personas and are not duplicates.

# replicateEverything 0.7.2

## pkgdown reference audit

* Re-audited the full exported surface (29 functions) against `NAMESPACE`,
  `DESCRIPTION`, and the live pkgdown reference. Confirmed no legacy or
  duplicate exports remain from the 0.7.0/0.7.1 hard-cut — `build_outputs()`
  vs `build_study_outputs()` and `validate_outputs()` vs `check_replication()`
  are deliberately distinct (registry/DOI-scoped dispatch vs local-checkout
  operations), not aliases.
* Fixed a stale `_pkgdown.yml` reference to the removed
  `prepare_study_for_registry()` (now `check_and_bake_study()`) and added the
  missing `register_study()` entry.
* Regrouped the pkgdown reference index into a clearer map: Discovery; Run &
  inspect; Contribute (build & check); Maintainer (registry ops); Maintainer
  (setup & diagnostics); Shiny app; AI skills.
* Synced `inst/ai/skills/*.md` and monorepo `AI.md` with 0.7 reality (no
  content drift found beyond the pkgdown reference; both already matched the
  `steps:`-only, no-handoff, `build_study_outputs()` contract).
* No exported API changes.

# replicateEverything 0.7.1

## Monorepo cleanup

* Removed the last legacy-named internal aliases left over from the
  `papers/` → `studies/` registry rename (`registry_paper_yaml_path()`,
  `registry_paper_yaml_url()`); call sites and tests now use
  `registry_study_yaml_path()` / `registry_study_yaml_url()` directly. No
  user-facing change (both were `@keywords internal`, unexported).
* Fixed two `test-package-replication.R` assertions that still checked the
  legacy `replications:` field on a live GitHub fixture; they now check
  `steps:` to match the 0.7 hard-cut.
* Archived one-off registry migration scripts (`migrate_studies.R`,
  `flatten_registry_stubs.R`, `migrate_code_format.R`,
  `build_artifacts.R`, and other pre-0.7 onboarding/tooling scripts) to
  `registry/scripts/archive/`; registry CI and guides now point at
  `scripts/build_outputs.R` / `scripts/validate_outputs.R` only.
* Rewrote the package `README.md` and the `meet-the-functions`,
  `folder-replication-checklist`, `package-replication-checklist`, and
  `maintainer-setup` vignettes around the 0.7 contract: `steps:` as a DAG,
  `check_and_bake_study()` as the sole contributor entrypoint, and
  `sync_study_to_registry()` / `register_study()` as the sole maintainer
  entrypoint (no study-local `registry/` or `inst/registry/` handoff, ever).
* No exported API changes.

# replicateEverything 0.7.0

## Breaking: yaml contract and contributor API

* Contributor entrypoint is now [check_and_bake_study()] (replaces
  `prepare_study_for_registry()`). Maintainer one-shot is [register_study()]
  (replaces internal `add_paper()` / `add_folder_paper()`). Study-local
  registry handoff (`write_handoff` / `write_study_registry_stub`) is gone.
* `replication.yml` must declare a non-empty `steps:` DAG. Legacy `prep:` /
  `replications:` blocks error. Step edges use `parents:` only; products use
  `outputs:` only (`requires` / `depends_on` / `artifact` / `output` /
  `stata_output` rejected).
* Metadata resolution is deterministic: local study root → configured registry
  stub → remote `studies/<folder>.yml`. No silent GitHub scavenges or `papers/`
  fallbacks.
* Package checks no longer require a study-local `build_report()` helper; bake
  via [build_study_outputs()].

# replicateEverything 0.6.18

## Shiny Contribute tab

* Restructured Contribute into numbered prep / check / registry sections:
  **1** Prep (`1.1` yaml elements only with click-to-open
  `rep-template` modal; `1.2` folder- vs package-backed layout plus common
  substantive-test guidance; `1.3` bake outputs via
  [build_study_outputs()] only); **2** Check locally (`2.1` validate +
  testthat; `2.2` API play-well checks); **3** Connect with the registry
  (maintainer sync or contributor PR).
* Contribute no longer recommends study-package `build_report()` (a thin
  alias of [build_study_outputs()]) or `configure_local_monorepo()` for
  external contributors. `build_report()` remains available in package
  study repos for local/CI convenience. Missing-output Display hints now
  also point at [build_study_outputs()] for package studies.
* Package-backed Contribute copy now says study packages must not
  **define or ship** `run_replication()` / `list_replications()` /
  `load_artifact()` / `get_code()` (not merely "don't export" them);
  export only yaml-named `make_*` / `format_*` and true study helpers.

# replicateEverything 0.6.17

## Shiny Contribute tab

* Restructured Contribute guidance: lead with `replication.yml`, then yaml /
  registry compatibility (maintainer, collections, engines, steps, analysis
  helpers, substantive tests, validate via replicateEverything APIs), then the
  two setup approaches (folder vs package), then shared check + shared registry
  connect (maintainer sync or contributor PR).
* Copy now states that `run_replication()` / `list_replications()` /
  `load_artifact()` / `get_code()` live only in replicateEverything and must
  not appear in study repos or study packages.

## Package-backed studies

* Package runners no longer require study packages to export those verbs.
  `run_package_replication()` calls study `make_*` / `format_*` from yaml
  (legacy wrappers still work if present).
* `check_package_replication()` fails if a study package still exports the
  legacy verbs; recommends `build_report()` and checks `make_*` / `format_*`.

# replicateEverything 0.6.16

## Shiny Contribute tab

* Contribute copy now leads with `replication.yml` (gold example from
  `rep-template`), then shared guidance (maintainer, collections, engines,
  steps, validate via replicateEverything APIs), then the two packaging
  approaches with their specific features.
* Package-backed section no longer claims study packages must export
  `run_replication()` / `list_replications()` / `load_artifact()` /
  `get_code()` — those verbs live in replicateEverything; study packages
  supply yaml plus `make_*` / `format_*` (and bake artifacts).

# replicateEverything 0.6.15

## Shiny Code tab / get_code guidance

* Code-tab display annotations no longer append R `make_*` /
  `haven::read_dta` footers to Stata or Python scripts. Those commented
  yaml-implied recipes are R-only (defs without a top-level call).
* [get_code_run_advice()] (shared by [get_code()] tips and Code tab step 3)
  drops "Prefer run_replication" — that path does not use the displayed
  script. Guidance now states the study-root working directory once, then
  lists engine-appropriate options (do / python / yaml-implied / paste).

# replicateEverything 0.6.14

## Shiny study selector

* Dropdown labels append a short title snippet (first ~16 characters,
  ellipsis if truncated) so same-author same-year studies are distinguishable
  (e.g. `Acemoglu et al (2001) Colonial Origins...`).

# replicateEverything 0.6.13

## Shiny Code tab

* **See here for guidance...** outer collapse is a distinct subtle box
  (cool tint + left accent) so it stands apart from the code viewers.

# replicateEverything 0.6.12

## Single build entrypoint

* Removed public/documented aliases `build_package_artifacts()` and
  `build_study_artifacts()`. Use [build_study_outputs()] only; it already
  dispatches to package- vs folder-backed implementations
  (`build_package_outputs_impl` / `build_folder_outputs_impl`, unexported).
* [build_study_outputs()] creates `outputs/` when missing and wires DAG parent
  `outputs:` into child `inputs:` / `data:` via [replication_data_paths()].
* [build_outputs()] with `doi = "everywhere"` builds only studies cloned in the
  local monorepo; skipped studies are listed in the return value and messages.

## Shiny Code tab

* Code tab order: One-line replication → **Full replication code** subtitle →
  collapsed **See here for guidance...** (three nested collapsed steps) →
  code viewer. Step 3 uses shared [get_code_run_advice()] (no script-footer tip).

# replicateEverything 0.6.11

## Yaml is the execute recipe (no required script footers)

* Authors write pure `make_*` / `format_*` (or Stata/Python equivalents).
  Interactive `sys.nframe() == 0` footers are optional and not required.
* [get_code()] tips are engine- and yaml-aware numbered lists under
  "To produce the table/figure/step:": prefer [run_replication()] first;
  R also shows the yaml-implied load → make → format call and
  `eval(parse(text = get_code(..., mode = "run")))`; Stata/Python point to
  `do` / `python` from the study root (no `eval(parse)` option).
* [get_code()] `mode = "run"` always appends the yaml-implied recipe (does
  not rely on ungating a footer).
* Folder checks only require that R table/figure scripts *define* `make_*`.
* Shiny Code tab: expandable setup steps; always-visible one-liner tip;
  step 3 uses the same [get_code()] run advice (no footer guidance).
* Agent skills under `inst/ai/skills/` document minimal yaml, pure helpers,
  and maintainer [sync_study_to_registry()] (no study-local registry handoff).

# replicateEverything 0.6.10

## get_code modes and usage tip

* [get_code()] gains `mode = c("definitions", "run")` (default
  `"definitions"`). `"run"` appends a yaml-implied load → make → format
  expression so `eval(parse(text = ...))` can produce the object (study
  root as working directory).
* Calling [get_code()] prints a short tip tailored by engine and step type.
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

* **Unified contribute API:** [build_study_outputs()] replaces [build_study_artifacts()] and [build_package_artifacts()]; [check_replication()] replaces [check_folder_replication()] and [check_package_replication()]; [validate_outputs()] replaces `validate_artifact()`, `validate_paper_artifacts()`, `validate_study_artifacts()`, and `validate_registry_artifacts()`. Use `doi = "everywhere"` and `what = "everything"` for registry-wide checks. Kind-specific check helpers remain internal; build helpers were later folded into [build_study_outputs()] (0.6.12).
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

* Stata dependency checks are **study-declared** via `stata_deps_probe:` (check-only `.do` in the study repo) or `stata_packages:` (generic `which`-only probe). The package no longer hardcodes ftools/reghdfe/estout. Live Run probes only; `install_stata_deps.do` runs only when `options(replicateEverything.install_stata_deps = TRUE)` (e.g. `build_study_outputs(install_deps = TRUE)`).
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

* `build_study_outputs()` — run replications and write `outputs/` + `manifest.json` from a study repo (formerly `build_study_artifacts()`).
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
