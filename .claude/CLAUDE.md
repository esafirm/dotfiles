## Gradle Build Cache

When a Gradle build fails and all tasks report `UP-TO-DATE`, **do not assume cache is the
problem** — the failure is almost certainly a real compilation error in your changes; check
the full build output. If you genuinely suspect a stale cache, **ask the user for confirmation**
before re-running with `--rerun-tasks` or any cache-busting flag.
