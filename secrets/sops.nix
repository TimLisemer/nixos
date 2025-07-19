{
  config,
  pkgs,
  inputs,
  hostName,
  ...
}: {
  # sops encryption settings
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/etc/ssh/nixos_personal_sops_key"];
  # sops.age.keyFile      = "/home/tim/.config/sops/age/keys.txt";
  # sops.age.generateKey  = true;

  sops.secrets.github_token = {};
  sops.secrets.google_oauth_client_id = {};
  sops.secrets.vaultwardenEnv = {};
  sops.secrets.traefikENV = {};
  sops.secrets.yakweideENV = {};
  sops.secrets.piholePWD = {};
  sops.secrets.immichENV = {};
  sops.secrets.wifiENV = {};
  sops.secrets.cloudflare_rclone = {};
  sops.secrets.google-sa = {
    sopsFile = ./secrets.yaml;
    key = "google_drive_sa_json";
    path = "/run/secrets/google-sa";
    # restartUnits = ["rclone-gdrive.mount"]; # auto-reload after key rotation
  };
  sops.secrets.restic_password = {};
  sops.secrets.restic_environment = {};
  sops.secrets.restic_repo_base = {};

  # build a tiny file at runtime that *does* include the hostname
  sops.templates.restic_repo = {
    owner = "root";
    mode = "0400";
    content = "${config.sops.placeholder."restic_repo_base"}/${hostName}";
    # optional: restart backup unit on change
    restartUnits = ["restic-backups-${hostName}.service"];
  };

  sops.secrets.openvpn_ca = {owner = "nm-openvpn";};
  sops.secrets.openvpn_extra_certs = {group = "nm-openvpn";};
  sops.secrets.openvpn_cert = {group = "nm-openvpn";};
  sops.secrets.openvpn_key = {group = "nm-openvpn";};
  sops.secrets.openvpn_ta = {group = "nm-openvpn";};
}
