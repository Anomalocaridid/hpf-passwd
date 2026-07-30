#!/usr/bin/env bash

# Safety options
set -o errexit           # Stop executing script when a command fails
set -o errtrace          # Re-enables ERR trap disabled by errexit
set -o nounset           # Stop executing script when an unset variable is accessed
set -o pipefail          # Propagate non-zero exit codes to the end of a pipeline
shopt -s inherit_errexit # Allow subshells to inherit errexit setting, requires bash >=4.4

# @describe change user password on NixOS systems that use `hashedPasswordFile`
# @meta version 0.0.0

# @arg login=`get_user_from_envs`       User to change the password of [env: $SUDO_USER, $USER]
# @flag --dry-run                       Show what would be done without changing any files
# @flag -p --fix-permissions            Set permissions for hashed password file without changing the file contents
# @option -F --flake <FLAKE_URI>        Flake URI to pass to nixos-option(8)
# @option -I --include <PATH>           Add path to Nix expression search path to pass to nixos-option(8)
# @option -P --prefix <PREFIX_DIR>      Prefix to add to `hashedPasswordFile` path
# @option --extra-experimental-features Additional experimental features to pass to nixos-options(8)

stderr_message() {
	>&2 echo "$(basename "$0"): $1"
}

get_user_from_envs() {
	echo "${SUDO_USER:-${USER}}"
}

# Query NixOS config for a given option's value
get_nixos_option() {
	# Dereference name of array variable
	local -n args="$2"
	readonly args

	# Note that for single options, `--recursive` makes nixos-option output a single line
	# containing the option path and the value
	local value
	value="$(nixos-option "$1" --recursive "${args[@]}" |
		cut --field 3 --delimiter " ")"
	readonly value

	# Error if option is null
	if [[ "$value" == "null;" ]]; then
		stderr_message "error: \`$1\` is null"
		return 1
	fi

	# Remove quotation marks in case option is a string
	echo "$value" | tr --delete '";'
}

# Check what `users.mutableUsers` is set to and warn if set to true
check_mutable_users() {
	local mutable_users
	mutable_users="$(get_nixos_option "users.mutableUsers" "$1")"
	readonly mutable_users

	if [[ "$mutable_users" == "true" ]]; then
		stderr_message "warning: \`users.mutableUsers\` is true, changes to hashed password files may not change actual passwords."
	fi
}

# Get path of the hashed password file for a given user
get_password_file() {
	get_nixos_option "users.users.$1.hashedPasswordFile" "$2"
}

# Prompt for password twice and check it is valid
# Separate from `password_prompt()` for mainly testing purposes
password_prompt_once() {
	local password password_repeat

	# Prompt for password twice
	read -r -s -p "Enter new password: " password
	>&2 echo ""
	read -r -s -p "Retype new password: " password_repeat
	>&2 echo ""

	# Ensure the password entered was the same both times
	if [[ "$password" == "$password_repeat" ]]; then
		if [[ -z "$password" ]]; then
			>&2 echo "No password has been supplied."
		else
			echo "$password"
		fi
	else
		>&2 echo "Passwords do not match."
	fi
}

# Prompt for password until valid input is received and return entered password
password_prompt() {
	local password=""

	while [[ -z "$password" ]]; do
		password="$(password_prompt_once)"
	done

	echo "$password"
}

# Given a password, write its hash to hashed password file
update_password_file() {
	local hash
	hash="$(mkpasswd "$1")"
	readonly hash

	if [[ "$3" ]]; then
		# I assume this is fine since the hash isn't being set anyways
		echo "hash: $hash"
	else
		# Make sure parent directories exist
		mkdir --parents "$(dirname "$2")"
		echo "$hash" >"$2"
		stderr_message "Hashed password file updated successfully. Please reboot or rebuild config to apply."
	fi
}

# Ensure permissions and ownership of the hashed password file match those of /etc/shadow
set_permissions() {
	local -r REF_FILE="/etc/shadow"
	stderr_message "Setting permissions on hashed password file."

	if [[ "$2" ]]; then
		local ref_info
		IFS=" " read -r -a ref_info <<<"$(ls -l "$REF_FILE")"
		readonly ref_info
		cat <<-EOF
			permissions: ${ref_info[0]}
			user:        ${ref_info[2]}
			group:       ${ref_info[3]}
		EOF
	else
		# Run chown first because it will fail if there are insufficient permissions and end the script
		# This would help prevent the permissions from being partially applied
		chown --reference="/etc/shadow" --changes "$1"
		chmod --reference="/etc/shadow" --changes "$1"
	fi
}

# Do not run if sourced
# Helps with testing
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	# Parse arguments with argc (defined at top of script)
	eval "$(argc --argc-eval "$0" "$@")"

	readonly is_dry_run="${argc_dry_run:-}"

	if [[ "$is_dry_run" ]]; then
		stderr_message "Dry run mode. No changes will be made."
	fi

	readonly username="${argc_login?}"

	# Note that this array will be passed by reference using its name
	declare -a nixos_option_args=()

	if [[ ! -z "${argc_flake:-}" ]]; then
		nixos_option_args+=("-F" "$argc_flake")
	fi

	if [[ ! -z "${argc_include:-}" ]]; then
		nixos_option_args+=("-I" "$argc_include")
	fi

	if [[ ! -z "${argc_extra_experimental_features:-}" ]]; then
		nixos_option_args+=("--extra-experimental-features" "$argc_extra_experimental_features")
	fi

	readonly nixos_option_args

	password_file="${argc_prefix:-}$(get_password_file "$username" "nixos_option_args")"
	readonly password_file

	readonly just_set_permissions="${argc_fix_permissions:-}"

	if [[ ! "$just_set_permissions" ]]; then
		check_mutable_users "nixos_option_args"
		stderr_message "Changing hashed password file for $username at $password_file."
		update_password_file "$(password_prompt)" "$password_file" "$is_dry_run"
	fi

	set_permissions "$password_file" "$is_dry_run"
fi
