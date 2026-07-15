# Shiny feedback — re-enable in-app form

In-app feedback (text box + submit) is **disabled by default** in 0.6.3 pending
reliable Shiny worker namespace reload on shiny2.wzb.eu.

## Current behavior

- **Feedback tab** shows static GitHub issue links (bug / feature / other).
- Hardcoded URL fallbacks when `shiny_feedback_github_category_url` is missing
  from a stale worker namespace (e.g. installed 0.6.2 session).
- **No in-app form** unless `options(replicate_shiny.feedback_in_app_enabled = TRUE)`.
- **CSV logging off** unless `options(replicate_shiny.feedback_enabled = TRUE)` or
  `REPLICATE_SHINY_FEEDBACK_ENABLED=1`.

## Re-enable when

1. Server admin can restart Shiny workers after `install_github()`, **or**
2. Namespace stale detection / worker reload is fixed.

Then:

1. Set `feedback_enabled = TRUE` in `save_local_shiny()` / `deploy-options.R` if CSV logging is desired.
2. Set `options(replicate_shiny.feedback_in_app_enabled = TRUE)` in `local.R` or deploy options.
3. Remove or update the `# TODO(replicate-shiny-feedback)` comment in `app.R`.
