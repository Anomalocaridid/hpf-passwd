{
  description = "Manage passwords on NixOS systems that use `hashedPasswordFile`";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    flake-compat = {
      url = "github:NixOS/flake-compat";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );

      # This project relies on a patch to nixos-option that adds an `--extra-experimental-features` flag
      # TODO: remove when https://github.com/NixOS/nixpkgs/pull/546044 makes it into nixos-unstable
      nixos-option-patched = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          nixpkgs-546044-drv = pkgs.applyPatches {
            src = pkgs.path;
            patches = [
              (pkgs.fetchpatch2 {
                url = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/546044.patch?full_index=1";
                hash = "sha256-Ci1weyeWNkTwOgo/F4GcJM5eDA9ho+Ca1JOgSt37tyk=";
              })
            ];
          };

          nixpkgs-546044 = import nixpkgs-546044-drv { inherit (pkgs.stdenv) system; };
        in
        nixpkgs-546044.nixos-option
      );
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          hpf-passwd = pkgs.callPackage ./package.nix { nixos-option = nixos-option-patched.${system}; };
          default = hpf-passwd;
        }
      );

      devShell = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.mkShell {
          buildInputs = with pkgs; [
            bash-language-server # LSP for IDEs
            bashunit # Unit testing framework
            shellcheck # More diagnostics for language server
            shfmt # Formatter

            # hpf-passwd.sh's dependencies
            argc
            coreutils
            gnused
            mkpasswd
            nixos-option-patched.${system}
          ];
        }
      );
    };
}
