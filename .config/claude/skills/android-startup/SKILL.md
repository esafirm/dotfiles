---
name: android-startup
description: Manually investigate, improve, and verify native Android app startup using Perfetto traces.
disable-model-invocation: true
slash: true
metadata:
  opencode/autoinvoke: false
---

# Android startup

Run this workflow only when invoked as `/android-startup`. Arguments may identify an app project, package, device, launch scenario, or existing Perfetto trace; infer only facts you can verify. This skill coordinates measurement and changes; use `perfetto-trace-analysis` for root-cause investigation, `perfetto-sql` for additional queries, and `nolambda-android-dev` when touching a native Android project. Do not duplicate or weaken their analytical protocols. If their setup instructions suggest an automatic download, **ask first**: this workflow does not authorize silent installations.

## 1. Establish the case

- Identify the target project (if any), package, device, build variant, launcher/activity or requested navigation journey, and available traces. Inspect code/configuration rather than guessing identifiers. If multiple devices or packages are plausible, ask which one. A trace can be analyzed without source access; code changes are limited to native Android Kotlin/Java, Views, and Compose projects, not Flutter.
- Default to a **stopped-app launch**: the installed app's process is stopped, its data remains intact, and the launcher activity starts. Data clearing, reinstalling, and first-install launches are **different scenarios** and require an explicit request. For other activities or journeys, agree on a reproducible launch path first. Never assume `force-stop` clears app data.
- For comparable measurements use the same device, app variant, launch path, data state, network conditions, and approximate device load/temperature. Prefer a representative release/profileable build; label debug measurements as non-representative. Do not change build setup or add instrumentation merely to obtain measurements without an approved plan.
- Before **any** device-affecting action (force-stop, launch, trace recording, installing an app, etc.), explain what will happen and obtain consent. Do not clear app data, reinstall, or alter a user's device setup as a shortcut. Check that required tools and the intended app/device are available; do not silently download tools or edit `.gitignore` to accommodate them.

## 2. Collect baseline evidence

- If a trace is supplied, prefer it. Check that it covers the target package and a relevant startup. If the analysis skill's beside-the-trace scratchpad would write into the app repository or an undesired location, ask to copy the trace into a user-chosen local directory outside the repo; keep the original untouched. Do not overwrite existing traces or analysis files.
- Otherwise ask for a local artifact directory outside the app repository, obtain device consent, and follow [the capture recipe](references/capture.md). If automated capture is unavailable, provide the manual Perfetto capture alternative and explain what evidence is missing. Do not upload traces or place them in source control without explicit permission.
- Prefer an existing Macrobenchmark startup test for repeated timing and trace collection when it measures the same scenario. Otherwise collect at least five stopped-app launches per condition if feasible, plus representative Perfetto traces for the baseline and candidate. Use the **same** timing method before and after; report individual values, median, and spread, not just a single launch. Record sample count, launch method, device/build details, and failures. Do not treat `am start -W` as automatically equivalent to TTID or TTFD; do not trust the local `startup-check` script's timing without validating it against trace evidence.
- Read and follow `perfetto-trace-analysis` for each relevant trace, including its evidence scratchpad and startup metrics. Use observed TTID/TTFD when available and explain what each measures; do not require TTFD, add `reportFullyDrawn` automatically, or infer readiness from first frame. If no startup metric is present, still analyze the trace and state what cannot be quantified. Separate app-critical-path work from external system/device stalls. An expensive slice alone is not proof of CPU work or causality.

## 3. Propose, then change

- Correlate verified trace events with the Android source and initialization graph; confirm whether the work is necessary before first display or usability. Check functional trade-offs: moving work after first frame must not make the app look faster while delaying necessary content or breaking behavior. If the bottleneck is external to the app, or source is unavailable, report that rather than inventing an app fix.
- Present the evidence (trace and timestamps), likely critical path, one independently testable fix, expected effect, risks, and exact files/areas to change. **Wait for approval before editing.** An approval covers that plan; ask again if the plan changes materially. If there is no comparable device/build for remeasurement, disclose that and implement only on explicit approval to proceed without verification.
- Change one cause at a time. Follow project conventions; compile/test affected modules and relevant behavior. Do not automatically add benchmarking modules, startup instrumentation, dependencies, or change app data. Preserve unrelated work.

## 4. Remeasure and report

- Recapture and analyze candidate traces and repeat the same launch protocol after a change when possible. Compare like-for-like metrics, per-run timings, medians, spread, relevant slices/thread states, and user-visible readiness; distinguish an observed difference from a demonstrated cause. If the change merely shifts work later or degrades readiness, call out the trade-off.
- Report the scenario, baseline and candidate measurements, trace/scratchpad paths, evidence for or against the fix, tests, limitations, regressions, and remaining bottlenecks. Never claim an improvement when comparison was impossible or the evidence is inconclusive. Propose the next bottleneck as a separate iteration rather than bundling unmeasured changes.
