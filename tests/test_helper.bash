#!/bin/bash
# =============================================================================
# test_helper.bash - BATS Test Helper for n8n Scripts
# =============================================================================
# Provides common setup, teardown, and mocking utilities for all tests
# =============================================================================

# Load BATS helper libraries
load '/usr/lib/bats/bats-support/load.bash'
load '/usr/lib/bats/bats-assert/load.bash'

# -----------------------------------------------------------------------------
# Directory Setup
# -----------------------------------------------------------------------------
# Get the directory containing the test files
TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

# Create a temporary directory for each test
setup_temp_dir() {
	export TEST_TEMP_DIR="$(mktemp -d)"
	export TEST_PROJECT_DIR="$TEST_TEMP_DIR/project"
	export TEST_SCRIPTS_DIR="$TEST_PROJECT_DIR/scripts"
	export TEST_BACKUP_DIR="$TEST_PROJECT_DIR/backups"
	export TEST_LOG_DIR="$TEST_PROJECT_DIR/logs"

	mkdir -p "$TEST_SCRIPTS_DIR"
	mkdir -p "$TEST_BACKUP_DIR"/{postgres,redis,n8n,env}
	mkdir -p "$TEST_LOG_DIR"

	# Create a mock .env file
	cat >"$TEST_PROJECT_DIR/.env" <<'EOF'
POSTGRES_USER=n8n
POSTGRES_DB=n8n
POSTGRES_PASSWORD=testpass
REDIS_PORT=6379
EOF
}

teardown_temp_dir() {
	if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
		rm -rf "$TEST_TEMP_DIR"
	fi
}

# -----------------------------------------------------------------------------
# Mock Functions
# -----------------------------------------------------------------------------

# Create a mock command that can be customized per test
create_mock() {
	local cmd_name="$1"
	local exit_code="${2:-0}"
	local output="${3:-}"

	local mock_dir="$TEST_TEMP_DIR/mocks"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/$cmd_name" <<EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
	chmod +x "$mock_dir/$cmd_name"

	# Prepend mock directory to PATH
	export PATH="$mock_dir:$PATH"
}

# Create a docker mock with configurable responses
setup_docker_mock() {
	local mock_dir="$TEST_TEMP_DIR/mocks"
	mkdir -p "$mock_dir"

	# Create docker mock script
	cat >"$mock_dir/docker" <<'DOCKER_MOCK'
#!/bin/bash
# Configurable docker mock

case "$1" in
ps)
	if [[ "$*" == *"--format"* ]]; then
		echo "n8n-postgres"
		echo "n8n-redis"
		echo "n8n-main"
	else
		echo "NAMES"
		echo "n8n-postgres"
		echo "n8n-redis"
		echo "n8n-main"
	fi
	;;
exec)
	container="$2"
	shift 2
	case "$1" in
	pg_dump)
		echo "-- PostgreSQL dump"
		echo "CREATE TABLE test (id int);"
		;;
	psql)
		echo "OK"
		;;
	redis-cli)
		case "$2" in
		LASTSAVE)
			echo "1703548800"
			;;
		BGSAVE)
			echo "Background saving started"
			;;
		PING)
			echo "PONG"
			;;
		INFO)
			echo "used_memory_human:10.5M"
			;;
		KEYS)
			echo "bull:jobs:wait"
			;;
		LLEN | ZCARD)
			echo "0"
			;;
		*)
			echo "OK"
			;;
		esac
		;;
	pg_isready)
		exit 0
		;;
	n8n)
		echo "1.70.0"
		;;
	postgres)
		echo "postgres (PostgreSQL) 16.1"
		;;
	redis-server)
		echo "Redis server v=7.2.3"
		;;
	*)
		echo "mock exec: $*"
		;;
	esac
	;;
inspect)
	if [[ "$*" == *"State.Status"* ]]; then
		echo "running"
	elif [[ "$*" == *"State.Health"* ]]; then
		echo "healthy"
	elif [[ "$*" == *"Config.Image"* ]]; then
		echo "n8nio/n8n:1.70.0"
	else
		echo "{}"
	fi
	;;
cp)
	# Simulate docker cp by creating a file
	dest="${!#}"
	if [[ -n "$dest" ]]; then
		echo "mock rdb data" >"$dest" 2>/dev/null || true
	fi
	;;
run)
	# Simulate docker run (for backup-n8n.sh tar command)
	echo "mock docker run"
	;;
stats)
	echo -e "n8n-main\t5.5%\t256MiB / 2GiB"
	echo -e "n8n-postgres\t2.1%\t128MiB / 2GiB"
	echo -e "n8n-redis\t0.5%\t32MiB / 2GiB"
	;;
