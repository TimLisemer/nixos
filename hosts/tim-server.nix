{
  config,
  pkgs,
  inputs,
  home-manager,
  lib,
  disks,
  ...
}: {
  # Import the common configuration shared across all machines
  imports = [
    (import ../common/disko.nix {inherit disks;})
    ../common/common.nix
    ../packages/system-packages.nix
    ../packages/dependencies.nix
    (import ../common/home-manager.nix {
      inherit config pkgs inputs home-manager lib;
      isDesktop = false;
      isWsl = false;
      isServer = true;
      isHomeAssistant = false;
      isInstaller = false;
    })
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = lib.mkForce 1;

  # Machine specific configurations

  networking.hostName = "tim-server";

  environment.variables.SERVER = "1";

  environment.systemPackages = with pkgs; [
  ];

  virtualisation.docker.storageDriver = "btrfs";

  virtualisation.oci-containers.containers = {
    # --------------------------------------------------------------------------
    # yakweide-discord-bot
    # --------------------------------------------------------------------------
    yakweide-discord-bot = {
      image = "ghcr.io/yakweide/yakweide-discord-bot:latest";
      autoStart = true;

      extraOptions = [
        "--network=docker-network"
        "--restart=always"
      ];

      environmentFiles = [
        config.sops.secrets.yakweideENV.path
      ];
    };

    # --------------------------------------------------------------------------
    # vaultwarden
    # --------------------------------------------------------------------------
    vaultwarden = {
      image = "vaultwarden/server:latest";
      autoStart = true;

      extraOptions = [
        "--network=docker-network"
        "--restart=always"
      ];

      ports = [
        "4743:4743" # hostPort:containerPort
      ];

      volumes = [
        "/mnt/docker-data/volumes/vaultwarden:/data:rw"
      ];

      environmentFiles = [
        config.sops.secrets.traefikEnv.path
      ];

      environment = {
        SIGNUPS_ALLOWED = "false";
        INVITATIONS_ALLOWED = "true";

        ROCKET_PROFILE = "release";
        ROCKET_ADDRESS = "0.0.0.0";
        ROCKET_PORT = "4743";

        DEBIAN_FRONTEND = "noninteractive";
      };

      # -------------------------------------------------------------------------
      # syncthing
      # -------------------------------------------------------------------------
      syncthing = {
        image = "syncthing/syncthing:latest";
        autoStart = true;

        extraOptions = [
          "--network=docker-network"
          "--restart=always"
        ];

        # TCP and UDP ports – duplicates from the original command removed
        ports = [
          "21027:21027/tcp"
          "21027:21027/udp"
          "22000:22000/tcp"
          "22000:22000/udp"
          "22067:22067/tcp"
          "22067:22067/udp"
          "8384:8384" # Syncthing UI
        ];

        volumes = [
          "/mnt/docker-data/volumes/syncthing:/var/syncthing:rw"
        ];

        environment = {
          PUID = "1000";
          PGID = "1000";
          HOME = "/var/syncthing";
          STGUIADDRESS = "0.0.0.0:8384";
          STHOMEDIR = "/var/syncthing/config";
        };
      };

      # -------------------------------------------------------------------------
      # traefik  (uses a secret file for the Cloudflare token)
      # -------------------------------------------------------------------------
      traefik = {
        image = "traefik:latest";
        autoStart = true;

        extraOptions = [
          "--network=docker-network"
          "--restart=always"
        ];

        ports = [
          "443:443"
          "80:80"
          "8085:8080" # Traefik dashboard
        ];

        volumes = [
          "/mnt/docker-data/volumes/traefik:/etc/traefik:rw"
          "/var/run/docker.sock:/var/run/docker.sock:rw"
        ];

        # Every key=value in this file becomes a container env-var.
        # Put *only* secrets in there to keep the file small.
        environmentFiles = [
          config.sops.secrets.traefikEnv.path
        ];

        # Non-secret variables can stay inline.
        environment = {
          # Keys with dots must be quoted to be valid Nix attribute names
          "traefik.http.routers.api.rule" = "Host(`traefik.local.yakweide.de`)";
          "traefik.http.routers.api.entryPoints" = "https";
          "traefik.http.routers.api.service" = "api@internal";
          "traefik.enable" = "true";
        };
      };

      # -------------------------------------------------------------------------
      # portainer_agent
      # -------------------------------------------------------------------------
      portainer_agent = {
        image = "portainer/agent:latest";
        autoStart = true;

        extraOptions = [
          "--network=bridge" # exactly as in your docker run
          "--restart=always"
        ];

        ports = ["9001:9001"];

        volumes = [
          "/mnt/docker-data/volumes:/var/lib/docker/volumes:rw"
          "/var/run/docker.sock:/var/run/docker.sock:rw"
        ];
        # No environment values needed for the agent
      };
    };
  };
}
