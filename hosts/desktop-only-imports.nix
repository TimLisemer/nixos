{
  config,
  pkgs,
  inputs,
  home-manager,
  lib,
  ...
}: {
  imports = [
    ../common/common.nix
    ../common/desktop-only.nix
    (import ../common/home-manager.nix {
      inherit config pkgs inputs home-manager lib;
      isDesktop = true;
      isWsl = false;
      isServer = false;
      isHomeAssistant = false;
      isInstaller = false;
    })
    ../packages/packages.nix
    ../desktop-environments/desktop-environments.nix
    inputs.sops-nix.nixosModules.sops
    ../secrets/sops.nix
  ];

  environment.variables.DESKTOP = "1";
}
