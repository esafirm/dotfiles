---
name: instaphone
description: Use only when the user explicitly asks for `instaphone` or asks whether to use it. Run Android APK verification, instrumentation tests, UI flows, bug reproductions, or benchmarks on the Free Instabox Android box instead of interrupting an active local device session. Not the default for generic Android test requests.
---

# Instaphone

`instaphone` is the named Instabox machine. It runs Android 14 in an x86_64 container, not an Android Studio AVD. It uses software rendering and has no Google Play Services or ARM translation. Prefer it when asked to choose between it and a local device already in use. An explicit target wins. If the build or test needs something the box can't provide, report the blocker rather than silently using another device.

Runtime and rendering move off the Mac, but local builds and APK transfers still cost time and resources. Free is suitable for on-demand jobs, not continuous uptime. Do not upgrade or provision a paid machine.

## Start a job

1. Read `instabox get instaphone --json` without waking it. Verify `.template.id == "android"`. If it is missing, consult the `instabox` skill and ask before creating a replacement. If `.cooldownUntil` is in the future, report that time and stop.
2. Record whether you woke it. For a suspended box use `instabox resume instaphone`; for a stopped box use `instabox start instaphone`. Leave a running box alone. Confirm Android has booted and `adb devices -l` shows exactly one online device on the box. Use that serial explicitly.
3. Use an existing APK when verifying that artifact. Otherwise build locally using the project's normal workflow. Build remotely only when requested. Check the app and test APKs for native ABIs before upload: no native libraries or `x86_64` are supported; ARM-only APKs are not. Check for Play Services dependencies when relevant.

## Deploy, run, and collect

- Upload only the required APKs with `instabox push`. Run `adb -s SERIAL install -r APK` **inside the box**. Preserve app data by default. Never clear data or uninstall to resolve a signing mismatch without approval. Use `install-multiple` for a compatible split set.
- For instrumentation, install the app and test APK, use `adb -s SERIAL shell pm list instrumentation` to find the runner, then run `adb -s SERIAL shell am instrument -w -r TEST_PACKAGE/RUNNER`. Inspect the instrumentation output for failed or zero tests, not just the shell exit code. Use `instabox ssh instaphone -- '…'` for commands that may exceed the `exec` timeout. Keep the Free runtime cap in mind.
- For UI or bug reproduction, use ADB, Android CLI, or the dashboard's **Computer** tab. Don't run multiple UI drivers against the same device simultaneously. Save targeted logs, screenshots, or test reports and pull them back before pausing. For example, use `adb -s SERIAL exec-out screencap -p > screenshot.png` on the box, then `instabox pull instaphone /data/home/screenshot.png`. Never pass binary output through `instabox exec` stdout.
- If a local tool needs ADB, run `instabox port-forward instaphone 15555:5555`, verify the host port is free first, and connect with `adb connect 127.0.0.1:15555`. Select that serial explicitly. Disconnect and close the tunnel after use. Never publish ADB.
- For benchmarks, record APK/build, Android version and ABI, relevant setup, and cold or warm state. Use repeated, like-for-like runs. Treat Instaphone timings as evidence about Instaphone, not physical-device audio latency, rendering performance, or local AVD speed. For offload comparisons, measure Mac CPU/RAM and wall time separately and distinguish setup from warm runs.

## Optional tools on the box

- Android CLI and `maestro-runner` are installed on `instaphone`. Check their versions or availability before using them. Use the `android-cli` skill for Android CLI usage and the official Linux x86_64 installer if provisioning a replacement.
- `blnav` is optional for BandLab workflows. It runs as a compiled Linux x86_64 executable with its flow files under `$HOME/.local/share/blnav`. To refresh it, cross-compile from the authorized local checkout with `bun build --compile --minify --target=bun-linux-x64-baseline src/cli.ts --outfile <staging-dir>/blnav`. Deploy only the executable to `$HOME/.local/share/blnav/bin/blnav` and the required flow assets under `$HOME/.local/share/blnav/flows`. Use `tar --no-mac-metadata --no-xattrs` when packaging flows on macOS. Verify with `blnav list` and `blnav lint <destination>`.
- Never copy or persist `.env`, tokens, or other credentials on the box. Some `blnav` flows require variables at preflight even when the app is already signed in. For those flows, use local `blnav` with the private ADB tunnel and local credentials, or choose a flow that doesn't require secrets. Do not put secrets in Instabox command arguments, reports, or logs.

## Finish

Report the target, artifact, test result, and any evidence. If you woke the box for a one-shot job, suspend it after collecting results. Leave it running if it was already running or the user is debugging interactively. Clean up only the tunnel you opened. Respect the Free limits: 30-minute idle pause, a 2-hour initial runtime limit that can extend up to 8 hours with use, and a cooldown after reaching the limit. Do not try to bypass those limits.
