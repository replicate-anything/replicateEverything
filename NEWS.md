# replicateEverything 0.7.38

## Shiny: move stale-deploy warning into footer

* The yellow/orange **"Shiny deployment may be stale"** top banner is removed.
  Deploy-stamp mismatches (version, library path, or loaded namespace) now show
  only as a brief footer note next to the existing version/`pkg`/`app` line,
  e.g. `stamp version: 0.7.34 · installed: 0.7.35 [possibly stale]`.
* When stamp and installed package agree, the footer shows **no** extra stale
  text (matching SHAs alone already signal a consistent deploy).

# replicateEverything 0.7.37

## Fix: bake timings recorded from build_study_outputs

* [build_display_artifact_entries()] and [run_build_prep_steps()] now call
  [record_study_replication_timing()] after each successful (non-cached)
  step. Overnight `build_study_outputs()` runs were rewriting figures/tables
  without refreshing `outputs/replication_timings.json` because only
  [run_replication()] recorded timings.
* [record_study_replication_timing()] writes via a sibling `.tmp` then rename
  (with warning on failure) so Dropbox-paused locks are less likely to leave
  a stale timings file with no error signal.

# replicateEverything 0.7.36

## Fix: skip incomplete prep siblings during full bake

* [prep_steps_for_build()] / [build_study_outputs()] no longer run
  `incomplete: true` transform steps (e.g. Hahn
  `compute_mvpf_main_mathematica`) when baking all outputs. Full bake now
  walks ancestors of display steps and skips blocked engine paths, so a
  missing `wolframscript` cannot abort an operable Stata+R bake.

# replicateEverything 0.7.35

## Shiny launch: frontload Studies UI + health counts; defer auto-update

* **Baked Studies widgets:** [build_shiny_studies_cache()] writes a `ui`
  block (`select_choices`, `collection_choices`) into `shiny_studies.json`
  (schema_version 2). Shiny applies those named choices on startup instead of
  re-sorting authors and rebuilding dropdown labels each session.
* **Health bar:** uses baked `audit_summary.json` `progress` counts only —
  no longer loads `audit_latest.rds` on first paint. [audit_progress_counts()]
  prefers `summary$progress` when present.
* **Process preload:** worker start parses `shiny_studies.json` and
  `audit_summary.json` once into globals; session `onFlushed` assigns from
  that memo instead of reassembling.
* **Deferred auto-update:** [ensure_replicate_everything_current()] runs ~2s
  after Studies are interactive, not on the first flush critical path.

# replicateEverything 0.7.34

## Fix: Display for prep/transform data steps (Hahn datasets 1–5)

* **Bug:** After multi-panel Display (0.7.32), Shiny loaded artifacts via
  [load_artifact_panels()], which only treated html/png/rds/svg/xlsx as
  displayable. Prep/transform steps whose `outputs:` are `.done` / `.dta` /
  `.csv` (Hahn `clean_data`, `macros`, `cost_curve_data_r`,
  `compute_mvpf_main`, `compute_mvpf_no_lbd`) fell through to invented
  `outputs/<id>.html`/`.png` candidates, then GitHub raw URLs, and surfaced
  as missing with **HTTP 404** — even when baked local sinks existed and
  [load_artifact()] already previewed/summarized them correctly.
* **Fix:** treat `.csv`/`.dta`/`.tab` as displayable sinks; for prep steps,
  include declared `outputs:` (including `.done`) and skip html/png type
  fallbacks when sinks are declared; [load_artifact_panels()] delegates prep
  entries to [load_artifact()] / [load_prep_step_display()]. Local monorepo
  paths win; no rebake.

# replicateEverything 0.7.33

## Fix: Excel Display rounding actually reaches Shiny

* **Bug:** 0.7.32 added [format_xlsx_preview_df()] but Shiny `as_table_ui()`
  fell back to bare `as.character()` when the installed package lacked that
  helper (e.g. still on 0.7.31). That preserved Excel float-text artifacts
  such as Hahn `tab_2` `6.2399425510000004` / `-113.1814499`.
* **Fix:** Shiny always rounds preview cells to 3 decimals (inline fallback
  mirrors the package helper; never raw `as.character`). Package helper uses
  `sprintf("%.3f", ...)` and unwraps length-1 list cells. Does not rebake
  workbooks.

# replicateEverything 0.7.32

## Display: multi-panel figures + Excel 3-decimal preview

* **Multi-panel figures:** Shiny Display now stacks every declared displayable
  `outputs:` sink for a figure step (png/html/svg), not only the first path
  returned by [study_artifact_rel_path()]. New helpers
  [study_declared_displayable_rels()], [get_artifact_paths()], and
  [load_artifact_panels()] feed [load_replication_for_display()]. Fixes Hahn
  AER `fig_2` / `fig_3` (panels a+b both baked) without study-specific hacks.
* **Excel table preview:** numeric cells in the `readxl` Display preview are
  rounded to 3 decimal places ([format_xlsx_preview_cell()] /
  [format_xlsx_preview_df()]); non-numeric text is unchanged. Does not rebake
  workbooks.

# replicateEverything 0.7.31

## Fix: Excel `outputs:` paths resolve for Display (Hahn Table 1 / 2)

