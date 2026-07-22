#!/usr/bin/env bash

function set_up() {
	source "src/hpf-passwd.sh"
}

function test_mock_mkpasswd_quick_check_same_hash() {
	assert_same "$(mkpasswd "test")" "$(mkpasswd "test")"
}

function test_mock_mkpasswd_quick_check_different_hashes() {
	assert_not_same "$(mkpasswd "foo")" "$(mkpasswd "bar")"
}

function test_update_password_file_dry_run_output() {
	assert_exec "update_password_file test /dev/full 1" \
		--stdout "hash: $TEST_HASH"
}

function test_update_password_file_dry_run_no_changes() {
	local password_file
	password_file="$(bashunit::temp_dir)/should_not_exist"
	readonly password_file

	update_password_file "test" "$password_file" "1"

	assert_false "test -f $password_file"
}

function test_update_password_file_wet_run() {
	local password_file
	password_file="$(bashunit::temp_dir)/contains_hash"
	readonly password_file

	update_password_file "test" "$password_file" ""

	assert_same "$TEST_HASH" "$(cat "$password_file")"
}
