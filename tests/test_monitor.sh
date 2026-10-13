#!/usr/bin/env bash
# ==========================================================
#  Test Suite for CyberSec Linux Health & Threat Monitor
# ==========================================================

set -eo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT="$ROOT_DIR/health_monitor.sh"

PASSED=0
FAILED=0

run_test() {
  local name="$1"
  shift
  echo -n "Running test: $name ... "
  if "$@"; then
    echo -e "\e[32mPASS\e[0m"
    PASSED=$((PASSED + 1))
  else
    echo -e "\e[31mFAIL\e[0m"
    FAILED=$((FAILED + 1))
  fi
}

test_syntax() {
  bash -n "$ROOT_DIR/health_monitor.sh" && \
  bash -n "$ROOT_DIR/install.sh" && \
  bash -n "$ROOT_DIR/uninstall.sh"
}

test_version_flag() {
  local output
  output=$(bash "$SCRIPT" --version)
  [[ "$output" =~ "CyberSec Monitor v" ]]
}

test_help_flag() {
  local output
  output=$(bash "$SCRIPT" --help)
  [[ "$output" =~ "Usage:" ]] && [[ "$output" =~ "--scan" ]] && [[ "$output" =~ "--json" ]]
}

test_json_output() {
  local output
  output=$(bash "$SCRIPT" --no-install --json)
  # Verify required JSON fields are present
  [[ "$output" =~ '"cpu_percent":' ]] && \
  [[ "$output" =~ '"memory_percent":' ]] && \
  [[ "$output" =~ '"disk_percent":' ]] && \
  [[ "$output" =~ '"internet_status":' ]] && \
  [[ "$output" =~ '"listening_ports_count":' ]]
}

test_custom_config() {
  local tmp_cfg
  tmp_cfg=$(mktemp)
  cat <<EOF > "$tmp_cfg"
CPU_LIMIT=99
MEM_LIMIT=92
DISK_LIMIT=77
LOGIN_FAIL_LIMIT=12
EOF

  local output
  output=$(bash "$SCRIPT" --no-install --config "$tmp_cfg" --json)
  rm -f "$tmp_cfg"

  [[ "$output" =~ '"cpu_limit": 99' ]] && \
  [[ "$output" =~ '"memory_limit": 92' ]] && \
  [[ "$output" =~ '"disk_limit": 77' ]] && \
  [[ "$output" =~ '"login_fail_limit": 12' ]]
}

test_invalid_option() {
  if bash "$SCRIPT" --non-existent-flag &>/dev/null; then
    return 1
  else
    return 0
  fi
}

echo "=== CyberSec Monitor Automated Tests ==="
run_test "Bash Syntax Check" test_syntax
run_test "CLI --version Flag" test_version_flag
run_test "CLI --help Flag" test_help_flag
run_test "CLI --json Telemetry Output" test_json_output
run_test "CLI --config Custom Configuration" test_custom_config
run_test "CLI Invalid Flag Handling" test_invalid_option

echo "========================================="
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
