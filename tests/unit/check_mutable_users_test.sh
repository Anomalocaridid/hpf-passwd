#!/usr/bin/env bash

function set_up() {
	source "src/hpf-passwd.sh"
}

function mutable_user_values() {
	bashunit::data_set "mutable" "true" "--stderr-contains"
	bashunit::data_set "immutable" "false" "--stderr-not-contains"
}

# @data_provider mutable_user_values
function test_::1::_user() {
	bashunit::mock nixos-option mock_nixos-option_mutableUsers "$2"
	assert_exec check_mutable_users \
		"$3" "warning: \`users.mutableUsers\` is true, changes to hashed password files may not change actual passwords."
}
