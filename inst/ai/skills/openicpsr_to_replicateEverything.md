---
name: openicpsr-to-replicate-everything
description: >-
  Onboard an OpenICPSR / ICPSR (often AER/AEA) replication deposit into a
  folder-backed replicateEverything study repo. Use when the deposit is on
  openicpsr.org, has no public per-file API, or the user mentions OpenICPSR /
  ICPSR / AEA Data Editor packages.
---

# OpenICPSR / ICPSR → replicateEverything

Companion to `folder_replication.md` (layout, DAG, yaml) and
`dataverse_to_replicateEverything.md` (Dataverse fetch patterns). OpenICPSR is
**not** Harvard Dataverse: there is usually **no** public per-file fetch API
(Cloudflare / JS-gated project page). Workflow differs mainly in **how inputs
land on disk**.

**Gold OpenICPSR examples:** `rep-10.1257-aer.20250166` (Mathematica gaps);
`rep-10.1257-aer.20240673` (proprietary-data gaps when onboarded).

## Start from an OpenICPSR project id

Given only a project id (e.g. `236844`), build the browser URLs and the local
drop path. **Do not invent a live-fetch step** in the study yaml — OpenICPSR has
no public surgical file API analogous to Dataverse `api/access/datafile/<id>`.

### URL templates

Replace `{id}` with the numeric project id and `{Vn}` with the version
(`V1`, `V2`, …). Folder path is the usual AEA “Replication-package-repository”
layout; adjust the `path=` query if the project UI shows a different root folder.

| Purpose | URL |
|---------|-----|
| **Browse folder** | `https://www.openicpsr.org/openicpsr/project/{id}/version/{Vn}/view?path=/openicpsr/{id}/fcr:versions/{Vn}/Replication-package-repository&type=folder` |
| **Download (terms gate)** | `https://www.openicpsr.org/openicpsr/project/{id}/version/{Vn}/download/terms?path=/openicpsr/{id}/fcr:versions/{Vn}/Replication-package-repository&type=folder` |

Example (`236844`, `V1`):

```
https://www.openicpsr.org/openicpsr/project/236844/version/V1/download/terms?path=/openicpsr/236844/fcr:versions/V1/Replication-package-repository&type=folder
```

There is **no stable anonymous zip URL**. After login + terms acceptance in a
real browser, the UI issues a one-shot download (often a zip). Agents should
treat that as a **human-assisted** step, not a package API.

### Headless / curl reality (do not fight this)

Probed with `curl` / `Invoke-WebRequest` (no ICPSR session cookies):

| Observation | Meaning |
|-------------|---------|
| `HTTP 403` + `Cf-Mitigated: challenge` | Cloudflare bot challenge — HTML challenge page, **not** a zip |
| `302` → `/openicpsr/login` → `login.icpsr.umich.edu` (Keycloak “Sign in to icpsr”) | Terms/download requires an **ICPSR account** |
| Stripping `/terms` → `/download?...` | Often `404` without a prior authenticated terms accept |
| Saved “zip” that starts with `<!DOCTYPE html>` | Challenge or login HTML — delete it |

**Do not** automate Keycloak login or Cloudflare challenges. Ask the user to
download in a browser, then continue from the local path below.

### Preferred local path (monorepo)

```
original_studies/{id}-V1/          # unzipped deposit (authoritative working copy)
original_studies/{id}-V1.zip       # optional: keep the zip beside the folder
```

Examples:

- Project `236844` V1 → `original_studies/236844-V1/`
- Project `239169` V1 → `original_studies/239169-V1/` (or existing `239169-V1` sibling)

Agents: before asking the user, search for `{id}` / `Replication-package` under
`original_studies/` and Downloads. If absent, **pause deposit-dependent work**
and report the exact drop path. Study repo (`rep-*`) stays light — do **not**
commit the full unzip there.

## Workflow (short)

