{
  config,
  inputs,
  system,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    config = {allowUnfree = true;};
    inherit system;
  };
in {
  environment.systemPackages = with pkgs; [
    adw-gtk3
    alejandra
    awscli2
    dbus
    nautilus-open-any-terminal
    syncthing
    vaapiVdpau
    comfortaa
    bat
    cliphist
    dejavu_fonts
    dracut
    elfutils
    ethtool
    dex
    wol
    restic
    fastfetch
    fd
    ffmpeg
    fzf
    gamemode
    gamescope
    minicom
    screen
    unzip
    justbuild
    pulseaudio
    sockdump
    nix-prefetch
    nix-prefetch-git
    qemu
    inetutils
    nmap
    ripgrep
    openvpn
    trash-cli
    vdpauinfo
    resources
    rclone
    xorg.xeyes
    distrobox
    dive
    i2c-tools
    unstable.gemini-cli
    unstable.claude-code
    unstable.codex
    liquidctl
    glxinfo
    jq
    libglvnd
    mesa
    nixpkgs-fmt
    xorg.libxcb
    openal
    rpiboot
    screen
    spice
    # spice-gtk
    virt-viewer
    libvirt
    virt-manager
  ];
}
