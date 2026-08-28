#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../plex-unrecent
source "$SCRIPT_DIRECTORY/../plex-unrecent"

failures=0

assert_equal() {
    local expected="$1" actual="$2" description="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok - %s\n' "$description"
    else
        printf 'not ok - %s (expected %q, got %q)\n' "$description" "$expected" "$actual" >&2
        failures=$((failures + 1))
    fi
}

assert_file_missing() {
    local path="$1" description="$2"
    if [[ ! -e "$path" ]]; then
        printf 'ok - %s\n' "$description"
    else
        printf 'not ok - %s (%s exists)\n' "$description" "$path" >&2
        failures=$((failures + 1))
    fi
}

test_normalization_and_distance() {
    assert_equal 'godfather' "$(normalize_title 'The Godfather!')" 'normalization drops leading article and punctuation'
    assert_equal 'allladiesdoit' "$(normalize_title 'All Ladies Do It')" 'normalization drops whitespace'
    assert_equal '1' "$(levenshtein_distance 'godfathr' 'godfather')" 'Levenshtein distance detects one typo'
}

test_fuzzy_ranking() {
    CANDIDATE_IDS=(1 2 3)
    CANDIDATE_TITLES=('The Godfather' 'The Godfather Part II' 'Goodfellas')
    CANDIDATE_YEARS=(1972 1974 1990)
    CANDIDATE_TYPES=(1 1 1)
    CANDIDATE_LIBRARIES=('Movies' 'Movies' 'Movies')
    rank_matches 'the godfathr'
    assert_equal '0' "$(match_index "${RANKED_MATCHES[0]}")" 'fuzzy ranking chooses the closest typo match'
    assert_equal '11' "$(match_score "${RANKED_MATCHES[0]}")" 'fuzzy ranking reports normalized typo score'
}

test_duplicate_queue_prevention() {
    QUEUE_IDS=()
    QUEUE_TITLES=()
    QUEUE_YEARS=()
    QUEUE_TYPES=()
    QUEUE_LIBRARIES=()
    CANDIDATE_IDS=(42)
    CANDIDATE_TITLES=('Scrubs')
    CANDIDATE_YEARS=(2001)
    CANDIDATE_TYPES=(2)
    CANDIDATE_LIBRARIES=('TV')
    queue_add 0 >/dev/null
    queue_add 0 >/dev/null 2>&1 || true
    assert_equal '1' "${#QUEUE_IDS[@]}" 'queue does not accept an item twice'
}

test_series_descendant_expansion() {
    QUEUE_IDS=(100)
    QUEUE_TITLES=('Example Show')
    QUEUE_YEARS=(2020)
    QUEUE_TYPES=(2)
    QUEUE_LIBRARIES=('TV')
    readonly_query() {
        printf '100%s2\n101%s3\n102%s3\n201%s4\n202%s4\n203%s4\n' \
            "$FIELD_SEPARATOR" "$FIELD_SEPARATOR" "$FIELD_SEPARATOR" "$FIELD_SEPARATOR" "$FIELD_SEPARATOR" "$FIELD_SEPARATOR"
    }
    expand_queue
    assert_equal '6' "${#EXPANDED_IDS[@]}" 'series expansion includes show, seasons, and episodes'
    assert_equal '2' "${SERIES_SEASON_COUNTS[100]}" 'series expansion counts seasons'
    assert_equal '3' "${SERIES_EPISODE_COUNTS[100]}" 'series expansion counts episodes'
}

test_backup_retention() {
    local test_directory
    test_directory="$(mktemp -d)"
    DB_DIRECTORY="$test_directory"
    DB_FILENAME='test.db'
    BACKUP_RETENTION=2
    touch "$test_directory/test.db.before-unrecent-20260101-000000"
    touch "$test_directory/test.db.before-unrecent-20260101-000000-wal"
    touch "$test_directory/test.db.before-unrecent-20260102-000000"
    touch "$test_directory/test.db.before-unrecent-20260103-000000"
    prune_backups
    assert_file_missing "$test_directory/test.db.before-unrecent-20260101-000000" 'retention removes oldest primary backup'
    assert_file_missing "$test_directory/test.db.before-unrecent-20260101-000000-wal" 'retention removes matching WAL companion'
    assert_equal '2' "$(find "$test_directory" -maxdepth 1 -type f ! -name '*-wal' | wc -l | tr -d ' ')" 'retention keeps requested primary backup count'
    rm -rf -- "$test_directory"
}

test_normalization_and_distance
test_fuzzy_ranking
test_duplicate_queue_prevention
test_series_descendant_expansion
test_backup_retention

if ((failures > 0)); then
    exit 1
fi
printf 'All offline tests passed.\n'
