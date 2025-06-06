{
  disks,
  host,
  pkgs,
  self,
  ...
}: let
  dependencies =
    [
      self.nixosConfigurations.${host}.config.system.build.toplevel
      self.nixosConfigurations.${host}.config.system.build.diskoScript
      self.nixosConfigurations.${host}.config.system.build.diskoScript.drvPath
      self.nixosConfigurations.${host}.pkgs.stdenv.drvPath

      self.nixosConfigurations.${host}.pkgs.perlPackages.ConfigIniFiles
      self.nixosConfigurations.${host}.pkgs.perlPackages.FileSlurp

      (self.nixosConfigurations.${host}.pkgs.closureInfo {rootPaths = [];}).drvPath
    ]
    ++ builtins.map (i: i.outPath) (builtins.attrValues self.inputs);

  closureInfo = pkgs.closureInfo {rootPaths = dependencies;};
in {
  imports = [
    ./common.nix
    (import ../common/home-manager.nix {
      inherit config pkgs inputs home-manager lib;
      isDesktop = false;
      isWsl = false;
      isServer = false;
      isHomeAssistant = false;
      isInstaller = true;
    })
  ];

  environment.etc."install-closure".source = "${closureInfo}/store-paths";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "install-${host}" ''
      set -eux
      nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- --mode zap_create_mount ${self}/common/disko.nix --arg disks '${builtins.toJSON (
        if builtins.isList disks
        then disks
        else throw "disks must be a list of strings"
      )}'
      touch /root/counter3
      mkdir -p /mnt/etc/nixos
      cp -a ${self}/* /mnt/etc/nixos/
      nixos-install --flake "/mnt/etc/nixos#${host}"
      reboot
    '')
  ];
}
