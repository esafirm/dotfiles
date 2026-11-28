---
name: instabox-snapshots
description: Use when the user wants to save an instabox box's state and load it later — "save a snapshot", "checkpoint this box", "restore/load from a snapshot", "start a new box from my setup", "clone this box", "a box from my Docker image". Covers instabox snapshot save/import/ls/files/rm, create --snapshot and fork.
metadata:
  installed-by: instabox
---

# instabox snapshots: save and load

A snapshot is a saved copy of a box's disks (root disk and `/data`), private to the account. Load it by creating a new box from it. Snapshots hold disks only: running processes and memory are not saved (use `instabox suspend` for that).

## Save

```sh
instabox snapshot save work --name work-ready --description "deps installed, repo cloned"
```

- A running box is saved live, without stopping it: the snapshot is `pending` in `instabox snapshot ls` until its disks finish uploading (`--no-wait` returns at once).
- Do not stop the box first: `stop` ends every process in it. A live snapshot is like a clean power cut: what is on disk is kept, what programs hold only in memory is not. Only if the server answers that this box must be stopped, or if a program must write its data to disk first (a database mid-write), run `instabox stop work`, save, then `instabox start work`.
- A running GPU box is never saved live: the save answers `409 operation_conflict` ("stop it first"). `instabox snapshot save work --name work-ready --restart` stops it, saves it and starts it again (also after a failed save), one stderr line per step; its processes must be started again afterwards. `--restart` never stops a box the server saves live.
- `--root-only` saves just the root disk (smaller; `/data` is not included).
- A disk snapshot includes credential files written by applications, tool sign-ins, and historical Vault files; a suspend snapshot can also retain credentials in process memory. Org Secrets reach the box only as placeholders, so a snapshot holds none of their values, but anything an app or a person wrote to disk is kept. Do not describe snapshots as credential-free. Review copied credentials and rotate upstream when required before sharing or retaining them.
- Pick names that say what is inside (`node20-playwright`, `api-db-seeded`); names must be unique among your snapshots.

## Load

```sh
instabox snapshot ls                                    # your snapshots: id, name, root/data size, source
instabox create --name work2 --snapshot work-ready
instabox exec work2 -- ls /data/home                    # same root disk and /data as when saved
```

`--snapshot` takes a snapshot name or its `sn_...` id.

## Look inside without starting anything

```sh
instabox snapshot files work-ready /etc                 # list a directory of the root disk
instabox snapshot files work-ready /etc/os-release      # print a text file
```

This reads the snapshot's root disk only; `/data` (and HOME) are not browsable here. To check files under `/data`, load the snapshot into a box and use `instabox exec`.

## Copy a box

`instabox fork` does it in one command: it copies a running or stopped box into a new box (or `--count` up to 5, named `NAME-1` to `NAME-N`) with the same template and size and waits until it runs. The server copies the disks on the box's host and boots the copy in a few seconds, with no snapshot; memory and running programs are not copied. With an older server that has no native fork, or with `--keep-snapshot`, it goes through a snapshot (save, create, delete unless `--keep-snapshot`). A suspended box is copied neither way: resume it first. The source box is not changed. The copies keep the source's idle pause, max-run, metadata and delete time (the same moment) unless you pass `--auto-suspend`, `--max-run-minutes`, `--meta` (added to the source's) or `--delete-after`.

```sh
instabox fork work --name work2
instabox fork work --name try --count 3 --json         # try-1, try-2, try-3
```

The same by hand, when you want the snapshot's name or the copy's create flags (`--secrets`, `--no-vault`, `--auto-suspend`):

```sh
instabox snapshot save work --name work-copy
instabox create --name work2 --snapshot work-copy
instabox snapshot rm --yes work-copy                    # optional; work2 is not affected
```

The copy gets a new sandbox identity and the Secret selection in its creation request. Without `--secrets` it keeps the existing Vault behavior and does not enroll in org Secrets; it does not inherit the source's selection. To give it neither store's credentials, use:

```sh
instabox create --name work2 --snapshot work-copy --no-vault --secrets none
```

To give the copy API credentials, name them with `--secrets NAME,NAME`. Placeholders copied from the source box do not work for the new one. New selections do not erase credentials that apps or people already wrote into files on the copied disks; review those before sharing the snapshot or the box.

## A box from a Docker/OCI image

```sh
instabox snapshot import python:3.12 --name py312       # a few minutes: pulls, lays the image over a box, reboots it to check, saves
instabox create --name dev --snapshot py312
instabox exec dev -- python3 --version                  # the image's python
```

The box is a normal instabox box (systemd, sshd, sudo, the user, `/data`) with the image's files, `ENV` and users on top; the image's `ENTRYPOINT`/`CMD` runs as `instabox-image.service` (`--no-entrypoint` to skip; `journalctl -u instabox-image.service` for its output). Images must be `linux/amd64`. Private registries: `--registry-username U` with `INSTABOX_REGISTRY_PASSWORD` set or `--registry-password-stdin`. A locally built image must be pushed to a registry first (`ghcr.io`, or `ttl.sh` for a one-off). `--json` gives `{snapshot, image, digest, os, service, verified, ...}`; `--keep-builder` keeps the throwaway box for a look when something is off. Details and limits: `instabox help snapshot import`.

## Clean up

```sh
instabox snapshot rm --yes work-ready
```

Snapshots count toward the account's snapshot and storage limits (`instabox usage`). Delete ones you no longer need.

## Typical agent loop

1. `instabox create --name job --snapshot <base>` (it pauses by itself after 30 idle minutes)
2. Work with `instabox exec job -- ...`
3. When the setup is worth keeping: `instabox snapshot save job --name <base>-v2` (no need to stop it)
4. `instabox rm --yes job` when done.
