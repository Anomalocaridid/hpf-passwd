#!/usr/bin/env bash

# Safety options
set -o errexit           # Stop executing script when a command fails
set -o errtrace          # Re-enables ERR trap disabled by errexit
set -o nounset           # Stop executing script when an unset variable is accessed
set -o pipefail          # Propagate non-zero exit codes to the end of a pipeline
shopt -s inherit_errexit # Allow subshells to inherit errexit setting, requires bash >=4.4

# @describe change user password on NixOS systems that use hashedPasswordFile
# @arg login $USER           User to change the password of (defaults to $USER)
# @flag -P --fix-permissions Set permissions for hashed password file without changing the file contents
# @flag --dry-run            Show what would be done without changing any files

stderr_message() {
	>&2 echo "$(basename "$0"): $1"
}

# Query NixOS config for a given option's value
get_nixos_option() {
	# Note that nixos-option has no option to output just the value
	# so it needs to be extracted manually
	# Also make sure to trim leading spaces
	local value
	value="$(nixos-option "$1" |
		sed --silent '/^Value:/{n;p;}' |
		sed 's/^[[:blank:]]*//g')"
	readonly value

	# Error if option is null
	if [[ "$value" == "null" ]]; then
		stderr_message "error: \`$1\` is null"
		return 1
	fi

	# Remove quotation marks in case option is a string
	echo "$value" | tr --delete '"'
}

# Check what `users.mutableUsers` is set to and warn if set to true
check_mutable_users() {
	local mutable_users
	mutable_users="$(get_nixos_option "users.mutableUsers")"
	readonly mutable_users

	if [[ "$mutable_users" == "true" ]]; then
		stderr_message "warning: \`users.mutableUsers\` is true, changes to hashed password files may not change actual passwords."
	fi
}

# Get path of the hashed password file for a given user
get_password_file() {
	get_nixos_option "users.users.$1.hashedPasswordFile"
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

	readonly is_dry_run="${argc_dry_run:=}"

	if [[ "$is_dry_run" ]]; then
		stderr_message "Dry run mode. No changes will be made."
	fi

	readonly username="${argc_login?}"

	password_file="$(get_password_file "$username")"
	readonly password_file

	readonly just_set_permissions="${argc_fix_permissions:=}"

	if [[ ! "$just_set_permissions" ]]; then
		check_mutable_users
		stderr_message "Changing hashed password file for $username at $password_file."
		update_password_file "$(password_prompt)" "$password_file" "$is_dry_run"
	fi

	set_permissions "$password_file" "$is_dry_run"
fi
