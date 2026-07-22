{
  description = "Manage passwords on NixOS systems that use `hashedPasswordFile`";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  };

  outputs =
    { self, nixpkgs }:
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
    in
    rec {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          hpf-passwd = pkgs.callPackage ./package.nix { };
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
            nixos-option
          ];
        }
      );
    };
}
