# replicateEverything agent skills

**Canonical home** for the domain skills that teach an agent how to onboard and
maintain replication studies with this package. These ship inside the installed
package (`system.file("ai/skills", package = "replicateEverything")`) so anyone
who clones or installs replicateEverything gets the current guidance.

## Skills

| File | Skill name | Use for |
|------|------------|---------|
| `folder_replication.md` | `folder-replication` | Generic folder-backed study repo; **Step 1b DAG from original repo**; Step 4a dependency search + Step 4b `steps:` yaml |
| `dataverse_to_replicateEverything.md` | `dataverse-to-replicate-everything` | Harvard Dataverse deposits → folder-backed study repo |
| `include_study_in_registry.md` | `include-study-in-registry` | Contributor prepare + maintainer sync into central registry |
| `check_study_submission.md` | `check-study-submission` | Review / audit: Shiny "no steps", yaml hard errors, **surgical pulls / light-repo**, missing outputs |

Each file is a self-contained Cursor Agent Skill (YAML frontmatter with
`name:` + `description:`, then the body).

**Policy (see root `AI.md`):** study repos stay light; **Pattern B default** =
surgical Dataverse file-id pulls → `outputs/`; full archive only when Pattern C
is justified. Jiang (`rep-10.1017-s0003055426101749`) is Pattern A (surgical
file URLs into `data/raw/`) and should migrate toward Pattern B when convenient.

## Single source of truth

These skills live **only** here. There are no Dropbox or `~/.cursor/skills`
copies to keep in sync. Discovery works through a tiny pointer skill
(`replicate-everything-studies`) on the personal skill path, which tells the
agent to open the relevant file from this folder before acting.

To update: **edit the file here and commit.** Nothing else to propagate — the
pointer resolves the path at run time (workspace `inst/ai/skills/` in the
monorepo, or `system.file("ai/skills", package = "replicateEverything")` from an
installed package).
