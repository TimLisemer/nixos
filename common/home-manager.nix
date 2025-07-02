{
  config,
  pkgs,
  inputs,
  home-manager,
  lib,
  isDesktop,
  isWsl,
  isServer,
  isHomeAssistant,
  users,
  ...
}: let
in {
  # Import the Home Manager NixOS module
  imports = [
  ];

  # NixOS system-wide home-manager configuration
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
    (import ./common-home-manager.nix {
      inherit config pkgs inputs home-manager lib isDesktop isWsl isServer isHomeAssistant;
    })
  ];

  # Home Manager individual user configuration
  home-manager.users =
    lib.mapAttrs (_name: user: {
      programs.git = {
        enable = true;
        userName = user.gitUsername;
        userEmail = user.gitEmail;
        extraConfig = {
          init.defaultBranch = "main";
          safe.directory = ["/etc/nixos" "/tmp/NixOs"];
          pull.rebase = "true";
          push.autoSetupRemote = true;
          core.autocrlf = "input";
          core.eol = "lf";
        };
      };
      home.file = {
        ".config/ags" = {
          source = builtins.toPath ../files/ags;
          force = true;
        };
        ".config/hypr/hyprland.conf" = {
          source = builtins.toPath ../files/hypr/hyprland.conf;
          force = true;
        };
      };
    })
    users;
}