* **Bug:** `study_artifact_rel_candidates()` only treated `html|png|rds|svg` as
  displayable, so table steps whose sole `outputs:` entry was an `.xlsx`
  (Hahn `tab_1` / `tab_2`) fell through to non-existent `outputs/<id>.html`
  and Shiny Display reported a missing object even when the workbook was on
  disk. The 0.7.30 Excel preview UI never ran because lookup never found the
  file.
* **Fix:** treat `.xlsx` / `.xlsm` / `.xls` as displayable sinks in candidate
  resolution and Display-sink checks; `read_artifact_file()` / remote fetch
  keep the workbook path (like PNG); Shiny `as_table_ui()` previews a
  character path to an Excel file via the existing `readxl` preview (not only
  Stata result lists); folder `table_artifact_file_ok()` accepts Excel sinks.

# replicateEverything 0.7.30

## Hahn tables + WZB Shiny run gate

* **Hahn tables:** file-backed Excel table artifacts (e.g. Hahn `tab_1` /
  `tab_2` `.xlsx` outputs) now preview in Shiny when `readxl` is available on
  the host, instead of falling through to a raw text / unreadable file-path
  view. The table display picks non-`data_export` sheets first and trims blank
  rows/columns for a compact preview.
* **Stata runner exit codes:** generated runners now preserve the nested
  step do-file's `_rc` and re-raise it on `exit` (Windows included). Previously
  a failed step could still report process exit 0 after `exit, clear STATA`,
  which surfaced only as a confusing "Expected Stata output not found".
* **WZB Shiny live-run limit:** deployed apps can now set
  `replicate_shiny.wzb_live_run_max_seconds` via
  [save_local_shiny()] / [write_shiny_deploy_options()] /
  `deploy-options.R` (default `600`, i.e. 10 minutes). When the app is running
  on the WZB Shiny host and a step's estimated runtime exceeds that threshold,
  clicking `Run` shows a polite "please run locally" message and falls back to
  baked Display output instead of starting the server-side job.
* **Registry health layout:** the health legend/key is now explicitly laid out
  to the right of the bar for a more compact header.

## Fix: registry health bar `[[` crash persisted after the 0.7.28 authors fix

* **Bug:** the 0.7.28 fix guarded the empty-`authors` `strsplit(...)[[1]]`
  sites, but the health bar's `[[` crash persisted because it had a second,
  unrelated cause introduced by the finer replicating / timed out /
  substantive / missing-engine / other status breakdown:
  `registry_health_bar_ui()` built a *named* integer vector `segs`, then
  called `segs <- pmax(0L, segs)` to clamp negative counts - but `pmax()`
  silently drops the names attribute when one argument is an unnamed
  scalar, so every subsequent `segs[["replicating"]]` (etc.) lookup threw
  `Error in [[: subscript out of bounds`. Reproduced end-to-end with
  `devtools::load_all()` against the local `registry/audit_summary.json`.
* **Fix:** clamp negatives in place (`segs[is.na(segs) | segs < 0L] <- 0L`)
  instead of `pmax()`, which preserves names. Also hardened bucket lookups
  in `registry_health_bar_ui()` against version-skewed/legacy
  `audit_progress_counts()` output missing one or more of the newer
  buckets (falls back to `0` per-bucket instead of erroring), so an older
  or partial audit summary degrades gracefully instead of crashing.
* **Fail-soft UX:** a health-bar rendering failure (this bug or any future
  one) no longer surfaces as a big red Shiny error banner at the top of the
  app. The bar is silently omitted and a small `replicateEverything:
  registry health bar unavailable (see server log)` note appears in the
  footer instead; the underlying error is still logged server-side
  (`warning()`) for maintainers.

## Fix: Stata dependency check disagreed with `ssc install` (moremata)

* **Bug:** `check_study_compatibility()` / `install_dependencies()` could
  report Stata packages as missing (e.g. `estout`, `outreg`, `moremata` for
  the Bertoli `10.1596/1813-9450-10626` study) even though `ssc install`
  confirmed them already installed in the interactive Stata session. Root
  cause: the auto-generated dependency probe tested every declared package
  with `which <pkg>`, but `moremata` ships no ado command of its own name
  (it's a pure Mata function library - `lmoremata.mlib` + help files, no
  `moremata.ado`), so `which moremata` always fails with `r(111)`
  regardless of installation status. Because the probe exits at the first
  failing check, this single false failure caused *every* declared package
  for the study to be reported "missing", not just `moremata` - a second,
  compounding bug. Both the check and the install path already resolved
  the exact same Stata executable ([find_stata_executable()]); confirmed
  with a live probe against the actual Stata 17 MP install
  (`C:/Program Files/Stata17/StataMP-64.exe`) that `which moremata` fails
  while `findfile lmoremata.mlib` correctly finds the installed library.
* **Fix:**
  - `moremata` (and any future file-only package) is now probed with
    `findfile lmoremata.mlib` instead of `which moremata`
    ([stata_package_probe_spec()] / [stata_package_probe_line()]), used
    consistently by both the install script and the check probe.
  - A failing generated probe now attributes the failure to the *specific*
    package whose check failed (via its distinct `exit` code -
    [stata_deps_probe_plan_from_packages()] /
    [stata_probe_failure_code()]), instead of blaming every declared
    package for one broken check.
  - `check_study_compatibility()`'s `$dependencies$stata` (and
    `install_dependencies()` console output) now always report which Stata
    binary was used (`stata_executable` path + a human-readable
    `stata_label`, e.g. `"Stata 17 MP (C:/Program Files/Stata17/
    StataMP-64.exe)"` - see [stata_executable_label()]), so a check-vs-
    install Stata mismatch is visible instead of assumed.
  - `install_dependencies()` now reports which packages were already
    present vs. newly installed, and immediately re-runs the same
    presence probe after install ("on-the-spot validation"), warning
    loudly with the specific still-missing package(s) if the probe still
    fails - so "Dependency install finished" can no longer silently lie.

