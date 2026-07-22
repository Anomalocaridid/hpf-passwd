#!/usr/bin/env bash

# Safety options
set -o errexit           # Stop executing script when a command fails
set -o errtrace          # Re-enables ERR trap disabled by errexit
set -o nounset           # Stop executing script when an unset variable is accessed
set -o pipefail          # Propagate non-zero exit codes to the end of a pipeline
shopt -s inherit_errexit # Allow subshells to inherit errexit setting, requires bash >=4.4

# Defined to test detection of $USER
export USER="hpf-test-user"

# Any tests that rely on nixos-option, but do not mock it, will not work in nix sandbox
# This is because nix does not support running nix in a derivation
function skip_if_in_nix_sandbox() {
	cat <<-EOF
		if [[ ! -z \$NIX_ENFORCE_PURITY ]]; then
			bashunit::skip "Test does not work in nix sandbox" && return
		fi
	EOF
}
export -f skip_if_in_nix_sandbox

# Mock commands to ensure reproducibility in tests

# Make the password hash deterministic by fixing the salt
# NOTE: VERY INSECURE, IMPLEMENTED FOR TESTING PURPOSES ONLY
bashunit::mock mkpasswd command mkpasswd --method=sha512crypt --salt=testSalt

# Hash for password "test" generated with above mocked mkpasswd
# Use single quotes to reproduce output verbatim
# shellcheck disable=SC2016
export TEST_HASH='$6$testSalt$u4ALIX7a/ff0wBCiwNgqZKj3x9dJTxMjRDf0zeaPIfOSzn1gK3RYluhUl5cyWIihdVHs7QyfZ18hU1jJpLapZ.'

# The only thing ls is used for is getting the permissions and ownership of /etc/shadow in a dry run
bashunit::mock "ls" <<<"-rw-r----- 1 root shadow 1106 Dec 31 00:00 /etc/shadow"

# chown requires root permissions, so just dummy it out
bashunit::mock "chown" true

# Hardcode expected permissions rather than referencing /etc/shadow
function mock_chmod() {
	local args=("u=rw,g=r,o=")

	for arg in "$@"; do
		if [[ ! "$arg" =~ \-\-reference=.* ]]; then
			args+=("$arg")
		fi
	done

	command chmod "${args[@]}"
}
export -f mock_chmod

bashunit::mock "chmod" mock_chmod

# Helpers to mock nixos-option to minimize the tests that have to be skipped in a nix sandbox
# It is probably not a good idea to make these rely on snapshot files, but at least it's DRY

# NOTE: Quotes are significant for this one because there needs to be a way to differentiate `null` and `"null"`
function mock_nixos-option_hashedPasswordFile() {
	if [[ "$2" =~ users\.users\..*\.hashedPasswordFile ]]; then
		# cat "$(pwd)/tests/unit/snapshots/nixos_option_unmocked_test_sh.test_nixos_option_output_hashedPasswordFile.snapshot"
		cat "$(pwd)/tests/unit/snapshots/nixos_option_unmocked_test_sh.test_nixos_option_output_hashedPasswordFile.snapshot" |
			sed "s#\"/persist/passwords/hpf-test-user\"#$1#"
	else
		>&2 echo "error: unexpected option"
		return 1
	fi
}
export -f mock_nixos-option_hashedPasswordFile

function mock_nixos-option_mutableUsers() {
	if [[ "$2" == "users.mutableUsers" ]]; then
		cat "$(pwd)/tests/unit/snapshots/nixos_option_unmocked_test_sh.test_nixos_option_output_mutableUsers.snapshot" |
			sed "s# false# $1#"
	else
		>&2 echo "error: unexpected option"
		return 1
	fi
}
export -f mock_nixos-option_mutableUsers

# NOTE: this function takes one argument for each mocked option
function mock_nixos-option_integration() {
	if [[ "$3" =~ users\.users\..*\.hashedPasswordFile ]]; then
		mock_nixos-option_hashedPasswordFile "$1" "$3"
	elif [[ "$3" == "users.mutableUsers" ]]; then
		mock_nixos-option_mutableUsers "$2" "$3"
	else
		>&2 echo "error: given option \`$2\` not mocked"
		return 1
	fi
}
export -f mock_nixos-option_integration
