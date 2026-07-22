#!/usr/bin/env bash

# NOTE: `users.mutableUsers` should not affect behavior beyond the warning message
function user_mutability_provider() {
	bashunit::data_set "immutable_users" "false" "--stderr-not-contains"
	bashunit::data_set "mutable_users" "true" "--stderr-contains"
}

function test_dry_run_output() {
	bashunit::mock nixos-option mock_nixos-option_integration "/dev/full" "false"

	assert_exec "yes 'test' | bash src/hpf-passwd.sh --dry-run" \
		--stdout-contains "hash: $TEST_HASH" \
		--stderr-contains "Dry run mode. No changes will be made."
}

# This is the only test in this file which expects a difference depending on `users.mutableUsers`
# All the others are to ensure no changes occur
# @data_provider user_mutability_provider
function test_dry_run_::1::() {
	bashunit::mock nixos-option mock_nixos-option_integration "/dev/full" "$2"

	assert_exec "yes 'test' | bash src/hpf-passwd.sh --dry-run" \
		"$3" "warning: \`users.mutableUsers\` is true, changes to hashed password files may not change actual passwords."
}

# NOTE: tests/bootstrap.sh defines $USER, which is used as the user whose hashed password file will be changed
# when one is not explicitly given
# @data_provider user_mutability_provider
function test_dry_run_user_env_detection_::1::() {
	bashunit::mock nixos-option mock_nixos-option_integration "/dev/full" "$2"

	assert_exec "yes 'test' | bash src/hpf-passwd.sh --dry-run" \
		--stderr-contains "Changing hashed password file for hpf-test-user at /dev/full."
}

# @data_provider user_mutability_provider
function test_dry_run_no_effects_::1::() {
	local password_file
	password_file="$(bashunit::temp_dir)/should_not_exist"
	readonly password_file

	bashunit::mock nixos-option mock_nixos-option_integration "$password_file" "$2"

	yes "test" | bash src/hpf-passwd.sh --dry-run

	assert_false test -f "$password_file"
}

# @data_provider user_mutability_provider
function test_wet_run_password_hash_::1::() {
	local password_file
	password_file="$(bashunit::temp_dir)/contains_hash"
	readonly password_file

	bashunit::mock nixos-option mock_nixos-option_integration "$password_file" "$2"

	yes "test" | bash src/hpf-passwd.sh

	assert_same "$TEST_HASH" "$(cat "$password_file")"
}

# @data_provider user_mutability_provider
function test_wet_run_file_permissions_::1::() {
	local password_file
	password_file="$(bashunit::temp_dir)/contains_hash"
	readonly password_file

	bashunit::mock nixos-option mock_nixos-option_integration "$password_file" "$2"

	yes "test" | bash src/hpf-passwd.sh

	# TODO: After bashunit in nixpkgs is updated to 0.41.0, rewrite using `assert_file_permission`
	local file_info
	IFS=" " read -r -a file_info <<<"$(command ls -l "$password_file")"
	readonly file_info

	assert_same "-rw-r-----" "${file_info[0]}"
}
