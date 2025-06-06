{
  config,
  pkgs,
  inputs,
  ...
}: {
  # Environment Variables
  environment.variables = {
    RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    MUTTER_DEBUG_KMS_THREAD_TYPE = "user";
    NODE_OPTIONS = "--max-old-space-size=4096";
    SGX_ENCLAVE_SIZE = "4G";
    RUST_MIN_STACK = "268435456";
    QT_QPA_PLATFORM = "wayland";
    NIXPKGS_ALLOW_UNFREE = "1"; # duplication with nixpkgs.config.allowUnfree
    WEBKIT_DISABLE_DMABUF_RENDERER = "1"; # Tauri Apps couldn’t run on NixOS NVIDIA
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    BLESH_PATH = "${pkgs.blesh}/share/blesh";
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
    rootless.enable = false; # Use rootful Docker
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

  users.users.tim = {
    isNormalUser = true;
    hashedPassword = "$6$fhbC3/uvj6gKqkYC$Kh4HKuYYbKdaag/D7yWP7VZAIdS9oGWudxiyy1HPsH0mUaTEf6X/QzNOM6Su0RhzvT4fXKNrj3gFt.iGpKGIj0"; # mkpasswd -m sha-512 <your-password>
    description = "Tim Lisemer";
    extraGroups = ["networkmanager" "wheel" "dialout" "docker"];
  };

  # Google Drive Rclone Mount
  environment.etc."rclone-gdrive.conf".text = ''
    [gdrive]
    type = drive
    client_id = /run/secrets/google_oauth_client_id
    scope = drive
    service_account_file = /run/secrets/google-sa
  '';
  fileSystems."/mnt/gdrive" = {
    device = "gdrive:";
    fsType = "rclone";
    options = [
      "nodev"
      "nofail"
      "allow_other"
      "args2env"
      "config=/etc/rclone-gdrive.conf"
      # --- network-related bits ---
      "_netdev" # mark as “needs the network”
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
    ];
  };
  # Cloudflare R2 Rclone Mount
  fileSystems."/mnt/cloudflare" = {
    device = "cloudflare:nixos";
    fsType = "rclone";
    options = [
      "nodev"
      "nofail"
      "allow_other"
      "args2env"
      "config=/run/secrets/cloudflare_rclone"
      # --- network-related bits ---
      "_netdev" # mark as “needs the network”
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    tree
    blesh
    wl-clipboard
    starship
    zoxide
    dconf2nix
    btop
    docker
    docker-compose
    nerd-fonts.jetbrains-mono
    switcheroo-control
  ];

  # Open ports in the firewall
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable entirely:
  networking.firewall.enable = false;

  # TTY Console
  console = {
    earlySetup = true; # apply before the login prompt
    # font = "ter-v32n"; # 16 × 32 Terminus, good for Hi-DPI
    # packages = with pkgs; [terminus_font]; # make sure the PSF is present
    keyMap = "de";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It’s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing it read the docs (e.g. man configuration.nix or
  # https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
