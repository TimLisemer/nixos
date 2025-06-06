{
  disks,
  config,
  pkgs,
  ...
}: {
  # Import the common configuration shared across all machines
  imports = [
    (import ../common/disko.nix {inherit disks;})
    ./desktop-only-imports.nix
    ./tim-pc-hardware-configuration.nix
    ../common/nvidia.nix
  ];

  # Machine specific configurations

  networking.hostName = "tim-pc";

  # Portainer Container
  virtualisation.oci-containers.containers = {
    portainer = {
      image = "portainer/portainer-ce:lts";
      autoStart = true;
      ports = ["9000:9000"]; # Expose Portainer UI on host port 9000
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock" # Allow Portainer to manage Docker
        "/mnt/docker-data/volumes:/var/lib/docker/volumes:rw"
        "/mnt/docker-data/volumes/portainer:/data" # Persistent Portainer data
      ];
      cmd = ["--host" "unix:///var/run/docker.sock"];
      # Optional: if you want to limit privileges further, add extra options:
      # extraOptions = [ "--restart=always" ];
    };
  };

  boot = {
    kernelParams = ["acpi_enforce_resources=lax"];
    kernelModules = ["i2c-dev" "i2c-piix4"];
  };

  hardware = {
    i2c = {
      enable = true;
    };
  };

  # services.udev.extraRules = builtins.readFile ../files/OpenRGB/60-openrgb.rules;

  environment.systemPackages = with pkgs; [openrgb-with-all-plugins];

  services.hardware.openrgb.enable = true;
  systemd.user.services.openrgb = {
    description = "OpenRGB";
    wantedBy = ["default.target" "graphical-session.target"];
    partOf = ["graphical-session.target"];
    serviceConfig = {
      # ExecStart = "${pkgs.openrgb-with-all-plugins}/bin/openrgb --startminimized --profile 'On'";
      # ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = "/bin/openrgb --startminimized --profile 'On'";
      Restart = "on-failure";
      RestartSec = "5s";
      StartLimitIntervalSec = "10s";
      StartLimitBurst = "10";
      After = ["graphical-session.target" "network-online.target"];
    };
  };
}
