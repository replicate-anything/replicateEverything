# replicateEverything agent skills

**Canonical home** for the domain skills that teach an agent how to onboard and
maintain replication studies with this package. These ship inside the installed
package (`system.file("ai/skills", package = "replicateEverything")`) so anyone
who clones or installs replicateEverything gets the current guidance.

## Skills

| File | Skill name | Use for |
|------|------------|---------|
| `folder_replication.md` | `folder-replication` | Generic folder-backed study repo; **Step 1b DAG from original repo**; Step 4a dependency search + Step 4b `steps:` yaml; blocked steps; **Parents + Shiny Live Run** |
| `dataverse_to_replicateEverything.md` | `dataverse-to-replicate-everything` | Harvard Dataverse deposits → folder-backed study repo |
| `openicpsr_to_replicateEverything.md` | `openicpsr-to-replicate-everything` | OpenICPSR / ICPSR (often AER) deposits — download once, commit needed inputs, wrapper DAG |
| `include_study_in_registry.md` | `include-study-in-registry` | Contributor prepare + maintainer sync into central registry |
| `check_study_submission.md` | `check-study-submission` | Review / audit: Shiny "no steps", yaml hard errors, **surgical pulls / light-repo**, incomplete / proprietary steps |

Each file is a self-contained Cursor Agent Skill (YAML frontmatter with
`name:` + `description:`, then the body).

**Policy (see root `AI.md`):** study repos stay light; **Pattern B default** =
surgical Dataverse file-id pulls → `outputs/`; Pattern A materialize → `data/`
only when fetch is not a claimed step; full archive only when Pattern C
justified. OpenICPSR (no public file API): commit needed inputs only, still
yaml-declare. Blocked steps: `incomplete:` + `requires_engine:` or
`data_unavailable:` (audit skips). **Shiny Live Run runs the selected leaf
only** — bake+commit parent sinks (or track leaf inputs); local materialize
is not Live Run proof (`folder_replication.md` § Parents + Shiny Live Run).

**Public maintainer API:** `register_study()` / `refresh_registry()` /
`audit_everything()` / `audit_report()`. Contribute: `check_and_bake_study()` /
`build_study_outputs()`. Prefer these over unexported helpers
(`sync_study_to_registry`, `check_replication`, `fetch_dataverse_file`, …).

**Excel dual-sheet exports:** when onboarding Stata → Excel tables that keep a
formatted presentation sheet and a machine-readable numbers sheet, name the live
values sheet **`data_export`** (Display + substantive tests prefer it when present).

**File provenance headers:** every code file gets a short top-of-file comment
naming one of `connector` / `author-original` / `translation (X -> Y)` /
`author-edited` (see `folder_replication.md` § File provenance headers).
Untouched vendored trees (e.g. `code/original/`) get one folder-level
`README.md` instead of per-file headers.

## Single source of truth

These skills live **only** here. There are no Dropbox or `~/.cursor/skills`
copies to keep in sync. Discovery works through a tiny pointer skill
(`replicate-everything-studies`) on the personal skill path, which tells the
agent to open the relevant file from this folder before acting.

To update: **edit the file here and commit.** Nothing else to propagate — the
pointer resolves the path at run time (workspace `inst/ai/skills/` in the
monorepo, or `system.file("ai/skills", package = "replicateEverything")` from an
installed package).

## Package releases (agents editing replicateEverything)

Do **not** auto-bump `DESCRIPTION` / `NEWS` on every tiny change. Bump when
releasing a **coherent set** of changes; prefer **patch** (`0.7.y`); stay on
`0.x` until a deliberate 1.0. Minor (`0.8.0`) only for larger coherent
releases, sparingly. Batch when possible. See README **Project status** and
`NEWS.md` (0.7.17 versioning note).
