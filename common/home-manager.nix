{
  config,
  pkgs,
  inputs,
  home-manager,
  lib,
  isDesktop,
  isWsl,
  isServer,
  isHomeAssistant,
  isInstaller,
  ...
}: {
  # Import the Home Manager NixOS module
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  # NixOS system-wide home-manager configuration
  home-manager.sharedModules = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Home Manager configuration for the user 'tim'
  home-manager.users.tim = {
    # Specify the Home Manager state version
    home.stateVersion = "25.05";

    imports =
      lib.optionals isDesktop [./dconf.nix]
      ++ [
        ./qemu.nix
      ];

    # Sops Home Configuration
    sops.defaultSopsFile = ../secrets/secrets.yaml;
    sops.defaultSopsFormat = "yaml";
    sops.age.sshKeyPaths = [".ssh/id_ed25519y"];

    # Git configuration
    programs.git = {
      enable = true;
      userName = "timlisemer";
      userEmail = "timlisemer@gmail.com";

      # Set the default branch name using the attribute set format
      extraConfig = {
        init.defaultBranch = "main";
        safe.directory = ["/etc/nixos" "/tmp/NixOs"];
        pull.rebase = "true";
        push.autoSetupRemote = true;
        core.autocrlf = "input";
        core.eol = "lf";
      };
    };

    # Firefox Theme
    home.file.".mozilla/firefox/default/chrome/firefox-gnome-theme" = {
      source = inputs.firefox-gnome-theme;
      force = true;
    };
    home.file.".mozilla/firefox/default/chrome/userChrome.css" = {
      text = ''
        @import "firefox-gnome-theme/userChrome.css";
        @import "firefox-gnome-theme/theme/colors/dark.css";
      '';
      force = true;
    };

    home.activation = {
      firefoxThemeActivation = ''
        # Ensure userContent.css exists and is non-empty
        mkdir -p $HOME/.mozilla/firefox/default/chrome/
        [[ -s "$HOME/.mozilla/firefox/default/chrome/userContent.css" ]] || echo >> "$HOME/.mozilla/firefox/default/chrome/userContent.css"

        # Insert @import statement at the beginning of userContent.css before any @namespace
        grep -Fxq '@import "firefox-gnome-theme/userContent.css";' "$HOME/.mozilla/firefox/default/chrome/userContent.css" || sed -i '1i@import "firefox-gnome-theme/userContent.css";' "$HOME/.mozilla/firefox/default/chrome/userContent.css"
      '';
    };

    programs.firefox = {
      enable = true;
      nativeMessagingHosts = [pkgs.web-eid-app];
      profiles = {
        default = {
          id = 0;
          name = "default";
          isDefault = true;
          settings = {
            "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
            "signon.rememberSignons" = false;

            # For Firefox GNOME theme:
            "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
            "browser.tabs.drawInTitlebar" = true;
            "svg.context-properties.content.enabled" = true;
            "widget.gtk.rounded-bottom-corners.enabled" = true;

            # Automatically load the YubiKey PKCS#11 module
            "security.osclientcerts.autoload" = true;
          };
        };
      };
    };

    programs.atuin = {
      enable = true;
      # https://github.com/nix-community/home-manager/issues/5734
    };

    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 1800;
      enableSshSupport = true;
    };

    home.packages = with pkgs; [
      atuin
      sops
    ];

    # Files and folders to be symlinked into home
    home.file = {
      ".config/ags" = {
        source = builtins.toPath ../files/ags;
        force = true;
      };
      ".config/hypr" = {
        source = builtins.toPath ../files/hypr;
        force = true;
      };
      ".config/starship.toml" = {
        source = builtins.toPath ../files/starship.toml;
        force = true;
      };
      "Pictures/Wallpapers" = {
        source = builtins.toPath ../files/Wallpapers;
        force = true;
      };
      ".bash_profile" = {
        source = builtins.toPath ../files/bash_profile;
        force = true;
      };
      ".bashrc" = {
        source = builtins.toPath ../files/bashrc;
        force = true;
      };
      ".stignore" = {
        source = builtins.toPath ../files/stignore;
        force = true;
      };
      ".vimrc" = {
        source = builtins.toPath ../files/vimrc;
        force = true;
      };

      # Arduino
      ".arduinoIDE/arduino-cli.yaml" = {
        source = builtins.toPath ../files/arduino/arduino-cli.yaml;
        force = true;
      };

      # EasyEffects
      ".config/easyeffects/autoload/input/alsa_input.usb-R__DE_R__DE_NT-USB__02447C32-00.mono-fallback:.json" = {
        source = builtins.toPath ../files/easyeffects/autoload/input;
        force = true;
      };
      ".config/easyeffects/input/Discord.json" = {
        source = builtins.toPath ../files/easyeffects/input;
        force = true;
      };

      # OpenRGB
      ".config/OpenRGB/plugins/settings" = {
        source = ../files/OpenRGB/plugins/settings;
        force = true;
      };
      ".config/OpenRGB/Off.orp" = {
        source = ../files/OpenRGB/Off.orp;
        force = true;
      };
      ".config/OpenRGB/On.orp" = {
        source = ../files/OpenRGB/On.orp;
        force = true;
      };
      ".config/OpenRGB/OpenRGB.json" = {
        source = ../files/OpenRGB/OpenRGB.json;
        force = true;
      };
      ".config/OpenRGB/sizes.ors" = {
        source = ../files/OpenRGB/sizes.ors;
        force = true;
      };

      # nvim
      ".config/nvim/after" = {
        source = "${inputs.tim-nvim}/after";
        force = true;
      };
      ".config/nvim/lua" = {
        source = "${inputs.tim-nvim}/lua";
        force = true;
      };
      ".config/nvim/init.lua" = {
        source = "${inputs.tim-nvim}/init.lua";
        force = true;
      };

      # Vscode
      ".config/Code/User/settings.json" = {
        source = builtins.toPath ../files/vscode/settings.json;
        force = true;
      };
      ".config/Code/User/keybindings.json" = {
        source = builtins.toPath ../files/vscode/keybindings.json;
        force = true;
      };

      # Autostart
      ".config/autostart" = {
        source = ../files/autostart;
        force = true;
      };

      # Mimeapps
      ".config/mimeapps.list" = {
        source = builtins.toPath ../files/mimeapps.list;
        force = true;
      };

      # Gnome
      ".config/gnome-initial-setup-done" = {
        text = ''yes'';
        force = true;
        executable = false;
      };

      # SSH Authorized Keys
      ".ssh/authorized_keys" = {
        text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEae4h0Uk6x/lrmw0PZv/7GfWyLuEAVoc70AC4ykyFtX TimLisemer";
        force = true;
      };

      # Terminals
      ".config/ghostty/config" = {
        source = builtins.toPath ../files/ghostty/config;
        force = true;
      };
      ".local/share/icons/hicolor/16x16/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_16.png;
        force = true;
      };
      ".local/share/icons/hicolor/32x32/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_32.png;
        force = true;
      };
      ".local/share/icons/hicolor/128x128/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_128.png;
        force = true;
      };
      ".local/share/icons/hicolor/256x256/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_256.png;
        force = true;
      };
      ".local/share/icons/hicolor/512x512/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_512.png;
        force = true;
      };
      ".local/share/icons/hicolor/1024x1024/apps/com.mitchellh.ghostty.png" = {
        source = builtins.toPath ../files/icons/ghostty/com.mitchellh.ghostty_1024.png;
        force = true;
      };
    };

    # Steam adwaita theme
    systemd.user.services.installAdwaitaTheme = {
      Unit = {
        Description = "Install Adwaita Theme for Steam";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "install-adwaita-theme" ''
          if [ ! -d $HOME/.config/steam-adwaita-theme ]; then
            ${pkgs.git}/bin/git clone https://github.com/tkashkin/Adwaita-for-Steam $HOME/.config/steam-adwaita-theme
          else
            cd $HOME/.config/steam-adwaita-theme
            ${pkgs.git}/bin/git reset --hard
            ${pkgs.git}/bin/git pull
          fi
          cd $HOME/.config/steam-adwaita-theme
          ${pkgs.python3}/bin/python3 install.py -c adwaita -e library/hide_whats_new
        ''}";
      };
      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
