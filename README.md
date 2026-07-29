# fstablint

Validate `/etc/fstab` for the hardening and reliability mistakes that `mount -a`
will not warn you about until it is too late.

fstablint is a single Python file with no dependencies. It reads files only and
exits non-zero on any HIGH or CRITICAL finding, so it fits a pre-commit hook or a
config-management check.

## What it catches

- **Unhardened sensitive mounts** — `/tmp`, `/var/tmp` and `/dev/shm` without
  `nodev,nosuid,noexec` (and `/home` without `nodev,nosuid`). These are standard
  CIS items: without them anyone can drop a setuid or executable file on a
  world-writable filesystem.
- **Network mounts that hang the boot** — an `nfs`/`cifs` entry without `nofail`
  will stall startup when the server is down; without `_netdev` it may be mounted
  before the network is up. Both are flagged.
- **Mounts by device name** — `/dev/sdb1` becomes `/dev/sdc1` the day you add a
  disk. fstablint tells you to use `UUID=` or `LABEL=`.
- **Duplicate mount points**, the **wrong field count**, and filesystems with an
  **fsck pass of 0** (never checked) or a non-`1` pass on `/`.

Entries that are already correct — a hardened `/dev/shm`, an NFS mount with
`_netdev,nofail` — are left quiet, so the output stays signal.

## Usage

```sh
fstablint /etc/fstab
```

Example:

```
$ fstablint /etc/fstab
  HIGH     line 3: /tmp is missing nodev,noexec,nosuid (CIS: sensitive mounts should carry these)
  HIGH     line 5: /mnt/nfs: network fs without nofail; a down server will hang the boot
  HIGH     line 6: mount point /data already defined on line 2
  LOW      line 2: /data: mounted by device name /dev/sdb1; use UUID= or LABEL=
```

## Caveat

This lints the file's contents; it does not inspect the running mounts or the
disks. A finding may be intentional on your system (a build box may want `exec`
on `/tmp`). Read each one, and pair it with `findmnt --verify`.

## Tests

```sh
./tests/run.sh
```

Builds throwaway fstab fixtures in a temp dir, asserts the findings — including
the guards that keep a correctly-hardened mount quiet — and cleans up.

## License

MIT. See `LICENSE`.
