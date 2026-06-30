## Android Studio MCP Tool Names

When searching this Android codebase, always use the `android-studio_` prefixed tool names (NOT bare `mcp__studio__*` or any other prefix):

### Search (text & regex in files)
- `android-studio_search_text`, `android-studio_search_regex`
- `android-studio_search_in_files_by_text`, `android-studio_search_in_files_by_regex`

IMPORTANT: For `android-studio_search_text`, the parameter is "q"

### File Discovery
- `android-studio_find_files_by_name_keyword`, `android-studio_find_files_by_glob`
- `android-studio_search_file`, `android-studio_search_symbol`

### Read / Edit / Navigate
- `android-studio_read_file`, `android-studio_get_all_open_file_paths`, `android-studio_open_file_in_editor`
- `android-studio_replace_text_in_file`, `android-studio_reformat_file`, `android-studio_rename_refactoring`

### Code Analysis (diagnostics, structure, dependency)
- `android-studio_get_file_problems` — lint/error diagnostics in a file
- `android-studio_get_project_dependencies` — all project library dependencies
- `android-studio_get_project_modules` — all modules with types
- `android-studio_get_repositories` — VCS roots in the project

### Code Insight (symbol resolution)
- `android-studio_get_symbol_info` — Quick Documentation at a given position
- `android-studio_search_symbol` — semantic class/method/field lookup

### Project / Utility
- `android-studio_list_directory_tree`
- `android-studio_create_new_file`, `android-studio_execute_terminal_command`

## Android Studio MCP projectPath Requirement

All `android-studio_*` MCP tools require `projectPath` to be provided, even though the schema marks it optional. Without it, the tools fail with a confusing `entries`-related schema error (`MCP error -32602: Structured content does not match the tool's output schema: data must have required property 'entries'`). Always pass `projectPath`.

## Retry Discipline for MCP Tools

When searching or exploring the codebase: first try with `android-studio_*` MCP tools. If they fail, check for mistakes (e.g. missing `projectPath`) and retry once. If still failing, fall back to `bash` (rg/grep/find). If MCP tools return results, **do not** run other tools unless explicitly asked for more detail.
