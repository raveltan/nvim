#!/usr/bin/env bash
# Wrapper for fl-gaf neotest integration.
#
# Delegates to bin/run-tests so that Docker infrastructure namespacing
# (GAF_TEST_WORKER_ID), setup, and teardown are handled by the upstream
# tool — we don't reimplement any of it here.
#
# Two transformations:
# 1. --filter values are re-encoded so spaces become \s. bin/run-tests
#    word-splits flags via `read -r -a flag_args <<< "$1"`, which would
#    otherwise shred the value (neotest-phpunit emits filters like
#    "::testName( with data set .*)?$"). PHPUnit's --filter is PCRE so
#    \s matches the same characters.
# 2. --log-junit is redirected to a project-local temp file (Docker only
#    mounts the project dir), then copied to the path neotest expects.
#
# Always runs with SETUP=false. Infrastructure must be brought up explicitly
# via <leader>Tx (which calls `bin/run-tests setup`). bin/run-tests recovers
# the worker ID from .cache/gaf_session_* and reuses the namespaced silo.
# If no session exists, bin/run-tests bails with "Services are not running".

set -eo pipefail

find_project_root() {
    local dir="$1"
    while [[ "$dir" != "/" && -n "$dir" ]]; do
        if [[ -x "$dir/bin/run-tests" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

TEST_PATH=""
PASSTHROUGH=()
ORIGINAL_JUNIT=""
NEXT_IS_FILTER=0

for arg in "$@"; do
    if [[ $NEXT_IS_FILTER -eq 1 ]]; then
        # Re-encode spaces in filter regex so bin/run-tests' word-split keeps it intact.
        PASSTHROUGH+=("${arg// /\\s}")
        NEXT_IS_FILTER=0
    elif [[ "$arg" == --filter=* ]]; then
        value="${arg#--filter=}"
        PASSTHROUGH+=("--filter=${value// /\\s}")
    elif [[ "$arg" == "--filter" ]]; then
        PASSTHROUGH+=("$arg")
        NEXT_IS_FILTER=1
    elif [[ "$arg" == --log-junit=* ]]; then
        ORIGINAL_JUNIT="${arg#--log-junit=}"
    elif [[ -z "$TEST_PATH" && "$arg" != --* ]]; then
        TEST_PATH="$arg"
    else
        PASSTHROUGH+=("$arg")
    fi
done

if [[ -z "$TEST_PATH" ]]; then
    echo "Error: No test path provided" >&2
    exit 1
fi

# Canonicalize TEST_PATH (resolve symlinks + relative segments) so prefix
# stripping works whether neotest gave us an absolute or relative path,
# and whether the project root was reached via a symlink (e.g. worktree).
if [[ ! -e "$TEST_PATH" ]]; then
    echo "Error: Test path does not exist: $TEST_PATH" >&2
    exit 1
fi
TEST_PATH=$(realpath "$TEST_PATH")

PROJECT_ROOT=$(find_project_root "$TEST_PATH")
if [[ -z "$PROJECT_ROOT" ]]; then
    PROJECT_ROOT=$(find_project_root "$(pwd)")
fi
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "Error: Could not find project root (no bin/run-tests found)" >&2
    exit 1
fi
PROJECT_ROOT=$(realpath "$PROJECT_ROOT")

cd "$PROJECT_ROOT"

# bin/run-tests requires a relative path matching ^test/{functional,unit}, etc.
# Strip project root prefix.
if [[ "$TEST_PATH" != "$PROJECT_ROOT/"* ]]; then
    echo "Error: Test path '$TEST_PATH' is outside project root '$PROJECT_ROOT'" >&2
    exit 1
fi
TEST_PATH="${TEST_PATH#$PROJECT_ROOT/}"

# Redirect --log-junit to a path inside the Docker bind-mount.
LOCAL_JUNIT=""
if [[ -n "$ORIGINAL_JUNIT" ]]; then
    mkdir -p "${PROJECT_ROOT}/.cache"
    LOCAL_JUNIT="${PROJECT_ROOT}/.cache/neotest-junit-$$.xml"
    PASSTHROUGH+=("--log-junit=${LOCAL_JUNIT}")
fi

EXIT_CODE=0
SETUP=false ./bin/run-tests "$TEST_PATH" "${PASSTHROUGH[@]}" || EXIT_CODE=$?

if [[ -n "$LOCAL_JUNIT" && -f "$LOCAL_JUNIT" && -n "$ORIGINAL_JUNIT" ]]; then
    mkdir -p "$(dirname "$ORIGINAL_JUNIT")"
    cp "$LOCAL_JUNIT" "$ORIGINAL_JUNIT"
    rm -f "$LOCAL_JUNIT"
fi

exit $EXIT_CODE
