---
name: second-brain
description: Read and update the BandLab Android knowledge base at ~/second-brain. Use when answering questions about BandLab app architecture, navigation, players, ANRs, concurrency, tooling or past investigations, or when a session produces findings worth keeping.
---

# Second Brain

A vault of linked Markdown notes on the BandLab Android codebase, at
`~/second-brain`. Agents write it, people and agents read it. It is a git repo
with a private remote, so the same path works on this Mac and on cloned boxes.

Its own rules live in `~/second-brain/AGENTS.md`. Read that file before writing
anything. The summary below is a reminder, not a replacement.

## Reading

1. Open `~/second-brain/index.md` to see the folders.
2. Open the folder `index.md` for the area you care about. Each note has a
   one-line description there.
3. Read the note.
4. If the index is inconclusive, use ripgrep over the vault. Do not rely on
   wikilinks, the vault uses relative Markdown links.

Use the vault before researching a BandLab question from scratch, and cite the
note path when you answer from it.

## Writing

Follow `~/second-brain/AGENTS.md` for frontmatter, folder choice, link style,
the `# See also` section and index upkeep. Then:

- Append what changed to `meta/research-log.md` under today's date, newest first.
- Never edit anything under `raw/`.
- When no folder fits, ask instead of inventing one.

## Git

- Run `git -C ~/second-brain pull --rebase` before writing.
- Commit only the notes you changed, not unrelated vault state.
- Message format: `Second brain - <subject>` with a short plain description.
- No AI attribution in the commit.

## New machine

`git clone git@github.com:esafirm/bandlab-brain.git ~/Documents/bandlab/Bandlab-brain`
then `ln -sfn ~/Documents/bandlab/Bandlab-brain ~/second-brain`. That is the
whole setup, the vault is just Markdown.
