# hpf-passwd

A utility script for managing passwords on NixOS configurations that use `users.users.*.hashedPasswordFile` along with immutable user accounts.

## Features

- Conveniently changes passwords stored as hashes at `users.users.*.hashedPasswordFile`
- Automatically detects `users.users.*.hashedPasswordFile` from NixOS configurations (thanks to `nixos-option`)
- Supports both flakes and non-flake configurations
- Does not require any additional configuration

## Limitations

- `hpf-passwd` will never be a drop-in replacement for `passwd` or similar programs due to inherent limitations with using `hashedPasswordFile`. For instance, it will never be possible to set expiration dates for passwords.
- Unlike `passwd`, changes to passwords are only applied if `users.mutableUsers = false` and only when the NixOS configuration is re-activated. This is an inherent limitation to using `hashedPasswordFile`.
- Unlike `passwd`, `hpf-passwd` requires root permissions to change the current user's password.
- Currently, `hpf-passwd` only supports setting passwords, not deleting them, locking them, or showing any status information.
- Currently, only interactively setting a single user's password at a time is supported and there is no equivalent for `chpasswd`.

## Usage

```sh
# Change the current user's password
sudo hpf-passwd

# Change a different user's password
sudo hpf-passwd $user

# Ensure password file has appropriate permissions and ownership without changing password
sudo hpf-passwd --fix-permissions

# Specify config location and password file location prefix
# Useful for setting initial passwords as part of installation
sudo hpf-passwd --flake github:user/repo#hostname --prefix /mnt $user
sudo hpf-passwd --include nixos-config=/path/to/configuration.nix --prefix /mnt $user
```

See `hpf-passwd --help` or `man hpf-passwd` for further information.

## Installation

### With Flakes

Add the following to your `flake.nix`:

```nix
inputs.hpf-passwd.url = "github:Anomalocaridid/hpf-passwd";
```

Then, assuming you have `inputs` passed as an argument, add

```nix
{pkgs, inputs, ...}: {
  # For system-wide installation
  environment.systemPackages = [
    hpf-passwd.packages.${pkgs.stdenv.hostPlatform.system}.hpf-passwd
  ];

  # For a single user
  home.packages = [
    hpf-passwd.packages.${pkgs.stdenv.hostPlatform.system}.hpf-passwd
  ];
}
```

### Without flakes

Add the following to your `configuration.nix`:

```nix
{pkgs, ...}: let
  hpf-passwd = import (builtins.fetchTarball "https://github.com/Anomalocaridid/hpf-passwd/archive/master.tar.gz");
in {
  # For system-wide installation
  environment.systemPackages = [
    hpf-passwd.packages.${pkgs.stdenv.hostPlatform.system}.hpf-passwd
  ];

  # For a single user
  home.packages = [
    hpf-passwd.packages.${pkgs.stdenv.hostPlatform.system}.hpf-passwd
  ];
}
```
