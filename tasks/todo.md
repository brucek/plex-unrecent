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
