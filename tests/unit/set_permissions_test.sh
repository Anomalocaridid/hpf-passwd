#!/usr/bin/env bash

function set_up() {
	source "src/hpf-passwd.sh"
}

function test_set_permissions_dry_run() {
	local expected_output
	expected_output="$(
		cat <<-EOF
			permissions: -rw-r-----
			user:        root
			group:       shadow
		EOF
	)"
	readonly expected_output

	assert_exec "set_permissions /persist/passwords/hpf-test-user 1" \
		--stdin "$expected_output"
}

function test_set_permissions_temp_file() {
	local test_file
	test_file="$(bashunit::temp_file)"
	readonly test_file

	set_permissions "$test_file" ""

	# TODO: After bashunit in nixpkgs is updated to 0.41.0, rewrite using `assert_file_permission`
	local file_perms
	file_perms="$(command ls -l "$test_file" | cut -f1 -d" ")"
	readonly file_perms

	assert_same "-rw-r-----" "$file_perms"
}
