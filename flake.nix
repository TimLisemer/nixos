{
  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05"; # Stable channel for everything else
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # Unstable channel
    nixos-wsl.url = "github:nix-community/NixOS-WSL"; # NixOS WSL
    nixpkgs-oldvscode.url = "github:NixOS/nixpkgs/333d19c8b58402b94834ec7e0b58d83c0a0ba658"; # vscode 1.98.2
    flatpaks.url = "github:GermanBread/declarative-flatpak/stable-v3";
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs-stable";
      inputs.astal.follows = "astal";
    };

    alejandra = {
      # Nix formatter -> https://drakerossman.com/blog/overview-of-nix-formatters-ecosystem
      url = "github:kamadorueda/alejandra/4.0.0";
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

  # Optional: Binary cache for the flake
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
    tim-nvim,
    ...
  }: let
    # ────────────────────────────────────────────────────────────────
    # Set IP Addresses for each host here
    # ────────────────────────────────────────────────────────────────
    hostIps = {
      tim-laptop = "10.0.0.25";
      tim-pc = "10.0.0.3";
      tim-server = "142.132.234.128";
      tim-pi4 = "10.0.0.76";
      homeassistant-yellow = "10.0.0.2";
    };

    # ────────────────────────────────────────────────────────────────
    # Set User Information here
    # ────────────────────────────────────────────────────────────────
    users = {
      tim = {
        fullName = "Tim Lisemer";
        gitUsername = "timlisemer";
        gitEmail = "timlisemer@gmail.com";
        hashedPassword = "$6$K1WwF1Hn0r3j$6Pr1jZDl9yGsbM10Anwq7ieF6N61n3vg5EvAM9lGTRsaaqQwDmgeJ7NDNbgmZGCjqy7s1tt1XPB9I6G6SxSSi/"; # sha-512 crypt
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEae4h0Uk6x/lrmw0PZv/7GfWyLuEAVoc70AC4ykyFtX TimLisemer"
          # add more keys freely …
        ];
      };
      # add more people here …
    };
  in {
    mkSystem = {
      hostFile,
      system,
      disks ? null,
      hostName,
      users,
    }:
      nixpkgs-stable.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            disks
            inputs
            system
            home-manager
            self
            nixos-raspberrypi
            users
            ;

          # This node’s own IP
          ip = hostIps.${hostName};
        };

        modules = [
          disko.nixosModules.disko
          flatpaks.nixosModule
          vscode-server.nixosModules.default

          # Make the mapping (+ /etc/hosts entries) available everywhere
          ({lib, ...}: {
            networking.hostName = hostName;

            networking.extraHosts =
              lib.concatStringsSep "\n"
              (lib.mapAttrsToList (name: ip: "${ip} ${name}") hostIps);
          })

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
        inherit users;
      };

      tim-pc = self.mkSystem {
        hostFile = ./hosts/tim-pc.nix;
        system = "x86_64-linux";
        disks = ["/dev/nvme0n1" "/dev/nvme1n1"];
        hostName = "tim-pc";
        inherit users;
      };

      tim-server = self.mkSystem {
        # nix run nixpkgs#nixos-anywhere -- --flake ./#tim-server root@142.132.234.128
        hostFile = ./hosts/tim-server.nix;
        system = "x86_64-linux";
        disks = ["/dev/sda"];
        hostName = "tim-server";
        inherit users;
      };

      tim-wsl = self.mkSystem {
        hostFile = ./hosts/tim-wsl.nix;
        system = "x86_64-linux";
        hostName = "tim-wsl";
        inherit users;
      };

      tim-pi4 = self.mkSystem {
        hostFile = ./hosts/rpi4.nix;
        system = "aarch64-linux";
        hostName = "tim-pi4";
        inherit users;
      };

      homeassistant-yellow = nixos-raspberrypi.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          disko.nixosModules.disko
          vscode-server.nixosModules.default
          ./hosts/homeassistant-yellow.nix

          # Make the mapping (+ /etc/hosts entries) available everywhere
          ({lib, ...}: {
            networking.hostName = "homeassistant-yellow";

            networking.extraHosts =
              lib.concatStringsSep "\n"
              (lib.mapAttrsToList (name: ip: "${ip} ${name}") hostIps);
          })
        ];

        specialArgs = {
          disks = ["/dev/nvme0n1"];
          inherit inputs home-manager self nixos-raspberrypi users;
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
            inherit self inputs hosts hostDisks home-manager users;
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
                  inherit pkgs self lib hosts hostDisks home-manager;
                })
              ];
            })
          ];
        };

      installer-arm = let
        system = "aarch64-linux";
        pkgs = import nixpkgs-stable {inherit system;};
        hosts = ["homeassistant-yellow"];
        hostDisks = {
          "homeassistant-yellow" = ["/dev/nvme0n1"];
        };
      in
        nixos-raspberrypi.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              self
              inputs
              hosts
              hostDisks
              home-manager
              nixos-raspberrypi
              users
              ;
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
                  inherit pkgs self lib hosts hostDisks home-manager;
                })
              ];
              boot.kernelPackages = pkgs.rpi.linuxPackages_rpi5;

              # Allows missing modules, needed to build the system with the nixos-raspberrypi flake
              nixpkgs.overlays = [
                (final: super: {
                  makeModulesClosure = x:
                    super.makeModulesClosure (x // {allowMissing = true;});
                })
              ];
            })
          ];
        };
    };
  };
}
