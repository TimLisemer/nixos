{
  config,
  pkgs,
  inputs,
  ...
}: {
  # sops encription settings
  sops.defaultSopsFile = ./secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = ["/etc/ssh/nixos_personal_sops_key"];
  # sops.age.keyFile = "/home/tim/.config/sops/age/keys.txt";
  # sops.age.generateKey = true;
  sops.secrets.github_token = {};
  sops.secrets.google_oauth_client_id = {};
  sops.secrets.cloudflare_rclone = {};
  sops.secrets.traefikEnv = {};
  sops.secrets.yakweideENV = {};
  sops.secrets.google-sa = {
    sopsFile = ./secrets.yaml;
    key = "google_drive_sa_json";
    path = "/run/secrets/google-sa";
    # restartUnits = ["rclone-gdrive.mount"]; # auto-reload after key rotation
  };
}
