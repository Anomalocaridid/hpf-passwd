#!/usr/bin/env bash

# These test are meant to verify the behavior of nixos-option
# This is necessary to verify the tests that rely on mocking it since nixos-option can't be run in a nix sandbox since it runs nix
# Note that because of this, these tests must be skipped inside the nix sandbox

# Also note that these tests are the only ones that actually rely on the example configuration in tests/examples/configuration.nix
# However, other tests rely on the snapshots they check against

function set_up() {
	NIXOS_CONFIG="$(pwd)/tests/examples/configuration.nix"
}

# @tag runs_nix
# @data_provider nixos-option_snapshots
function test_nixos-option_output_hashedPasswordFile() {
	assert_match_snapshot "$(NIXOS_CONFIG="$NIXOS_CONFIG" command nixos-option --recursive "users.users.hpf-test-user.hashedPasswordFile")"
}

# @tag runs_nix
# @data_provider nixos-option_snapshots
function test_nixos-option_output_mutableUsers() {
	assert_match_snapshot "$(NIXOS_CONFIG="$NIXOS_CONFIG" command nixos-option --recursive "users.mutableUsers")"
}
