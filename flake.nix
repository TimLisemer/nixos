{
  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05"; # Stable channel for everything else
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # Unstable channel
    nixos-wsl.url = "github:nix-community/NixOS-WSL"; # NixOS WSL
    nixpkgs-oldvscode.url = "github:NixOS/nixpkgs/333d19c8b58402b94834ec7e0b58d83c0a0ba658"; # vscode 1.98.2
    flatpaks.url = "github:GermanBread/declarative-flatpak/stable-v3";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    alejandra = {
      # Nix formatter -> https://drakerossman.com/blog/overview-of-nix-formatters-ecosystem
      url = "github:kamadorueda/alejandra/4.0.0";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.astal.follows = "astal";
    };

    adwaita_hypercursor = {
      url = "github:dp0sk/Adwaita-HyprCursor";
      flake = false;
    };

    claude = {
      url = "github:k3d3/claude-desktop-linux-flake";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    firefox-gnome-theme = {
      url = "github:rafaelmardojai/firefox-gnome-theme";
      flake = false;
    };

    tim-nvim = {
      url = "github:timlisemer/nvim";
      flake = false;
    };
  };

  # Optional: Binary cache for the nixos-raspberrypi flake
  nixConfig = {
    extra-substituters = ["https://nixos-raspberrypi.cachix.org"];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs @ {
    self,
    nixpkgs-stable,
    nixpkgs-unstable,
    nixpkgs-oldvscode,
    flatpaks,
    disko,
    alejandra,
    sops-nix,
    vscode-server,
    home-manager,
    firefox-gnome-theme,
    nixos-wsl,
    nixos-raspberrypi,
    adwaita_hypercursor,
    tim-nvim,
    claude,
    ...
  }: let
    # ────────────────────────────────────────────────────────────────
    # Set IP Addresses for each host here, this will also be imported into pihole locale dns
    # ────────────────────────────────────────────────────────────────
    hostIps = {
      "tim-laptop" = "10.0.0.25";
      "tim-pc" = "10.0.0.3";
      "tim-server" = "142.132.234.128";
      "tim-pi4" = "10.0.0.76";
      "homeassistant-yellow" = "10.0.0.2";
      "traefik.local.yakweide.de" = "10.0.0.2";
      "pihole.local.yakweide.de" = "10.0.0.2";
      "files.local.yakweide.de" = "10.0.0.2";
      "portainer.local.yakweide.de" = "10.0.0.2";
      "syncthing.local.yakweide.de" = "10.0.0.2";
      "homeassistant.yakweide.de" = "10.0.0.2";
      "librechat.yakweide.de" = "142.132.234.128";
      "traefik.yakweide.de" = "142.132.234.128";
      # add more hosts here …
    };

    # ────────────────────────────────────────────────────────────────
    # Set User Information here
    # ────────────────────────────────────────────────────────────────
    users = {
      tim = {
        fullName = "Tim Lisemer";
        gitUsername = "timlisemer";
        gitEmail = "timlisemer@gmail.com";
        hashedPassword = "$6$fhbC3/uvj6gKqkYC$Kh4HKuYYbKdaag/D7yWP7VZAIdS9oGWudxiyy1HPsH0mUaTEf6X/QzNOM6Su0RhzvT4fXKNrj3gFt.iGpKGIj0"; # sha-512 crypt
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEae4h0Uk6x/lrmw0PZv/7GfWyLuEAVoc70AC4ykyFtX TimLisemer"
          # add more keys here …
        ];
      };
      # add more people here …
    };

    userBackupDirs = ["Coding" "Downloads" "Desktop" "Documents" "Pictures" "Videos" "Music" "Public" "Templates"];
    userDotFiles = [".config" ".mozilla" ".bash_history" ".steam" ".vscode-server" ".arduinoIDE" ".npm" ".vscode"];
    backupPaths = builtins.concatLists (builtins.map (
      username: let
        h = "/home/${username}/";
      in
        (map (dir: "${h}${dir}") userBackupDirs)
        ++ (map (dir: "${h}${dir}") userDotFiles)
    ) (builtins.attrNames users));
  in {
    mkSystem = {
      hostFile,
      system,
      disks ? null,
      hostName,
      users,
      backupPaths,
    }:
      nixpkgs-stable.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            disks
            inputs
            system
            home-manager
            adwaita_hypercursor
            self
            nixos-raspberrypi
            users
            hostName
            hostIps
            backupPaths
            ;

          # This node’s own IP
          ip = hostIps.${hostName};
        };

        modules = [
          disko.nixosModules.disko
          flatpaks.nixosModule
          vscode-server.nixosModules.default

          (import hostFile)
        ];
      };

    # ────────────────────────────────────────────────────────────────
    # Host Configurations
    # ────────────────────────────────────────────────────────────────
    nixosConfigurations = {
      tim-laptop = self.mkSystem {
        hostFile = ./hosts/tim-laptop.nix;
        system = "x86_64-linux";
        disks = ["/dev/nvme0n1"];
        hostName = "tim-laptop";
        backupPaths = backupPaths;
        inherit users;
      };

      tim-pc = self.mkSystem {
        hostFile = ./hosts/tim-pc.nix;
        system = "x86_64-linux";
        disks = ["/dev/nvme0n1" "/dev/nvme1n1"];
        hostName = "tim-pc";
        backupPaths = backupPaths;
        inherit users;
      };

      tim-server = self.mkSystem {
        hostFile = ./hosts/tim-server.nix;
        system = "x86_64-linux";
        disks = ["/dev/sda"];
        hostName = "tim-server";
        backupPaths = backupPaths;
        inherit users;
      };

      tim-wsl = self.mkSystem {
        hostFile = ./hosts/tim-wsl.nix;
        system = "x86_64-linux";
        hostName = "tim-wsl";
        backupPaths = backupPaths;
        inherit users;
      };

      tim-pi4 = self.mkSystem {
        hostFile = ./hosts/rpi4.nix;
        system = "aarch64-linux";
        hostName = "tim-pi4";
        backupPaths = backupPaths;
        inherit users;
      };

      homeassistant-yellow = let
        hostName = "homeassistant-yellow";
      in
        nixos-raspberrypi.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            {
              imports = with nixos-raspberrypi.nixosModules; [
                raspberry-pi-5.base
                raspberry-pi-5.bluetooth
              ];
            }
            vscode-server.nixosModules.default
            ./hosts/homeassistant-yellow.nix

            # Make the mapping (+ /etc/hosts entries) available everywhere
            ({
              config,
              pkgs,
              lib,
              ...
            }: {
              system.nixos.tags = let
                cfg = config.boot.loader.raspberryPi;
              in [
                "raspberry-pi-${cfg.variant}"
                cfg.bootloader
                config.boot.kernelPackages.kernel.version
              ];
            })
          ];

          specialArgs = {
            hostName = hostName;
            backupPaths = backupPaths;
            system = "aarch64-linux";
            inherit inputs home-manager adwaita_hypercursor self nixos-raspberrypi users hostIps;
          };
        };

      installer = let
        system = "x86_64-linux";
        pkgs = import nixpkgs-stable {inherit system;};
        hosts = ["tim-laptop" "tim-pc" "tim-server"];
        hostDisks = {
          "tim-laptop" = ["/dev/nvme0n1"];
          "tim-pc" = ["/dev/nvme0n1" "/dev/nvme1n1"];
          "tim-server" = ["/dev/sda"];
        };
      in
        nixpkgs-stable.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit self inputs hosts hostDisks home-manager adwaita_hypercursor users;
          };
          modules = [
            disko.nixosModules.disko
            vscode-server.nixosModules.default
            ({
              pkgs,
              lib,
              inputs,
              ...
            }: {
              imports = [
                (import ./common/installer.nix {
                  inherit pkgs self lib hosts hostDisks home-manager adwaita_hypercursor;
                })
              ];
            })
          ];
        };
    };
  };
}
