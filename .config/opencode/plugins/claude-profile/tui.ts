import { Plugin } from "@opencode/plugin/tui"
import { execFileSync } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

// Local-only: changes the profile used by the local service's Claude wrapper.
export default Plugin.define({
  id: "claude-profile",
  setup(context) {
    context.keymap.layer(() => ({
      mode: "global",
      commands: [{
        id: "claude-profile.select",
        title: "Switch global Claude profile",
        group: "Claude",
        palette: true,
        slash: { name: "claude-profile", arguments: true },
        async run(input) {
          try {
            const executable = join(homedir(), ".local/bin/opencode-claude")
            const current = execFileSync(executable, ["--profile", "status"], { encoding: "utf8" }).trim()
            const profile = input?.trim() || await context.ui.dialog.select({
              title: `Global Claude profile: ${current}`,
              current: current.split(" ")[0],
              options: [
                { title: "Personal", value: "personal", description: "~/.claude" },
                { title: "Work", value: "work", description: "~/.claude-work" },
              ],
            })
            if (!profile) return
            if (!["work", "personal", "status"].includes(profile)) {
              throw new Error("Use /claude-profile [work|personal|status]")
            }
            const selected = execFileSync(executable, ["--profile", profile], { encoding: "utf8" }).trim()
            context.ui.toast.show({
              title: "Global Claude profile",
              message: profile === "status" ? selected : `${selected}. Applies to new Claude processes, not running ones.`,
              variant: "success",
              duration: 6000,
            })
          } catch (error) {
            context.ui.toast.show({ title: "Claude profile", message: String(error), variant: "error" })
          }
        },
      }],
    }))
  },
})
