# plex-unrecent

`plex-unrecent` removes selected movies and TV series from Plex's **Recently Added** lists by backdating their `metadata_items.added_at` values to 1 January 2000.

It is intended for an Unraid host running the LinuxServer.io Plex container. It reads candidate titles while Plex is running, but stops Plex before it creates a backup or changes the database.

## Important safety warning

This utility directly changes Plex's internal SQLite database. That database is not a public Plex API, so use this only if you understand and accept the risk. Keep ordinary Plex backups too.

Before every successful write, `plex-unrecent` stops Plex, creates one timestamped database backup, updates only the selected metadata IDs in a single SQLite transaction, starts Plex once, and waits for Plex's identity endpoint to return HTTP 200. It deliberately does **not** run `wal_checkpoint`, `VACUUM`, `REINDEX`, schema changes, or any other database maintenance.

Never run a second database tool against Plex's database while Plex is running.

## Requirements

- Unraid with Docker access from the host
- A running Plex container named `plex` (or set `PLEX_UNRECENT_CONTAINER`)
- LinuxServer.io Plex image containing Plex SQLite at `/usr/lib/plexmediaserver/Plex SQLite`
- `curl`; `timeout` is optional but recommended for bounded read queries
- The Plex `/config` bind mount must expose the normal database path:

  `/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db`

The script determines the host-side `/config` source with `docker inspect`; it never assumes a hard-coded appdata path and never recursively searches `/config` or `/`.

## Install on Unraid

On the Unraid host, copy the executable to persistent flash storage:

```bash
mkdir -p /boot/config/custom/bin
cp plex-unrecent /boot/config/custom/bin/plex-unrecent
chmod 755 /boot/config/custom/bin/plex-unrecent
```

`/usr/local/bin` is in Unraid's RAM filesystem, so add this pattern to `/boot/config/go` to restore persistent custom scripts at boot:

```bash
# Restore persistent custom command-line scripts
for f in /boot/config/custom/bin/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    cp "$f" "/usr/local/bin/$name"
    chmod 755 "/usr/local/bin/$name"
done
```

Run the script from the host as a user allowed to control Docker and read the discovered `/config` source.

## Usage

### One title

```bash
plex-unrecent "All Ladies Do It"
plex-unrecent godfather
plex-unrecent "the godfathr"
```

The script reads all movie and series candidates read-only, normalizes titles case-insensitively (ignoring punctuation, whitespace, and a leading `The`, `A`, or `An`), then uses normalized Levenshtein distance for modest typos. It displays several close matches with year, content type, and library.

For safety, single-title mode refuses low-confidence or near-tied matches rather than guessing. If it finds one high-confidence match, it shows the final impact and asks for confirmation.

### Interactive batch mode

Run without a title:

```bash
plex-unrecent
```

Enter titles to build a queue. For each title, choose an explicitly numbered candidate. Commands are:

```text
list          Show queue
remove N      Remove item N from queue
done          Read/expand the selected records and show final summary
quit          Exit without changes
```

The queue is de-duplicated by Plex metadata ID, so the same movie or series cannot be added twice. Nothing is stopped or modified until the final `Proceed? [y/N]` is answered `y`.

## What is updated

- A selected **movie** updates only that movie's `metadata_items` row.
- A selected **series** updates the show row, its direct season rows, and episodes whose parent is one of those selected seasons.

The hierarchy is explicitly constrained to Plex metadata types: movie `1`, series `2`, season `3`, and episode `4`. The final summary gives the selected series' season/episode counts and the exact total number of records that will be updated.

The write is a single `BEGIN IMMEDIATE` transaction updating only prevalidated numeric metadata IDs. The script verifies SQLite's changed-row count before reporting success.

## Backups and retention

Once Plex is stopped, the script makes one backup alongside the live database:

```text
com.plexapp.plugins.library.db.before-unrecent-YYYYMMDD-HHMMSS
```

If the live `-wal` or `-shm` companion files exist then, matching companions are copied too. By default, the five most recent backups created by this utility are retained:

```bash
PLEX_UNRECENT_BACKUPS=10 plex-unrecent "The Godfather"
```

The override must be a positive integer. Pruning runs only after all of these succeed: the update, one Plex restart, and an HTTP 200 from `http://127.0.0.1:32400/identity`. The script only removes its own `.before-unrecent-...` primary files and matching `-wal`/`-shm` companions; Plex's own backups are never touched.

If an update or restart fails, the backup is retained. The script does not automatically restore a backup or overwrite the live database.

## Plex restart and client caching

If Plex was stopped by this script and an error or interruption occurs, its exit trap makes one best-effort attempt to start Plex. If Plex starts but the identity endpoint does not return HTTP 200 within about 60 seconds, the script reports the backup path and useful `docker logs`/`curl` diagnostics; it does not keep restarting Plex.

During startup, a temporary HTTP 503 with a database-migration message can be normal. The script waits for HTTP 200 before considering the operation successful.

If the item still appears in Plex Desktop's Recently Added row, fully quit the Plex app and reopen it; the client may cache the hub. That client-side cache does not by itself mean the database update failed.

## Troubleshooting

```bash
# Confirm the configured container is running
docker ps --filter name=plex

# Read Plex startup output after a reported identity timeout
docker logs --tail 200 plex

# Check the local Plex identity endpoint
curl -i http://127.0.0.1:32400/identity

# Inspect the actual /config source used by the container
docker inspect --format '{{range .Mounts}}{{if eq .Destination "/config"}}{{.Source}}{{end}}{{end}}' plex
```

If a title is rejected as ambiguous, use interactive batch mode to choose the exact year/type. If a read query times out, confirm Plex is healthy and retry later; no write was attempted.

## Manual restore (emergency only)

Only restore a backup if you have decided that it is necessary and understand that it replaces Plex's current database state.

1. **Stop Plex first.** Never copy a database over the live DB while Plex is running.
2. Identify the appropriate `.before-unrecent-...` backup beside the live database.
3. Preserve a copy of the current database before replacing anything.
4. Copy the chosen backup to the live database path. If restoring matching `-wal` and `-shm` companions, restore a consistent set from the same timestamp.
5. Ensure the restored files have the ownership/permissions Plex expects, then start Plex once and inspect its logs.

Do not use an automatic restore loop. If there is any uncertainty, make additional copies and seek Plex/Unraid support before modifying the database.

## Development checks

The offline harness uses mocked database reads and a temporary directory; it never contacts Docker, Plex, or a real database:

```bash
bash -n plex-unrecent
bash tests/test_plex_unrecent.sh
shellcheck plex-unrecent   # when installed
```
