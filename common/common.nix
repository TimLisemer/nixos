{
  config,
  pkgs,
  inputs,
  home-manager,
  lib,
  users,
  hostName,
  hostIps,
  ...
}: let
  dockerBin = "${pkgs.docker}/bin/docker";
in {
  # imports
  imports = [
    home-manager.nixosModules.home-manager
  ];

  nix.settings = {
    # do **not** use mkForce – let other modules add their entries
    substituters = [
      "file:///nix/store?trusted=1" # keep local store
      "https://cache.nixos.org?priority=40"
      "https://nixos-raspberrypi.cachix.org?priority=30"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];

    trusted-users = ["root" "@wheel"];
  };

  # Environment Variables
  environment.variables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    MUTTER_DEBUG_KMS_THREAD_TYPE = "user";
    NODE_OPTIONS = "--max-old-space-size=4096";
    SGX_ENCLAVE_SIZE = "4G";
    RUST_MIN_STACK = "268435456";
    QT_QPA_PLATFORM = "wayland";
    NIXPKGS_ALLOW_UNFREE = "1"; # duplication with nixpkgs.config.allowUnfree
    WEBKIT_DISABLE_DMABUF_RENDERER = "1"; # Tauri Apps couldn’t run on NixOS NVIDIA
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    BLESH_PATH = "${pkgs.blesh}/share/blesh";
    # environment.variables.GEMINI_API_KEY = "YOUR_API_KEY"; # OPTIONAL - For Gemini CLI
  };

  # Enable experimental nix-command and flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Increase the download buffer size
  nix.settings.download-buffer-size = 524288000;

  # Allow unfree and broken packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowBroken = true;

  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # NixOS garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Load the kernel module for Silicon Labs USB-to-UART bridges. For the homeassistant yellow
  boot.kernelModules = ["cp210x"];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Some programs need SUID wrappers or run in user sessions
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # VSCode Server
  services.vscode-server.enable = true;

  # Container
  services.spice-vdagentd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  virtualisation.containers.enable = true;
  virtualisation.containers.registries.search = ["docker.io"];
  virtualisation.oci-containers.backend = "docker";
  virtualisation.docker = {
    enable = true;
    rootless.enable = true;
    rootless.setSocketVariable = true;
    # daemon.settings.ipv6 = true
    daemon.settings.data-root = "/mnt/docker-data";
  };

  # Unrestrict ports below 1000
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

  # Syncthing (disabled by default)
  services.syncthing = {
    enable = false;
    user = "tim";
    dataDir = "/home/tim";
    configDir = "/home/tim/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "tim-server" = {
          id = "ZKX6K7U-XPIMO7N-QM7KBU7-5OPVX7S-3E4UDW7-YKQBR2P-ZU4DC3F-ZYC34A3";
          autoAcceptFolders = true;
        };
      };
      folders = {
        "Home" = {
          path = "/home/tim";
          devices = ["tim-server"];
          addresses = ["tcp://10.0.0.2:22000"];
        };
      };
    };
  };

  users.users =
    lib.mapAttrs (_name: user: {
      isNormalUser = true;
      description = user.fullName;
      hashedPassword = user.hashedPassword;
      extraGroups = ["networkmanager" "wheel" "dialout" "docker"];
      openssh.authorizedKeys.keys = user.authorizedKeys or [];
    })
    users;

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    tree
    blesh
    wl-clipboard
    osc
    starship
    zoxide
    dconf2nix
    btop
    docker
    docker-compose
    nerd-fonts.jetbrains-mono
    switcheroo-control
    ssh-to-age
    atuin
    sops
    gnugrep
    gawk
    gnused
    getent
    nodejs
  ];

  networking.hostName = hostName;

  networking.extraHosts =
    lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: ip: "${ip} ${name}") hostIps);

  ##########################################################################
  ## Docker bridge network creation – run once at boot, ensure it exists ##
  ##########################################################################
  systemd.services.docker-network-create = {
    description = "Ensure docker bridge network “docker-network” exists";
    after = ["docker.service"];
    wantedBy = ["docker.service" "multi-user.target"];

    serviceConfig = {Type = "oneshot";};

    script = ''
      set -euo pipefail

      # --- Wait until Docker answers -------------------------------------------------
      for i in {1..30}; do
        if ${dockerBin} info >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done || {
        echo "Docker daemon did not become ready within 30 s" >&2
        exit 1
      }

      # --- Create network if missing -------------------------------------------------
      if ! ${dockerBin} network inspect docker-network >/dev/null 2>&1; then
        echo "Creating bridge network docker-network"
        ${dockerBin} network create \
          --driver bridge \
          --subnet 172.18.0.0/16 \
          --gateway 172.18.0.1 \
          docker-network
      else
        echo "Bridge network docker-network already exists"
      fi
    '';
  };

  ##########################################################################
  ## Firefox GNOME theme – run once at boot, fix every user’s profile    ##
  ##########################################################################
  systemd.services."firefox-theme-activation" = {
    description = "Ensure Firefox GNOME theme userContent.css is imported for all users";
    after = ["local-fs.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {Type = "oneshot";};

    script = ''
      # Iterate over every “real” user account
      getent passwd | awk -F: '$3 >= 1000 && $7 !~ /(false|nologin)/ {print $1}' |
      while read -r user; do
        home="$(getent passwd "$user" | cut -d: -f6)"
        profileDir="$home/.mozilla/firefox/default/chrome"

        mkdir -p "$profileDir"
        [ -s "$profileDir/userContent.css" ] || : > "$profileDir/userContent.css"

        if ! grep -Fxq '@import "firefox-gnome-theme/userContent.css";' \
                      "$profileDir/userContent.css"
        then
          sed -i '1i@import "firefox-gnome-theme/userContent.css";' \
              "$profileDir/userContent.css"
        fi

        chown -R "$user":"$(id -gn "$user")" "$home/.mozilla"
      done
    '';
  };

  ##########################################################################
  ## Discord Flatapk Rich Presence IPC socket fix                         ##
  ##########################################################################
  systemd.tmpfiles.rules = [
    # type  path                           mode uid gid age  target
    "L!     /run/user/%u/discord-ipc-0     -    -   -   -    /run/user/%u/app/com.discordapp.Discord/discord-ipc-0"
  ];

  # TTY Console
  console = {
    earlySetup = true; # apply before the login prompt
    # font = "ter-v32n"; # 16 × 32 Terminus, good for Hi-DPI
    # packages = with pkgs; [terminus_font]; # make sure the PSF is present
    keyMap = "de";
  };

  home-manager.sharedModules = [
    {
      home.stateVersion = "25.05";
      home.file = {
        ".bash_profile" = {
          source = builtins.toPath ../files/bash_profile;
          force = true;
        };
        ".bashrc" = {
          source = builtins.toPath ../files/bashrc;
          force = true;
        };
        ".config/starship.toml" = {
          source = builtins.toPath ../files/starship.toml;
          force = true;
        };
      };

      programs.atuin = {
        enable = true;
        # https://github.com/nix-community/home-manager/issues/5734
      };
    }
  ];

  home-manager.users.root = {
    # Files and folders to be symlinked into home
    home.file = {
      ".config/starship.toml" = lib.mkForce {
        source = builtins.toPath ../files/starship-root.toml;
        force = true;
      };
    };
  };

  virtualisation.oci-containers.containers = {
    # -------------------------------------------------------------------------
    # watchtower - automatically update containers
    # -------------------------------------------------------------------------
    watchtower = {
      image = "containrrr/watchtower";
      autoStart = true;

      autoRemoveOnStop = false; # prevent implicit --rm

      environment = {
        # Keep default 24-hour poll interval
        WATCHTOWER_POLL_INTERVAL = "86400"; # 24 hours in seconds
        # Cleanup old images after updating
        WATCHTOWER_CLEANUP = "true";
        # Set timezone for logs
        TZ = "Europe/Berlin";
        # Enable debug logging for better visibility
        WATCHTOWER_DEBUG = "true";
      };
    };
  };

  ##########################################################################
  ## Watchtower immediate startup check service                           ##
  ##########################################################################
  systemd.services.watchtower-startup-check = {
    description = "Run Watchtower check immediately on startup";
    after = ["docker-watchtower.service"];
    wants = ["docker-watchtower.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };

    script = ''
      set -euo pipefail

      # Wait a moment for watchtower container to be fully started
      sleep 10

      # Run a one-time watchtower check immediately
      ${dockerBin} run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -e WATCHTOWER_CLEANUP=true \
        -e TZ=Europe/Berlin \
        -e WATCHTOWER_DEBUG=true \
        containrrr/watchtower \
        --run-once

      echo "Initial Watchtower check completed"
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It’s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing it read the docs (e.g. man configuration.nix or
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