volume)
	case "$2" in
	inspect)
		echo "{}"
		;;
	ls)
		echo "n8n_n8n_data"
		echo "n8n_postgres_data"
		;;
	esac
	;;
compose)
	case "$2" in
	ps)
		echo '{"Service":"n8n-worker","Name":"n8n-n8n-worker-1","State":"running"}'
		;;
	logs)
		echo "[2024-01-01 12:00:00] Mock log output"
		;;
	exec)
		echo "mock compose exec"
		;;
	version)
		echo "Docker Compose version v2.23.0"
		;;
	esac
	;;
system)
	echo "TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE"
	echo "Volumes         5         3         1.2GB     500MB"
	;;
info)
	echo "Docker info mock"
	;;
*)
	echo "docker mock: $*"
	;;
esac
exit 0
DOCKER_MOCK
	chmod +x "$mock_dir/docker"
	export PATH="$mock_dir:$PATH"
}

# Create curl mock for endpoint testing
setup_curl_mock() {
	local mock_dir="$TEST_TEMP_DIR/mocks"
	mkdir -p "$mock_dir"

	cat >"$mock_dir/curl" <<'CURL_MOCK'
#!/bin/bash
# Mock curl for health checks
if [[ "$*" == *"healthz"* ]]; then
	echo "200"
elif [[ "$*" == *"metrics"* ]]; then
	echo "200"
elif [[ "$*" == *"5678"* ]]; then
	echo "200"
else
	echo "200"
fi
exit 0
CURL_MOCK
	chmod +x "$mock_dir/curl"
	export PATH="$mock_dir:$PATH"
}

# -----------------------------------------------------------------------------
# Assertion Helpers
# -----------------------------------------------------------------------------

# Assert file exists and is not empty
assert_file_not_empty() {
	local file="$1"
	assert [ -f "$file" ]
	assert [ -s "$file" ]
}

# Assert log contains message
assert_log_contains() {
	local log_file="$1"
	local pattern="$2"
	run grep -q "$pattern" "$log_file"
	assert_success
}

# Assert exit code
assert_exit_code() {
	local expected="$1"
	assert_equal "$status" "$expected"
}

# -----------------------------------------------------------------------------
# Script Source Helper
# -----------------------------------------------------------------------------

# Source script functions without running main
source_script_functions() {
	local script="$1"
	local script_name="${script%.sh}"
	local script_path="$SCRIPTS_DIR/$script"

	# Ensure directories exist
	mkdir -p "$TEST_LOG_DIR"
	mkdir -p "$TEST_SCRIPTS_DIR"

	# Override paths for testing - must be set before sourcing
	export SCRIPT_DIR="$TEST_SCRIPTS_DIR"
	export PROJECT_DIR="$TEST_PROJECT_DIR"
	export BACKUP_DIR="$TEST_BACKUP_DIR"
	export BACKUP_BASE_DIR="$TEST_BACKUP_DIR"
	export LOG_FILE="$TEST_LOG_DIR/test.log"
	export COMPOSE_FILE="$TEST_PROJECT_DIR/docker-compose.yml"
	export RESULTS_DIR="$TEST_TEMP_DIR/benchmark"

	# Ensure log file can be created
	touch "$LOG_FILE" 2>/dev/null || true

	# Create a temporary copy that comments out main call and exit statements
	local temp_script="$TEST_TEMP_DIR/sourced_$(basename "$script")"

	# Transform the script:
	# - Comment out main "$@"
	# - Convert "exit 1" to "return 1" for functions
	# - Skip .env sourcing that exits on failure
	# - Override LOG_FILE to use test directory
	sed -e 's/^main "\$@"$/# main "$@"/' \
		-e 's/^[[:space:]]*exit 1$/return 1 2>\/dev\/null || :/' \
		-e 's/source "\${PROJECT_DIR}\/.env"/true # skip .env for testing/' \
		-e "s|LOG_FILE=\"\${PROJECT_DIR}/logs/[^\"]*\"|LOG_FILE=\"${TEST_LOG_DIR}/test.log\"|g" \
		"$script_path" >"$temp_script"

	# Source the modified script - errors are expected for some scripts
	set +e
	source "$temp_script" 2>/dev/null
	set -e

	# Ensure LOG_FILE is set to our test path after sourcing
	export LOG_FILE="$TEST_LOG_DIR/test.log"
}

# -----------------------------------------------------------------------------
# Common Setup/Teardown
# -----------------------------------------------------------------------------

# Standard setup for most tests
common_setup() {
	setup_temp_dir
	setup_docker_mock
	setup_curl_mock
}

# Standard teardown for most tests
common_teardown() {
	teardown_temp_dir
}
