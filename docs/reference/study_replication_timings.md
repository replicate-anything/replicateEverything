# Study-local bake timings (`outputs/replication_timings.json`)

Successful
[`run_replication()`](https://replicate-anything.github.io/replicateEverything/reference/run_replication.md)
/ bake runs append elapsed seconds per step so audit timeouts and Shiny
hourglass warnings can report the last known completion time instead of
only the audit patience cap.