```
- [ ] 1. Resolve project id → download/terms URL (above). Download **once** in a
      browser (ICPSR login + terms) → unzip under monorepo
      `original_studies/{id}-V1/` (optional zip beside it). Do not commit full bulk
      into the study repo.
- [ ] 2. Read author README / DAS; map README tables (figure/table → script → output)
- [ ] 3. Reconstruct wrapper-granularity DAG (Step 1b) — **not** one node per policy /
      micro-script when wrappers batch them
- [ ] 4. Grep whole deposit for mathematica / matlab / proprietary / restricted data
- [ ] 5. Size needed inputs; commit **only** what declared steps need under `data/`
      (≤50 MB rule); yaml-declare paths; do **not** ship unused archive bulk
- [ ] 6. Write `replication.yml` (`collections: [AER]` when AEA journal); mark blocked
      steps (`incomplete:` + `requires_engine:` or `data_unavailable:`)
- [ ] 7. Thin runners; bake runnable steps; registry sync
```
## Light repo (OpenICPSR)

| Prefer | Avoid |
|--------|--------|
| Keep full unzip in `original_studies/` | Copying the whole deposit into `rep-*` |
| Commit only inputs listed in yaml `inputs:` / `data:` | Ethics / instruments / unused appendix blobs |
| Yaml-declare every committed path | Undocumented files sitting in `data/` |
| Check folder sizes early (often whole deposit < 50 MB) | Inventing a fake live-fetch step when no API exists |

This is still **wire, don’t ship**: yaml is the contract; committed bytes are the
fallback when OpenICPSR cannot be fetched surgically. When a public file URL
exists, prefer Pattern B (access → `outputs/`) like Dataverse.

## DAG from README tables

AER/OpenICPSR READMEs often include explicit tables mapping each paper object to
a producing `.do` / script and output name. **Trust those tables**, then verify
with file I/O. Prefer **wrapper-level** transform steps (e.g. one
`compute_mvpf_main`) feeding thin table/figure runners — not ~100 per-policy
nodes that the author never runs individually.

## Blocked steps (engines vs proprietary data)

**DAG membership:** put a step in `steps:` only if it is a **replication claim**
(Display / audit). Proprietary prep (or other blocked stages) that is **not** on
the path to a claimed output belongs in README / study popup — **not** as orphan
Unavailable nodes in the DAG.

Before marking a step unavailable, **search the deposit and study repo for
precomputed gold** (results folders, committed `outputs/`, paper supplements).
Empty placeholders are common — that is not the same as “no gold anywhere.”

| Class | Yaml | Shiny / audit |
|-------|------|----------------|
| Missing system engine | `incomplete: true` + `requires_engine: mathematica` (+ `blocked_reason:`) | Hammer in Run slot; “not available” vs “not reproducible”; partial-replication popup; **audit skips** |
| Proprietary / restricted data | `incomplete: true` + `data_unavailable: proprietary` (+ `blocked_reason:`) | Padlock in Run slot + study popup; DAG mark; **audit skips** (unavailable ≠ success/failure) |
| Ordinary incomplete | `incomplete: true` + `blocked_reason:` only | Same skip / grey behavior; generic message |

```yaml
# Engine gap (example)
- id: compute_mvpf_main
  type: transform
  incomplete: true
  requires_engine: mathematica
  blocked_reason: >
    Requires wolframscript (Mathematica) for learning-by-doing policies.

# Proprietary data gap (intended contract; parallel to requires_engine)
- id: tab_restricted
  type: table
  incomplete: true
  data_unavailable: proprietary
  blocked_reason: >
    Analysis uses proprietary microdata not included in the OpenICPSR deposit.
```

`incomplete: true` alone already excludes a step from baking and from
`audit_everything()` (neither success nor failure — not attempted). Prefer the
structured fields so Shiny can classify engine vs data gaps.

## Collections

Use `collections: [AER]` (or other AEA journal tags) when citation metadata cites
*American Economic Review* / AEA — including OpenICPSR-hosted AEA deposits.

## See also

- `folder_replication.md` — Step 1b DAG, Step 5 data, blocked-step field table
- `check_study_submission.md` — lean materials + incomplete-step review
- `dataverse_to_replicateEverything.md` — when the deposit **is** on Dataverse
- Root `AI.md` — Pattern A/B/C + light-repo hard rules
- Onboarding scratch (monorepo): `onboarding_notes/openicpsr-aer-239169.md`
