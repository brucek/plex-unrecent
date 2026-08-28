# plex-unrecent delivery plan

- [x] Inspect the requested behavior and establish safety constraints.
- [x] Build read-only candidate discovery and deterministic fuzzy selection.
- [x] Build interactive queue handling and validated selected-ID expansion.
- [x] Build the stop/backup/transaction/restart lifecycle with recovery traps.
- [x] Add documentation, license, and offline tests.
- [x] Run syntax, lint (if available), and offline tests; review the diff.
- [x] Commit the verified implementation.

## Verification plan

- Unit-style Bash tests for normalization, fuzzy ranking, duplicate queue handling,
  selected series hierarchy expansion, and backup pruning.
- `bash -n plex-unrecent` and `shellcheck plex-unrecent` when available.
- No test connects to Docker or a real Plex database.

## Review

- All title and descendant reads use the Plex SQLite executable in read-only
  mode while Plex is running; user title text is never interpolated into SQL.
- The only write uses an exact, prevalidated list of numeric metadata IDs in a
  single transaction after a backup and stop.
- The stopped-container helper uses the container image and DB owner, avoiding
  a host SQLite dependency and root-owned database side files.
- Offline checks cover normalization, fuzzy selection, duplicate prevention,
  series descendants, and timestamped backup retention.

## Unraid deployment

- [x] Confirm SSH connectivity and inspect persistent/active script copies.
- [x] Install the committed executable to persistent flash and refresh the active copy.
- [x] Verify checksums, permissions, and shell syntax on the Unraid host.

Deployment verified on the Unraid host on 2026-08-27. Both deployed copies match
SHA-256 `2512f419fff3519eb0f62b9ebe4b24af223ea392a1afb058b959f8bc67bda759`.
The previous persistent copy is retained at
`/boot/config/custom/bin/plex-unrecent.before-update-20260827-221813`.

## Live performance fix

- [x] Inspect the hung interactive matcher on the Unraid host and confirm the bottleneck.
- [x] Replace the unbounded matcher with a bounded, deterministic approach.
- [x] Test the fix offline and on the Unraid host without changing Plex data.

Confirmed the full candidate list on the Unraid host. The live `bogus` interactive
read-only path completed and cancelled normally in 4 seconds (including the
candidate query), with exit status 0.

## Plex readiness checker

- [x] Rename the command to `ready-plex` for convenient tab completion.
- [ ] Add a standalone readiness checker with clear status and exit codes.
- [ ] Add offline response-classification tests and usage documentation.
- [ ] Test and install the checker on the Unraid host's persistent and active paths.
