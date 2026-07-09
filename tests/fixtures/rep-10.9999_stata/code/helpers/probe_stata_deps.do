version 17
* Probe-only: exit 0 when built-in summarize is available (no network).
cap which summarize
if _rc {
    exit 9
}
exit 0
