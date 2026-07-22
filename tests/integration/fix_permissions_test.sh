#!/usr/bin/env bash

function fix_permissions_flag_provider() {
	bashunit::data_set "long_flag" "--fix-permissions"
	bashunit::data_set "short_flag" "-P"
}

# @data_provider fix_permissions_flag_provider
function test_dry_run_::1::() {
	bashunit::mock nixos-option mock_nixos-option_integration "/dev/full" "UNREACHABLE"

	local expected_output
	expected_output="$(
		cat <<-EOF
			permissions: -rw-r-----
			user:        root
			group:       shadow
		EOF
	)"
	readonly expected_output

	assert_exec "bash src/hpf-passwd.sh $2 --dry-run" \
		--stdout-contains "$expected_output" \
		--stderr-not-contains "hpf-passwd.sh: Changing hashed password file"
}

# @data_provider fix_permissions_flag_provider
function test_dry_run_no_effects_::1::() {
	local password_file
	password_file="$(bashunit::temp_dir)/contains_hash"
	readonly password_file

	bashunit::mock nixos-option mock_nixos-option_integration "$password_file" "UNREACHABLE"

	echo "$TEST_HASH" >"$password_file"
	command chmod 777 "$password_file"

	bash src/hpf-passwd.sh "$2" --dry-run

	# TODO: After bashunit in nixpkgs is updated to 0.41.0, rewrite using `assert_file_permission`
	local file_perms
	file_perms="$(command ls -l "$password_file" | cut -f1 -d" ")"
	readonly file_perms

	assert_same "-rwxrwxrwx" "$file_perms"
}

# @data_provider fix_permissions_flag_provider
function test_wet_run_::1::() {
	local password_file
	password_file="$(bashunit::temp_dir)/contains_hash"
	readonly password_file

	bashunit::mock nixos-option mock_nixos-option_integration "$password_file" "UNREACHABLE"

	echo "$TEST_HASH" >"$password_file"
	command chmod 777 "$password_file"

	bash src/hpf-passwd.sh "$2"

	# TODO: After bashunit in nixpkgs is updated to 0.41.0, rewrite using `assert_file_permission`
	local file_perms
	file_perms="$(command ls -l "$password_file" | cut -f1 -d" ")"
	readonly file_perms

	assert_same "-rw-r-----" "$file_perms"
}
