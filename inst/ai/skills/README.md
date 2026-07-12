# replicateEverything agent skills

**Canonical home** for the domain skills that teach an agent how to onboard and
maintain replication studies with this package. These ship inside the installed
package (`system.file("ai/skills", package = "replicateEverything")`) so anyone
who clones or installs replicateEverything gets the current guidance.

## Skills

| File | Skill name | Use for |
|------|------------|---------|
| `folder_replication.md` | `folder-replication` | Generic folder-backed study repo; **Step 1b DAG from original repo**; Step 4a dependency search + Step 4b `steps:` yaml |
| `APSR_to_replicateEverything.md` | `apsr-to-replicate-everything` | Flat APSR / Cambridge Dataverse deliveries → folder-backed study repo |

Each file is a self-contained Cursor Agent Skill (YAML frontmatter with
`name:` + `description:`, then the body).

## Single source of truth

These skills live **only** here. There are no Dropbox or `~/.cursor/skills`
copies to keep in sync. Discovery works through a tiny pointer skill
(`replicate-everything-studies`) on the personal skill path, which tells the
agent to open the relevant file from this folder before acting.

To update: **edit the file here and commit.** Nothing else to propagate — the
pointer resolves the path at run time (workspace `inst/ai/skills/` in the
monorepo, or `system.file("ai/skills", package = "replicateEverything")` from an
installed package).
