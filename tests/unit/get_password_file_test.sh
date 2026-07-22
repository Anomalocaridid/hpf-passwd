#!/usr/bin/env bash

function set_up() {
	source "src/hpf-passwd.sh"
}

# NOTE: mock_nixos_option_hashedPasswordFile requires careful quoting
# because there needs to be a way to differentiate `null` and `"null"`
function valid_get_password_file_provider() {
	bashunit::data_set "normal" '"/persist/passwords/hpf-test-user"' "hpf-test-user"
	bashunit::data_set "null_string" '"null"' "hpf-test-user"
}

# @data_provider valid_get_password_file_provider
function test_valid_::1::_hashedPasswordFile_success() {
	bashunit::mock nixos-option mock_nixos-option_hashedPasswordFile "$(printf "%q" "$2")"
	assert_exec "get_password_file $3" \
		--stdout "$(echo "$2" | tr --delete '"')" \
		--stderr ""
}

function test_invalid_null_hashedPasswordFile_failure() {
	bashunit::mock nixos-option mock_nixos-option_hashedPasswordFile "null"
	assert_exec "get_password_file hpf-test-user" \
		--exit 1 \
		--stdout "" \
		--stderr-contains "error: \`users.users.hpf-test-user.hashedPasswordFile\` is null"
}
