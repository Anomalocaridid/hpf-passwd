#!/usr/bin/env bash

function set_up() {
	source "src/hpf-passwd.sh"
}

function password_prompt_provider() {
	local -r empty_password_error="No password has been supplied."
	local -r mismatching_password_error="Passwords do not match."
	bashunit::data_set "valid_nonempty" "nonempty" "" "$empty_password_error" "$(
		cat <<-EOF
			nonempty
			nonempty
		EOF
	)"
	bashunit::data_set "valid_matching" "matching" "" "$mismatching_password_error" "$(
		cat <<-EOF
			matching
			matching
		EOF
	)"
	bashunit::data_set "invalid_empty" "" "$empty_password_error" "$mismatching_password_error" "$(
		cat <<-EOF


		EOF
	)"
	bashunit::data_set "invalid_mismatching" "" "$mismatching_password_error" "$empty_password_error" "$(
		cat <<-EOF
			pass
			words
		EOF
	)"
}

# @data_provider password_prompt_provider
function test_::1::_password() {
	assert_exec "password_prompt_once" \
		--stdout "$2" \
		--stderr-contains "$3" \
		--stderr-not-contains "$4" \
		--stdin "$5"
}
