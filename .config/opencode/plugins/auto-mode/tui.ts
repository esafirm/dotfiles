import { Plugin } from "@opencode/plugin/tui"
import { readFileSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

// Toggle auto-accept permissions from the TUI.
//
// This flips session.permissions between "prompt" and "autoaccept" in the
// global cli.json. The TUI watches that file and reloads it on change, so the
// switch applies immediately: the prompt footer shows "auto" and pending
// permission requests are accepted without a prompt.

type PermissionMode = "prompt" | "autoaccept"

const VALUE = /("permissions"\s*:\s*)"(?:prompt|autoaccept)"/
const CURRENT = /"permissions"\s*:\s*"(prompt|autoaccept)"/

function configPath(): string {
  const base = process.env.XDG_CONFIG_HOME?.trim() || join(homedir(), ".config")
  return join(base, "opencode", "cli.json")
}

function setMode(text: string, mode: PermissionMode): string | undefined {
  if (VALUE.test(text)) return text.replace(VALUE, `$1"${mode}"`)

  // Plain JSON: rewrite structurally when there is nothing to replace yet.
  try {
    const data = JSON.parse(text)
    if (typeof data !== "object" || data === null || Array.isArray(data)) return undefined
    const session =
      typeof data.session === "object" && data.session !== null && !Array.isArray(data.session) ? data.session : {}
    return JSON.stringify({ ...data, session: { ...session, permissions: mode } }, null, 2) + "\n"
  } catch {
    // JSONC or unparsable: keep the edit narrow and inside the session object.
  }

  const match = /"session"\s*:\s*\{/.exec(text)
  if (!match) return undefined
  const offset = match.index + match[0].length
  if (/^\s*\}/.test(text.slice(offset))) return undefined
  return text.slice(0, offset) + `\n    "permissions": "${mode}",` + text.slice(offset)
}

function isPlainJson(text: string): boolean {
  try {
    JSON.parse(text)
    return true
  } catch {
    return false
  }
}

export default Plugin.define({
  id: "auto-mode",
  setup(context) {
    const toggle = () => {
      const path = configPath()
      const fail = (message: string) =>
        context.ui.toast.show({ title: "Auto mode", message, variant: "error" })

      let text: string
      try {
        text = readFileSync(path, "utf8")
      } catch {
        fail(`Could not read ${path}`)
        return
      }

      const next: PermissionMode = CURRENT.exec(text)?.[1] === "autoaccept" ? "prompt" : "autoaccept"
      const updated = setMode(text, next)
      if (updated === undefined) {
        fail(`Could not update ${path}`)
        return
      }
      // The file may be JSONC (comments, trailing commas). Only refuse the
      // write when the current file is plain JSON and the edit would break it.
      if (isPlainJson(text) && !isPlainJson(updated)) {
        fail(`Refusing to write invalid JSON to ${path}`)
        return
      }

      try {
        writeFileSync(path, updated, "utf8")
      } catch {
        fail(`Could not write ${path}`)
        return
      }

      context.ui.toast.show({
        title: "Auto mode",
        message: next === "autoaccept" ? "Auto-accept permissions enabled" : "Auto-accept permissions disabled",
        variant: "success",
      })
    }

    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "auto-mode.toggle",
          title: "Toggle auto-accept permissions",
          group: "Session",
          bind: "<leader>p",
          palette: true,
          slash: { name: "auto" },
          run: toggle,
        },
      ],
    }))
  },
})
