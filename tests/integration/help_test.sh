#!/usr/bin/env bash

function help_flag_provider() {
	bashunit::data_set "long_flag" "--help"
	bashunit::data_set "short_flag" "-h"
}

# @data_provider help_flag_provider
function test_help_message_snapshot_::1::() {
	assert_match_snapshot "$(2>&1 bash src/hpf-passwd.sh "$2")"
}
