#!/usr/bin/env bats

load ../node_modules/bats-support/load
load ../node_modules/bats-assert/load

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
    if [[ -n "$TEST_TMPDIR" && -d "$TEST_TMPDIR" ]]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

@test "retry succeeds after a transient failure" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash'; export RETRY_INTERVAL=0; counter_file='$TEST_TMPDIR/retry-counter'; flaky() { attempts=\$(cat \"\$counter_file\" 2>/dev/null || echo 0); attempts=\$((attempts + 1)); printf '%s\\n' \"\$attempts\" > \"\$counter_file\"; [ \"\$attempts\" -ge 2 ]; }; retry 3 flaky"

    assert_success
    assert_output --partial "Retrying (2/3): flaky"
}

@test "retry_with_backoff succeeds after a transient failure" {
    run bash -c "source '$BATS_TEST_DIRNAME/functions.bash'; counter_file='$TEST_TMPDIR/retry-backoff-counter'; flaky() { attempts=\$(cat \"\$counter_file\" 2>/dev/null || echo 0); attempts=\$((attempts + 1)); printf '%s\\n' \"\$attempts\" > \"\$counter_file\"; [ \"\$attempts\" -ge 2 ]; }; retry_with_backoff 3 0 flaky"

    assert_success
    assert_output --partial "Retrying (2/3) in 0s: flaky"
}