## Fix: broken `@description` link in roxygen docs

* `replication_errors.R`: the doc block documenting
  `replication_error_message()` was misattached to `strip_ansi_escapes()`
  (defined between the roxygen comment and the intended function), leaving
  `replication_error_message` undocumented and breaking the
  `[replication_error_message()]` markdown link used elsewhere in the same
  file (`missing_replication_steps_message()`). Moved the doc block to the
  correct function and gave `strip_ansi_escapes()` its own short doc
  comment; `devtools::document()` now builds without that link warning.

# replicateEverything 0.7.28

## Shiny path picks: standard chrome, translation note moved to study summary

* **Path picks (multi-language path groups):** the paired-icon path pick for
  groups like Stata+R vs Stata+Mathematica now looks like a standard
  single-icon engine pick (transparent, opacity-based active/inactive state)
  instead of a bordered box - no visible caption underneath. The only
  visual difference from an ordinary study is that a pick shows two icons
  (a language pair) instead of one. The `path_note:` text (e.g. "R is a
  translation of the original Mathematica LBD kernel") still lives in the
  tooltip / aria-label.
* **Study summary:** added [study_path_translation_notes()], a generic
  (non-study-specific) helper that surfaces each multi-language path
  group's `path_note:` once in the sidebar study summary ("Replication
  type: ..."), instead of as a per-row callout. No study-specific text is
  hardcoded in the package - it is read from yaml.
* **Wrench/hammer gating (confirmed, no behavior change needed):** the
  missing-system-engine wrench in the row's Display/Run controls already
  re-evaluates per the *currently selected* path, so it only shows when the
  Mathematica (or other proprietary-engine) path is the active selection,
  not the R/Stata default. The Studies-table summary column is unaffected.

## Fix: Shiny crash on studies with a blank `authors` field

* **Bug:** any registry entry with an empty `authors` string (e.g. a freshly
  onboarded stub before author metadata is filled in) crashed the Shiny app
  with `Error in [[: subscript out of bounds`. The Studies dropdown
  (`nice_doi_choices()`) and bibliography ordering
  (`studies_for_bibliography()`, `build_shiny_studies_cache()`) sorted rows
  by first-author surname using `strsplit(authors, ",")[[1]][[1]]`; an empty
  `authors` string splits to `character(0)`, and indexing it with `[[1]]`
  errors instead of returning `NA`/`""`.
* **Fix:** guard each of the three call sites with a `length()` check before
  indexing, so blank authors sort as "Unknown" instead of crashing.

# replicateEverything 0.7.27

## Prep Display: transform / .done sink summaries

* **Display:** transform/prep steps whose primary sink is a `.done` marker (or
  other non-tabular product) now show a human summary via
  [summarize_prep_transform_sink()] — completion stamp, optional yaml
  `products:` / `display_products:` inventory (with cheap row/col notes),
  output-dir listing, and key inputs — instead of dumping marker text like
  `clean_data completed …`.
* **Captions:** [prep_step_display_caption()] prefers short `path_note:` and
  truncates long `description:` blurbs so “Showing precomputed result for …”
  stays readable.

## Path boxes: `path_note:` for translation honesty

* Yaml steps may set `path_note:` (e.g. “R is a translation of the original
  Mathematica LBD kernel”). Shiny path boxes show it under the paired icons
  and in tooltips / aria labels ([step_path_note()]).

## Audit health bar: finer progress categories

* Registry top bar segments: **replicating**, **timed out**, **substantive
  fails**, **missing engines**, **other** (gaps / skipped / incomplete /
  data unavailable / other fails). Wired from
  [audit_progress_category()] / [audit_progress_counts()]; summary JSON gains
  `missing_engine` and `progress` when rewritten from an audit snapshot.

# replicateEverything 0.7.26

## Shiny path boxes: paired language icons + yaml-order Data steps

* **Shiny:** multi-language path alternatives render as **paired-icon boxes**
  (e.g. Stata+R icons inside one control, Stata+Mathematica in another), not
  a single misleading engine pill. Incomplete / `requires_engine:` paths are
  dashed+greyed but stay selectable so Code remains reachable; Display / Run
  still follow [shiny_step_show_display()] / wrench gap rules for the active
  path only.
* **Shiny:** Data steps follow yaml / DAG declaration order via
  [replication_sidebar_data_order()] — promoted multi-path transforms are
  interleaved with ordinary prep rows (not forced first). Shared `group:`
  siblings collapse to one sidebar key (no duplicate claim rows).

# replicateEverything 0.7.25

## Multi-language path alternatives (Shiny + yaml)

* **Yaml:** sibling steps may share `group:` and declare per-path
  `languages:` (e.g. `[stata, r]` vs `[stata, mathematica]`) for one claim
  with multiple engine paths. Documented in `folder_replication.md` and
  `inst/docs/step-dag-design.md`.
* **Shiny:** path groups render as labelled boxes (`[Stata / R]` |
  `[Stata / Mathematica]`); selection drives Display / Run / Code. Gap paths
  reuse [shiny_step_show_display()] / wrench helpers (Code visible; no false
  Display). Multi-path transforms stay under Data steps in yaml order.
* **Resolve:** `language = "r"` / `"mathematica"` selects by path languages
  even when `engine: stata`.

## Windows Stata: allow shell (drop /e batch mode)

* Windows Stata launches as `/q do …` instead of `/e /i /q do …`. Batch mode
  (`/e`/`/b`) ignores `shell`/`winexec` (“request ignored because of batch
  mode”), which blocked Hahn LBD `shell Rscript` and any other external
  calls. Generated runner now `log using` + `exit, clear STATA`; processx
  `windows_hide` keeps the GUI off the desktop. Dependency probes also go
  through [run_stata_do()] so they exit cleanly (a bare `/q do` hung until
  probe timeout and falsely reported every SSC package missing).
* PATH injection for Rscript’s bin is unchanged (still needed when shell
  runs under a thin System PATH).
* Probe map: SSC `labutil` → `which labmask`.

# replicateEverything 0.7.24

## Bake timings fallback for audit timeouts

* New study artifact `outputs/replication_timings.json`, written by
  [record_study_replication_timing()] on successful [run_replication()]
  folder runs. [lookup_study_replication_timing()] /
  [read_study_replication_timings()] read it.
* [lookup_replication_audit_runtime()] returns `bake_seconds` and prefers it
  for advice when audit `timed_out`. [format_long_run_warning()] /
  Shiny hourglass copy can say “last successful bake took …”.
* **Windows Stata batch:** prepend Rscript’s bin to PATH (and keep that env on
  the processx→system2 fallback) so LBD `shell Rscript` works under thin
  System PATH.

# replicateEverything 0.7.23

## Metadata: multiple source_repository URLs

* **`paper.source_repository`** may be a yaml list. New
  [paper_source_repositories()] returns all credits; [paper_source_repository()]
  still returns the primary (first). Shiny Source column / study details show
  one kind icon per URL. Registry stubs preserve the list. Motivated by
  `rep-10.1257-aer.20250166` (GitHub Policy-Impacts/mvpf-climate + OpenICPSR).
* **Windows Stata batch:** prepend Rscript's bin dir to PATH so LBD
  `shell Rscript` works when Stata only sees the machine System PATH.

## Stata / Shiny (carry from uncommitted bake session)

* **`save_artifact()`** for `stata_output` uses the real output file extension
  (xlsx/csv/dta/…) instead of hardcoding `.smcl`.
* **Shiny engine badges:** blocked `requires_engine: mathematica` steps show
  Mathematica only (no stray Stata badge); Mathematica recognized as a
  display/language token for alternate-engine groups.
* **Stata log flush wait** after batch exit (Windows/NTFS stale size).

# replicateEverything 0.7.22

## Skills: file provenance header convention

* **Docs:** New cross-study convention — every study code file carries a
  short top-of-file `replicateEverything provenance:` comment naming one of
  `connector` / `author-original` / `translation (X -> Y)` / `author-edited`.
  Documented in `inst/ai/skills/folder_replication.md` (§ File provenance
  headers), the skills `README.md`, and root `AI.md`. Large untouched vendored
  trees (e.g. `code/original/`) get one folder-level `README.md` instead of a
  per-file sweep. Applied to `rep-10.1257-aer.20250166` as the worked example.

# replicateEverything 0.7.21

## Shiny: package brand link; pkgdown Run & inspect first

* **UX:** Top-left `replicateEverything` brand in the Shiny app links to the
  pkgdown site ([PKGDOCS_URL]) in a new tab (no underline clutter).
* **Docs:** pkgdown reference index puts **Run & inspect** ahead of
  **Discovery** (most-used verbs first).

## Shiny: study share link in summary header

* **UX:** The public study share/chain icon is study-level, not
  table/figure-level. It no longer repeats on every left-menu step row;
  it sits once with the other chrome icons to the right of the study
  summary title (DOI-driven deep link via [share_link_ui()]).

## Shiny: fix inverted Display enablement; hourglass for audit-timeout Runs

* **Bug fix:** Display enablement no longer uses
  `output_exists || engine/data gap`. That rule greyd available prep steps
  without html/png sinks (Hahn: `clean_data` / `macros` /
  `compute_mvpf_no_lbd`) while leaving the Mathematica-blocked step
  (`compute_mvpf_main`) clickable. [shiny_step_show_display()] omits
  **Display** for gap/incomplete rows without a sink (padlock / wrench still
  open **Code**), keeps Display for runnable steps and for gaps that have a
  baked artifact.
* **UX / helpers:** [shiny_step_long_run_indicator()] shows a sand hourglass
  beside **Run** when a Display sink exists, registry audit timed out, and the
  step is otherwise runnable (no padlock / wrench gap). Lengthy tooltip /
  progress copy comes from [format_long_run_warning()] using
  `timeout_seconds` when available.
* **Audit:** [lookup_replication_audit_runtime()] returns
  `timeout_seconds` and treats timed-out rows as `runtime_category = "slow"`.

# replicateEverything 0.7.20

## format_for_display keeps REPLICATE_STUDY_ROOT

* Live Run formatting now keeps `REPLICATE_STUDY_ROOT` set while calling
  study `format_*` helpers (same as the analysis step). Without this,
  helpers that resolve `outputs/staging/*.tex` via that env var failed and
  Stata tables fell back to raw `.tex` in a `<pre>` on Run (Display baked
  HTML was fine).

# replicateEverything 0.7.19

## Docs home: no duplicate hex

* README hex keeps `class="pkgdown-hide"` so GitHub still shows the
  sticker, while the pkgdown home page relies on the navbar/header logo
  only (no large duplicate at the top of `docs/index.html`).

## Template / Contribute exemplar alignment

* **Shiny Contribute:** Gold `replication.yml` exemplar now matches
  `rep-template` (includes `paper.source_repository`, `year: "2026a"`,
  estimatr/knitr deps, `inputs:` only — no redundant `data:` duplicate).
* **Skills:** `folder_replication.md` notes Source icon kinds (personal as
  residual) and prefers `inputs:` over duplicating the same path under
  `data:` and `inputs:`.

# replicateEverything 0.7.18

## Shiny: authors visible above the study-info fold

* **UX:** Study details shows a shortened author line
  ([format_author_label()]) under the title (always visible). The folded
  panel still lists the fuller [format_authors_summary()] string with year
  and journal.

## Hex logo refresh

* Package hex sticker promoted to circular upright **replicate** /
  **everything** with recycle mark; left/right separator dots are orange
  (`#C55B28`). Shiny welcome modal places the hex centered below the copy
  (smaller) so text stays primary.
* Hex PNGs (`man/figures/logo.png`, `docs/logo.png`, Shiny
  `logo-hex.png`) now use a **transparent** exterior (true alpha) so the
  sticker sits cleanly on the blue welcome UI and other non-white
  backgrounds; the hex face is unchanged.

## Paper source repository credit

* **Metadata:** Canonical field is `paper.source_repository` (URL preferred;
  bare `replicateEverything` also accepted). Legacy `source_url` /
  `source_repo` are still read as aliases. [paper_source_repository()],
  [source_repository_kind()], and [source_repository_href()] resolve and
  classify credits (Dataverse, OSF, World Bank, ICPSR/OpenICPSR, Git,
  personal archive, replicateEverything).
* **Checks / audit:** [check_replication()] requires
  `paper.source_repository`. [audit_everything()] summary lists
  `missing_source_repository` keys via [registry_source_repository_gaps()].
* **Shiny:** Studies table has a dedicated **Source** column (kind icons) beside
  **Repo**; Study column is ~20% wider. Labeled **Source repository** link lives
  in the folded study-info panel (icon may still appear in the summary icon
  row). Registry stubs / `shiny_studies.json` carry the field for list-time
  display. Icon marks: Dataverse hollow two-ring brand (#C55B28), GitHub
  Octicons mark-github, ICPSR serif I in linking-widget blue (#115BFB), plus
  compact OSF / WB / personal / recycle icons.

## Shiny: study-only deep links (dropdown first)

* **Simplify:** Deep links are study-only (`?doi=` / optional `handle=`).
  Legacy `what=` / `language=` in old URLs are ignored and never re-emitted.
  Opening a study prefers the first Display-ready step (existing behaviour).
* **Bug fix / control flow:** Manual Studies dropdown always loads the selected
  study (highest priority). Removed `pending_deep_link_what`,
  `study_keys_match` same-DOI skip, and related guards that could block the
  dropdown while a cold-paste `?doi=` was pending. Cold paste still queues
  once and applies after `registry_ready`; URL sync writes `?doi=` only and
  does not re-queue.

## Shiny: cold-paste deep links open study

* **Bug fix:** Initial load with `?doi=` / `?handle=` now waits for the
  deferred Studies cache before selecting the study. Previously the deep-link
  queue could apply before `shiny_studies.json` was ready, so
  `updateSelectInput(selected=)` missed and the session stayed on the main
  Studies page (click-through Go still worked).
* Preserves the pending / current study when rebuilding the DOI dropdown;
  does not strip inbound query params while a deep link is pending.
* Accepts `handle=` as a study key; re-reads the query on `popstate`
  (back/forward).

## validate_outputs(): print a short report

* **UX:** [validate_outputs()] now returns a `validate_outputs_result` that
  auto-prints PASS/FAIL, DOI/what, and checked paths (same style as
  [check_replication()]). Previously success returned `invisible(TRUE)`, so an
  unassigned call printed nothing. Use `$ok` for the logical flag.

## Shiny: missing-engine icon is a wrench

* **UX:** Missing-engine / tool-gap mark is a **wrench** (amber circle) instead
  of a navigational compass — legend, Studies Notes, and Run-slot chrome. Padlock
  for data unavailable is unchanged. Internal gap kind remains `"hammer"`.

## Extension studies: cold-host inherited steps use parent URLs

* **Bug fix:** `step_run_context()` always sets parent `base_url` /
  `materials_repo` for inherited steps, even when the parent study is not
  checked out locally (Shiny / cold hosts). Previously those fields were only
  rewritten when a local parent `local_root` existed, so Code/Run still fetched
  `.../--alt-1/.../analysis_data.R`.
* **Bug fix:** `materials_repo_override` narrows folder candidates / map keys to
  the parent slug so materialize does not fall back to the extension checkout.
* **Bug fix:** `extended_base_paper_context()` always pins `base_url` to
  `extends.repo` / `extends.ref` (not only `materials_repo`).
* **Bug fix:** `study_repo_ref()` honors `ctx$materials_ref` for parent refs.

## Extension studies: Display resolves inherited sinks from the parent

* **Bug fix:** Shiny **Display** was greyed out for inherited prep (e.g.
  `analysis_data` on `--alt-1`) because `step_display_output_exists` /
  `artifact_lookup_candidates` / `get_artifact_path` / `load_artifact` probed
  the *extension* `outputs/` and URLs. They now use `step_run_context()` so
  Display enablement and resolution match Run/Code (parent local root or
  parent raw GitHub URL).
* **Bug fix:** `load_prep_step_display()` applies the same parent context and
  falls back to a remote parent sink when the file is not local.
* **Bug fix:** remote `.rds`/`.csv`/`.dta` artifacts download via
  `load_artifact_file_path()` (previously only html/png remote worked).
* **Bug fix:** `check_display_sink_rows()` no longer fails extensions for
  missing child copies of inherited prep sinks; it checks the parent study
  root when available, otherwise passes as inherited.

# replicateEverything 0.7.17

## Extension studies: inherited code/data resolve from the parent repo

* **Bug fix:** `get_code()` / Code-tab readers now use `step_code_context()` so
  inherited steps (e.g. `analysis_data` on alt-1) fetch from the base study
  repo instead of looking for `code/steps/...` under the extension slug.
* **Bug fix:** remote path joins use `registry_url()` everywhere
  (`get_code`, `resolve_registry_file`, `load_replication_data`, code-link
  readers) so `base_url` values that already end in `/` no longer produce
  `.../main//code/...` URLs.
* **Bug fix:** `study_repo_slug()` prefers `ctx$materials_repo` when set, so
  materializing an inherited step downloads the base checkout, not the
  extension.
* **Bug fix:** extension `tab_1` runs that need parent `outputs/*.rds` fall
  back to `.extends_context$base_url` when the base study is not local
  (Shiny / fresh machines).
* **Docs:** reanalysis vignette and step-inheritance notes use `analysis_data`
  (current Fearon & Laitin pipeline), not the retired `prep_data` name.

## Versioning (going forward)

* Stay on `0.x.y` until a deliberate 1.0 decision. Recent `0.7.y` patches
  (through 0.7.18) were fine; **future bumps should be rarer and batched**.
* Prefer patch (`0.7.y`) for most fixes and small UX/engine changes; minor
  (`0.8.0`) only for larger coherent releases, used sparingly.
* Bump `DESCRIPTION` / `NEWS` when releasing a coherent set of changes — not
  on every tiny commit when batching is possible. Stick to ordinary semver-style
  `0.MAJOR_FEEL.PATCH` (no schemes like `0.07.17`).

# replicateEverything 0.7.16

## Code tab: clearer run-tips header

* R defs-only Code tab epilogue banner is now
  `# --- Tips for running code (generated from replication.yml) ---`
  (was `Execute via replication.yml (get_code mode=run)`).

# replicateEverything 0.7.15

## Shiny: study links use the same Go handler

* Studies table **citation title**, **Link** chain icon, related-study icons,
  and **Explore different types of study** example citations all fire
  `go_to_study` (select study, load, switch to Replicate, close modal) —
  the same path as the **Go** button. Journal / DOI on the citation second
  line remain external article links. Link keeps a public deep-link `href`
  for right-click copy only.

# replicateEverything 0.7.14

## Shiny Display/Run: no “missing output” errors for registered studies

* **Blair / `engine: dataverse`:** Live Run with language `r` resolves surgical
  access steps (no “not available for language r”). Display shows a Dataverse
  file-access summary when `outputs/*.dta` is gitignored / absent — not
  “Output not on disk yet … Use Live Run”.
* **Package-backed Display (Geissler):** `load_artifact` /
  `artifact_lookup_candidates` fall back to GitHub raw
  `inst/report/artifacts/` when the study package is not installed locally.
* **Shiny gap icons:** padlock / compass click selects the step and opens
  **Code** (Display stays available when a sink or gap message is displayable).
* **Validation:** `check_display_sink_rows()` in folder/package
  `check_replication` — claimed non-gap steps must have Display wiring (baked
  table/figure sinks, or Dataverse access summary fields).

# replicateEverything 0.7.13

## Shiny Studies performance (registry-baked cache)

* **`build_registry_index()`** now also writes **`shiny_studies.json`**: citation,
  collections, languages/engines, notes flags (data unavailable / missing
  engine), related upstream/downstream (titles + urls), article and study
  urls. Helpers: [build_shiny_studies_cache()], [load_shiny_studies_cache()],
  [studies_table_data()].
* **Shiny Studies tab** reads only that cache (session-memoized by mtime); no
  live study-yaml fetch on the list. Full yaml / `list_replications()` still
  runs when a study is opened.
* **Startup:** UI shell paints first; studies cache, audit health bar, and
  version auto-update run in `session$onFlushed`.
* **Registry stubs** gain optional `notes:` (padlock / hammer) from study yaml
  on [sync_study_to_registry()].

# replicateEverything 0.7.12

## Shiny Studies polish + Madsen citation

* **Study-types guide:** renamed "Explore different types of study"; opens on
  first visit to the Studies tab (then only via the link); removed from the
  welcome popup; shorter example labels; bilingual row cites Acemoglu and
  Fearon & Laitin; no Pattern/Example headers or lead paragraph.
* **Studies table:** narrower Study column; Related ↑/↓ icons merged into Notes
  with padlock/compass (Related column removed).
* **Madsen/Voeten authors:** registry stub + index use Last, First form so the
  citation label is Madsen et al (not "Rask Madsen" from the compound-surname
  heuristic on "Mikael Rask Madsen").
* **Default step on study open:** selects the first *available* object
  (Display would work: baked output, or normal runnable), not the first
  blocked row. Skips missing-engine / `data_unavailable:` / incomplete steps
  with no displayable output (e.g. Hahn climate → Figure 5; other Hahn →
  Table 1).

# replicateEverything 0.7.11

## Study-types guide + Team 2026a/b labels

* **Shiny:** "Guide to study types" modal from the Studies tab and welcome
  screen (table of registry patterns with distinctive bits in bold).
* **Registry years:** paper years may use bibliography suffixes (`2026a`,
  `2026b`); index / `get_study()` keep them as character labels.
* **Studies Notes column:** gap icons (padlock / compass) remain in Notes;
  Languages stays engine badges only.

## Study summary API + Related column

* **`get_study(doi)`** returns a compact `replicate_study` descriptor;
  **`summary(get_study(doi))`** / **`summary_study(doi)`** print title, DOI,
  citation, collections, languages, maintainer, step counts, upstream /
  downstream related studies, gap tags, and repo link.
* **Registry index:** `build_registry_index()` writes `related_upstream` and
  `related_downstream`. Upstream comes from stub `paper.related` /
  `paper.extends`; downstream is the reverse map across the registry.
* **Shiny Studies list:** new **Related** column (↑ teal upstream /
  ↓ blue downstream icons with hover labels). Notes stays padlock/compass.
* Registry stubs now preserve `paper.related` and `paper.extends` on sync.

# replicateEverything 0.7.9

## Shiny Feedback tab only on WZB server

* **Feedback tab** (and welcome-copy mention) shown only when
  [shiny_running_on_wzb()] is `TRUE`: path marker `/wzb/samba/user/ipi/` in
  working dir, app dir, `.libPaths()`, or package install path. Override with
  `REPLICATE_SHINY_FEEDBACK=1` / `=0`. Local `run_shiny_app()` hides it by
  default.

## Shiny UX: Notes column, unified step rows, tooltip-only gaps

* **Studies list:** dedicated **Notes** column for padlock / compass gap icons
  (Languages stays language badges only). Desktop grid and mobile card layout
  both include Notes.
* **Step list:** engine badges (R/Stata/Mathematica) sit **left of Display/Run**
  for all studies, including Hahn Mathematica gaps — same layout as dual-engine
  rows.
* **Gap icons:** hover `title` tooltip only; click no longer opens a second
  modal. Missing-engine mark is a **compass** (clearer than the small hammer).
* **Paper links:** [paper_article_url()] no longer treats `paper.study_url`
  (GitHub) as an article landing page. Shiny DOI/journal links prefer
  `article_url` / `doi.org/{doi}`; GitHub URLs that leaked into `article_url`
  are ignored.

# replicateEverything 0.7.8

## Shiny: padlock vs hammer Run slots (+ Studies list)

* **UX:** Steps with `data_unavailable:` keep a normal label and Code; the Run
  slot is a **padlock** (click → availability message). Engine gaps
  (`requires_engine` / audit missing-engine skip / live engine probe) use a
  **hammer/tool** in the Run slot with “not available” vs “not reproducible”
  messages. No separate Unavailable badge or strikethrough for those rows.
* **Studies list:** same padlock/hammer icons appear beside language badges when
  a study has data or missing-engine gaps. Narrow screens stack each study as a
  labeled card row instead of a broken multi-column grid.
* **Helpers:** [classify_shiny_run_gap()], [study_gap_flags_from_entries()],
  [lookup_replication_audit_engine_skip()].

## LaTeX tabular (texdoc) → HTML

* **Internal helper:** `latex_tabular_to_html()` converts author
  `\begin{tabular}...\end{tabular}` fragments (Stata `texdoc` / booktabs) into
  HTML tables for Shiny Display — `\multicolumn`, `\hline`, `\textit` /
  `\textbf` supported; no LaTeX or pandoc required. Study format steps can call
  it via `replicateEverything:::latex_tabular_to_html()`.

## Shiny startup: auto-update check for replicateEverything

* **Shiny:** On app start, compare the installed package `RemoteSha` (fallback:
  bundled `BUNDLE_SHA`) to the latest GitHub commit on
  `replicate-anything/replicateEverything@main`. When behind and auto-update is
  enabled, install via `remotes::install_github()`, refresh the deploy bundle
  when possible, and show an info banner asking for a browser refresh (Shiny
  workers may still need a restart). Network failures fail soft with a warning
  banner.
* **Opt out:** `options(replicate_shiny.auto_update_replicate_everything = FALSE)`
  or alias `options(replicateEverything.shiny_auto_update = FALSE)`. Default
  `TRUE` on bare Shiny Server; [run_shiny_app()] and `local.R.example` set
  `FALSE` for local / `load_all` development.
* **Helpers:** [shiny_auto_update_enabled()], [package_sha_update_status()],
  [ensure_replicate_everything_current()].

## Missing-engine messages: not available vs not reproducible

* **UX:** Incomplete steps that need a proprietary/system engine (e.g.
  Mathematica) now use two fixed phrasings:
  * baked output absent →
    `"{label} not available because of missing {Engine} engine"`
  * baked output present →
    `"{label} not reproducible because of missing {Engine} engine"`
* **Bug fix:** yaml field checks for deprecated `requires:` / `depends_on:` now
  use exact `[[ ]]` indexing. R's `$requires` was partial-matching the new
  `requires_engine:` field and hard-erroring normalize.
* **Yaml:** optional step field `requires_engine:` (e.g. `mathematica`), or
  `system_requirements:`; otherwise the engine is inferred from
  `blocked_reason:` text. Helpers: [missing_engine_message()],
  [step_missing_engine_message()], [step_required_engine()],
  [step_display_output_exists()].
* **Shiny:** blocked table/figure pills keep **Display** enabled when a baked
  artifact exists (badge "Not reproducible"); both Display and Run stay
  disabled (visually greyed) with badge "Unavailable" when the file is absent.
  Hover/title and the missing-artifact panel use the same messages. Display on
  "Not reproducible" rows wires the same `replication_action` handler as
  runnable rows so baked artifacts still open.
* **Run:** [stop_if_step_blocked()] / [run_replication()] raise the new
  phrasing instead of only `"This object cannot be created because of: ..."`.

## Surgical Dataverse pulls + Pattern B default

* **New:** [fetch_dataverse_file()] — exported surgical download by file id / URL
  (`api/access/datafile/<id>?format=original`). Prefer over full-dataset zips and
  study-local `httr::GET` helpers.
* **New:** `engine: dataverse` on transform steps runs [run_dataverse_access_step()]
  (file id + `outputs:` → disk) without inventing study download code.
* **Display:** [is_dataverse_access_prep_step()] matches Pattern C deposit/manifest
  only — Pattern B `access_data` → `outputs/*.dta` shows a data preview (or a
  clear missing-output note), not a false "deposit summary".
* **Shiny Live Run:** [run_live_display()] passes `force = TRUE` so the target
  step re-executes (matches [run_replication()] defaults).
* **Policy:** root `AI.md` + skills — Pattern B access → `outputs/` is default;
  full archive only when Pattern C is justified; Jiang noted for B migration.
* **Studies:** Blair (`14058927`) and Madsen/Voeten (`14008582`) use surgical
  Pattern B pulls; Madsen no longer downloads a full DVN zip for one CSV.

## Declared remote data wiring (no access_data step)

* **New:** [materialize_declared_data()] fetches files listed under
  `dataverse.files` or top-level `data_files:` (each entry: local `path` +
  `url`, or Dataverse `id`/`file_id` with optional `original: true`) into the
  study tree. Hooked from [prepare_study_run()] and [ensure_study_data_files()]
  so `given = "nothing"` obtains raw roots without a study-local download step.
* **Studies:** Jiang (`rep-10.1017-s0003055426101749`) drops `access_data` and
  relies on yaml wiring → `data/raw/*.dta`. Transform steps remain for merges /
  recodes under `outputs/`.
* **Merge:** folder study yaml `dataverse:` / `data_files:` now copy into
  registry stubs via [complete_folder_study_meta()].
* **Stata:** [run_stata_replication()] ensures `inputs:` as well as `data:` via
  [replication_data_paths()].

# replicateEverything 0.7.6

## Clearer Shiny / list_replications errors when study yaml cannot be fetched

* **UX:** When a registry stub has no `steps:` and the study repo
  `replication.yml` cannot be loaded, [list_replications()] now reports a
  specific reason (HTTP 404/403 private-or-missing, network failure, yaml
  parse/normalize errors such as deprecated `artifact:`, or a genuinely empty
  stub) instead of the generic empty-`steps:` normalize message. The bundled
  Shiny app surfaces the same package message.

## Stata batch preamble hardened against interactive prompts

* **Bug fix / hardening:** `stata_runner_lines()` now also emits `pause off`,
  `set linesize 255`, and re-asserts `set more off` / `pause off` immediately
  before running the study script under `capture noisily nobreak do`. This
  blocks `--more--` paging, live `pause` prompts, and Break-key `r(1)` continue
  dialogs during Windows `/e` batch runs. (`varabbrev off` is intentionally
  not forced: many deposits rely on default abbreviation matching.)
* **Windows (real Continue/Break fix):** `stata_batch_args()` now passes
  `/e /i /q` (not bare `/e`). Stata's `/i` suppresses the batch taskbar icon
  ([GSW] B.5). Without it, clicking that icon opens "cancel the batch job?",
  injects `--Break--` / r(1), and cascades "Would you like the batch job to
  continue?" dialogs as nested do-files unwind — `set more off` cannot stop
  that. `run_stata_system2()` keeps `processx` `windows_hide = TRUE` and no
  longer falls back to a *visible* processx child if hide setup fails.

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
