---
name: nolambda-android-dev
description: Context and tooling rules for Android native projects (Kotlin/Java, Gradle, AndroidManifest, Jetpack Compose) in Android Studio or IntelliJ IDEA. Use whenever working in an Android native codebase — Gradle builds, .kt/.java sources, layouts, resources, or IDE MCP calls. Do not use for Flutter projects.
---

# nolambda Android Dev

Context for Android native work: Kotlin/Java projects built with Gradle in Android Studio or
IntelliJ IDEA. **Not** for Flutter.

## IDE MCP (Android Studio / IntelliJ IDEA)

- **`projectPath` is mandatory.** Every IDE MCP tool call must include `projectPath` set to the
  absolute path of the project root. Without it the call fails.
- **Do not use MCP for file I/O.** Reading files, writing/creating files, and replacing text all
  go through normal tooling (`read_file`, `write_file`, `edit_file`, shell) — never the MCP
  `read_file` / `create_new_file` / `replace_text_in_file` tools.

Reserve the IDE MCP for what only the IDE knows: symbol, module, and dependency queries,
project-structure inspection, file problems/inspections, run configurations, and refactorings.
