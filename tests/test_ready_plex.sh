#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../ready-plex
source "$SCRIPT_DIRECTORY/../ready-plex"

failures=0
temporary_directory="$(mktemp -d)"
trap 'rm -rf -- "$temporary_directory"' EXIT

assert_status() {
    local expected="$1" actual="$2" description="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok - %s\n' "$description"
    else
        printf 'not ok - %s (expected %s, got %s)\n' "$description" "$expected" "$actual" >&2
        failures=$((failures + 1))
    fi
}

response_file="$temporary_directory/response.xml"

printf '%s\n' '<MediaContainer size="0" machineIdentifier="example" version="1.43.3" />' > "$response_file"
if response_is_ready 200 "$response_file"; then status=0; else status=1; fi
assert_status 0 "$status" 'healthy identity response is ready'

printf '%s\n' '<Response code="503" title="Maintenance" status="Plex Media Server is currently running database migrations."/>' > "$response_file"
if response_is_ready 503 "$response_file"; then status=0; else status=1; fi
assert_status 1 "$status" 'migration response is not ready'

printf '%s\n' '<Response code="500" title="Error" status="Database error"/>' > "$response_file"
if response_is_ready 500 "$response_file"; then status=0; else status=1; fi
assert_status 1 "$status" 'error response is not ready'

printf '%s\n' '<MediaContainer size="0" />' > "$response_file"
if response_is_ready 503 "$response_file"; then status=0; else status=1; fi
assert_status 1 "$status" 'non-200 response is not ready'

if ((failures > 0)); then
    exit 1
fi
printf 'All ready-plex tests passed.\n'
