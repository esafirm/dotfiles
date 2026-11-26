# Capturing a stopped-app startup

This is a **recipe to adapt and verify**, not a script to run with unchecked placeholders. Follow [Perfetto's CLI reference](https://perfetto.dev/docs/reference/perfetto-cli) and [Android's startup environment guidance](https://developer.android.com/topic/performance/appstartup/setup-env) if device/version capabilities differ. Prefer an existing project Macrobenchmark test when it already captures the agreed scenario. Never install tools or operate a device without the user's consent.

1. Confirm one `adb devices` entry is authorized; pick its serial explicitly. Confirm the package is installed and resolve the launchable activity on **that device** (for example, `adb -s SERIAL shell cmd package resolve-activity --brief PACKAGE`). Confirm that `perfetto` is supported, enough device storage exists, and the destination local directory has been agreed. Do not silently build, deploy, clear data, or select a different device. Use a unique trace basename for every run; never overwrite a prior device or local trace.
2. Start tracing **before** the launch and wait for tracing sources to start. Adapt this simple-mode example, replacing `SERIAL`, `PACKAGE`, and `UNIQUE_NAME` with validated values; shell-quote actual values:

   ```sh
   adb -s SERIAL shell perfetto --background-wait --no-clobber \
     -o /data/misc/perfetto-traces/UNIQUE_NAME.perfetto-trace \
     -t 10s -b 32mb -a PACKAGE sched freq am wm view ss input
   adb -s SERIAL shell am force-stop PACKAGE
   adb -s SERIAL shell am start -n RESOLVED_COMPONENT
   ```

   Verify the recording started successfully before stopping/launching. Choose a longer duration if the app's meaningful startup exceeds ten seconds. `--background-wait` ensures the trace begins before the launch; `--no-clobber` prevents replacing a previous recording. If the device rejects a category or option, inspect `adb -s SERIAL shell perfetto --help` and adapt the recording; never present an empty or truncated capture as a successful startup trace. Capture scheduling, app/system atrace, and startup-related system events so analysis can identify both the launch and thread states.
3. Wait until recording has completed, then `adb -s SERIAL pull /data/misc/perfetto-traces/UNIQUE_NAME.perfetto-trace LOCAL_DIRECTORY/UNIQUE_NAME.perfetto-trace`. Check that the local file exists and contains the target launch before relying on it. Keep remote traces until the user agrees to removal; don't upload traces, clear global logcat, or leave an unbounded recording running.
4. Repeat stopped-app launches for timing under the same conditions before and after the change. Prefer a project's existing Macrobenchmark `StartupTimingMetric` cold-start test when appropriate; otherwise obtain a **validated** metric (e.g. trace startup metrics or device `Displayed` records), associating each observation with its run and checking units. `am start -W` reports ActivityManager wait values, which must not be mislabeled as TTID/TTFD. If trace capture or metrics are unavailable, give the user manual instructions for the Perfetto UI **Record New Trace** flow and explicitly distinguish diagnosis from a verified speedup.

If trace analysis requires a missing `./trace_processor` in the project root, tell the user the prerequisite and ask before fetching it; do not follow another skill's automatic-download step without this approval. Respect the analysis skill's facts-only scratchpad beside each trace; choose a local artifact directory where those files may be created.
