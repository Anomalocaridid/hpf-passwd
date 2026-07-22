{
  argc,
  bash,
  bashunit,
  coreutils,
  gnused,
  installShellFiles,
  lib,
  mkpasswd,
  nixos-option,
  resholve,
  shellcheck,
  shfmt,
  stdenvNoCC,
}:

resholve.mkDerivation {
  pname = "hpf-passwd";
  version = "unstable";

  src = ./.;

  dontConfigure = true;
  dontUnpack = true;

  nativeBuildInputs = [
    installShellFiles
    argc
  ];

  solutions = {
    default = {
      scripts = [ "bin/hpf-passwd" ];
      interpreter = lib.getExe bash;
      inputs = [
        argc
        coreutils
        gnused
        mkpasswd
        nixos-option
      ];

      execer = [
        "cannot:${lib.getExe nixos-option}"
        "cannot:${lib.getExe argc}"
      ];
    };
  };

  buildPhase = ''
    runHook preBuild

    mkdir ./build
    cp $src/src/hpf-passwd.sh ./build/hpf-passwd
    argc --argc-mangen $src/src/hpf-passwd.sh ./build

    runHook postBuild
  '';

  doCheck = true;

  nativeCheckInputs = [
    shellcheck
    shfmt
    bashunit
    # hpf-passwd.sh's dependencies
    argc
    coreutils
    gnused
    mkpasswd
    nixos-option
  ];

  checkPhase = ''
    runHook preCheck

    shellcheck $src/src/hpf-passwd.sh
    shfmt --diff $src/src/hpf-passwd.sh

    pushd $src
    bashunit test
    popd

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm555 ./build/hpf-passwd $out/bin/hpf-passwd

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installManPage ./build/hpf-passwd.1

    installShellCompletion --cmd hpf-passwd \
      --bash <(argc --argc-completions bash hpf-passwd) \
      --zsh <(argc --argc-completions zsh hpf-passwd) \
      --fish <(argc --argc-completions fish hpf-passwd) \
      --nushell <(argc --argc-completions nushell hpf-passwd) 
  '';

  meta = {
    description = "Manage passwords on NixOS systems that use `hashedPasswordFile`";
    license = lib.licenses.agpl3Only;
    mainProgram = "hpf-passwd";
  };
}
