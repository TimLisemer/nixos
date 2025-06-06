{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    steam
    wireshark
    # gnome-terminal
    ghostty
    geary
    intune-portal
    minecraft
    prismlauncher
    easyeffects
    rnote
    setzer
    gimp-with-plugins
    timeshift
    gnome-boxes
    loupe
    rpi-imager
    mediawriter
    postman
    vlc
    showtime
    google-chrome
    # discord
    webcord-vencord
    spotify

    arduino-ide
    qtcreator
    jetbrains.clion
    jetbrains.rider
    jetbrains.rust-rover
    jetbrains.idea-community
    jetbrains.pycharm-community
  ];

  programs.steam.enable = true;
  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };
}
