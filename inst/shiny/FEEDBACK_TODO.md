# Shiny feedback — deploy bake

Feedback (in-app form + CSV logging) is controlled by **baked deploy options**,
not `local.R`.

## Defaults

| Entry point | `live_run` | `feedback_enabled` (form + CSV) |
|-------------|------------|----------------------------------|
| `run_shiny_app()` | TRUE (interactive) | OFF |
| `save_local_shiny()` | TRUE (arg) | **TRUE** (server-friendly default) |

## Server deploy (one-liner)

```r
replicateEverything::save_local_shiny(
  "/path/to/ipi/replicate",
  live_run = FALSE,          # display-only when preferred
  feedback_enabled = TRUE    # default; comments ON
)
```

This writes:

1. `deploy-options.R` — sourced at app startup (no `local.R` required)
2. Baked literals at the top of the materialized `app.R` (marker block) so
   values remain even if `deploy-options.R` is skipped

Optional `local.R` may still override after `deploy-options.R`.

## Safe fallbacks

- GitHub issue links use hardcoded URL fallbacks when package helpers are
  missing from a stale worker namespace.
- Restart Shiny workers after `install_github()` + `save_local_shiny()`.

## Revert

If feedback causes trouble on the server, revert the feedback commit only:

```bash
git revert <feedback-commit-sha>
```

Then reinstall and redeploy `save_local_shiny(..., feedback_enabled = FALSE)`.
