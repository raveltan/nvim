#!/usr/bin/env bash
# Wrapper for fl-gaf neotest integration.
#
# bin/run-tests cannot be used directly because it word-splits flags internally
# (read -r -a flag_args <<< "$1"), breaking any flag value that contains spaces
# (e.g. --filter='::testName( with data set .*)?$').
#
# Instead, this wrapper:
# 1. Ensures Docker infrastructure is running (via bin/run-tests setup)
# 2. Runs bin/gaf-php vendor/bin/phpunit directly (preserving all arg quoting)
# 3. Redirects --log-junit to a project-local path (Docker only mounts project dir)
# 4. Tears down infrastructure after the test run

set -eo pipefail

find_project_root() {
    local dir="$1"
    while [[ "$dir" != "/" ]]; do
        if [[ -x "$dir/bin/run-tests" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Parse args: separate test path, intercept --log-junit, pass rest through
TEST_PATH=""
PHPUNIT_ARGS=()
ORIGINAL_JUNIT=""

for arg in "$@"; do
    if [[ "$arg" == --log-junit=* ]]; then
        ORIGINAL_JUNIT="${arg#--log-junit=}"
    elif [[ -z "$TEST_PATH" && "$arg" != --* ]]; then
        TEST_PATH="$arg"
    else
        PHPUNIT_ARGS+=("$arg")
    fi
done

if [[ -z "$TEST_PATH" ]]; then
    echo "Error: No test path provided"
    exit 1
fi

PROJECT_ROOT=$(find_project_root "$TEST_PATH")
if [[ -z "$PROJECT_ROOT" ]]; then
    echo "Error: Could not find project root (no bin/run-tests found)"
    exit 1
fi

cd "$PROJECT_ROOT"

# Redirect --log-junit to a project-local temp file (inside the Docker mount)
if [[ -n "$ORIGINAL_JUNIT" ]]; then
    LOCAL_JUNIT="${PROJECT_ROOT}/.cache/neotest-junit-$$.xml"
    PHPUNIT_ARGS+=("--log-junit=${LOCAL_JUNIT}")
fi

# Start infrastructure (MySQL, RabbitMQ, Redis)
bin/run-tests setup

# Detect test type for environment setup
OS="$(uname)"
if [[ "$OS" == "Darwin" ]]; then
    GAF_INTEGRATION_MYSQL_HOST="127.0.0.1"
    GAF_INTEGRATION_RABBIT_HOST="127.0.0.1"
    GAF_INTEGRATION_REDIS_HOST="127.0.0.1"
else
    GAF_INTEGRATION_MYSQL_HOST="gaf_integration_mysql"
    GAF_INTEGRATION_RABBIT_HOST="gaf_integration_rabbitmq"
    GAF_INTEGRATION_REDIS_HOST="gaf_integration_redis"
fi

# Run phpunit directly via bin/gaf-php (preserves quoting of all args)
EXIT_CODE=0
CONTAINER_NAME="fl-gaf-phpunit" \
EXTRA_ARGS="--network gaf_integration_network" \
GAF_INTEGRATION_MYSQL_HOST="$GAF_INTEGRATION_MYSQL_HOST" \
GAF_INTEGRATION_RABBIT_HOST="$GAF_INTEGRATION_RABBIT_HOST" \
GAF_INTEGRATION_REDIS_HOST="$GAF_INTEGRATION_REDIS_HOST" \
GAF_TEST_DOUBLES_ENABLED="true" \
bin/gaf-php vendor/bin/phpunit "$TEST_PATH" "${PHPUNIT_ARGS[@]}" || EXIT_CODE=$?

# Tear down infrastructure
bin/run-tests shutdown

# Copy JUnit XML back to where neotest expects it
if [[ -n "$ORIGINAL_JUNIT" && -f "$LOCAL_JUNIT" ]]; then
    mkdir -p "$(dirname "$ORIGINAL_JUNIT")"
    cp "$LOCAL_JUNIT" "$ORIGINAL_JUNIT"
    rm -f "$LOCAL_JUNIT"
fi

exit $EXIT_CODE
