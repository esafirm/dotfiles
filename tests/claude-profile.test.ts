import { beforeEach, expect, mock, test } from "bun:test"

const calls: string[][] = []
const execute = mock((_path: string, args: string[]) => {
  calls.push(args)
  return args[1] === "personal" ? "personal (/fixture/.claude-personal)\n" : "work (/fixture/.claude)\n"
})
mock.module("node:child_process", () => ({ execFileSync: execute }))
mock.module("@opencode/plugin/tui", () => ({ Plugin: { define: (plugin: unknown) => plugin } }))
const { default: plugin } = await import("../.config/opencode/plugins/claude-profile/tui")
const select = mock(async () => "personal" as string | undefined)
const toast = mock((_options: { variant: string }) => {})
let command!: { run: (input?: string) => Promise<void> }
plugin.setup({
  keymap: { layer: (factory: () => { commands: typeof command[] }) => { command = factory().commands[0] } },
  ui: { dialog: { select }, toast: { show: toast } },
} as any)

beforeEach(() => {
  calls.length = 0
  toast.mockClear()
  select.mockClear()
  select.mockResolvedValue("personal")
})

test("picker switches without shell interpolation or model calls", async () => {
  await command.run()
  expect(select).toHaveBeenCalledTimes(1)
  expect(calls).toEqual([["--profile", "status"], ["--profile", "personal"]])
})

test("explicit profile bypasses picker", async () => {
  await command.run("work")
  expect(select).not.toHaveBeenCalled()
  expect(calls.at(-1)).toEqual(["--profile", "work"])
})

test("invalid arguments never reach the executable", async () => {
  await command.run("personal; echo bad")
  expect(calls).toEqual([["--profile", "status"]])
  expect(toast.mock.calls[0][0].variant).toBe("error")
})

test("cancel leaves selection unchanged", async () => {
  select.mockResolvedValueOnce(undefined)
  await command.run()
  expect(calls).toEqual([["--profile", "status"]])
  expect(toast).not.toHaveBeenCalled()
})

test("status does not open picker or write a profile", async () => {
  await command.run("status")
  expect(select).not.toHaveBeenCalled()
  expect(calls.every((args) => args[1] === "status")).toBe(true)
})
