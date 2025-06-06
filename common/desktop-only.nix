# Stuff that only makes sense on bare-metal / desktop NixOS, not inside WSL
{
  config,
  pkgs,
  lib,
  ...
}: {
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = lib.mkForce 1;

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # Enable the GDM Display Manager
  services.xserver.displayManager.gdm.enable = true;

  # Enable Smartcard Support
  hardware.gpgSmartcards.enable = true;
  services.pcscd.enable = true;
  services.udev.packages = [pkgs.yubikey-manager];
  environment.etc."chromium/native-messaging-hosts/eu.webeid.json".source = "${pkgs.web-eid-app}/share/web-eid/eu.webeid.json";
  environment.etc."opt/chrome/native-messaging-hosts/eu.webeid.json".source = "${pkgs.web-eid-app}/share/web-eid/eu.webeid.json";
  # Tell p11-kit to load/proxy opensc-pkcs11.so, providing all slots
  # (PIN1 for auth/decrypt, PIN2 for signing).
  environment.etc."pkcs11/modules/opensc-pkcs11".text = ''
    module: ${pkgs.opensc}/lib/opensc-pkcs11.so
  '';
  environment.systemPackages = with pkgs; [
    # Wrapper for Chrome/Chromium to use p11-kit-proxy for PKCS#11
    (writeShellScriptBin "setup-browser-eid" ''
      NSSDB="''${HOME}/.pki/nssdb"
      mkdir -p ''${NSSDB}
      ${pkgs.nssTools}/bin/modutil -force -dbdir sql:$NSSDB \
        -add p11-kit-proxy \
        -libfile ${pkgs.p11-kit}/lib/p11-kit-proxy.so
    '')
  ];

  # Enable touchpad support (libinput default)
  # services.xserver.libinput.enable = true;

  # Enable Switcheroo
  services.switcherooControl.enable = true;

  # Laptop lid switch on external power
  services.logind.lidSwitchExternalPower = "ignore";

  # Enable Power Profiles
  services.power-profiles-daemon.enable = true;

  virtualisation.docker.storageDriver = "btrfs";

  # Fix shebangs in scripts # Try to bring this back to common/common.nix however currently it breaks a lot of things for example npm
  services.envfs.enable = true;

  # Enable sound with PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber = {
      enable = true;

      ###########################################################################
      # 1.  Load the software-DSP policy so we can use “hide-parent = true”
      ###########################################################################
      extraConfig."50-enable-softwaredsp" = {
        "wireplumber.profiles" = {
          main = {
            "node.software-dsp" = "required";
          };
        };
      };

      ###########################################################################
      # 2.  Audio policy – single fragment, all rules in one place
      ###########################################################################
      extraConfig."99-my-audio" = {
        # ----------------------------------------------------------------------
        # 2a.  Device- and node-level rules handled by the ALSA monitor
        # ----------------------------------------------------------------------
        "monitor.alsa.rules" = [
          # — A —  hide NVIDIA HDMI card completely
          {
            matches = [{"device.name" = "alsa_card.pci-0000_09_00.1";}];
            actions.update-props.device.disabled = true;
          }

          # — B —  hide webcam audio device
          {
            matches = [
              {
                "device.name" = "alsa_card.usb-Startime_Communication._Ltd._KAYSUDA_CA20_.*-00";
              }
            ];
            actions.update-props.device.disabled = true;
          }

          # — C —  motherboard ALC1220 → keep **only** the S/PDIF profile
          {
            matches = [{"device.name" = "alsa_card.pci-0000_0b_00.4";}];
            actions.update-props = {
              device.profile = "output:iec958-stereo";
              device.nick = "Speakers";
              device.description = "Speakers";
            };
          }

          # — D —  rename Sound-Blaster Omni card
          {
            matches = [
              {
                "device.name" = "alsa_card.usb-Creative_Technology_Ltd_SB_Omni_Surround_5.1_.*";
              }
            ];
            actions.update-props = {
              device.nick = "Sound Blaster Omni";
              device.description = "Sound Blaster Omni";
            };
          }

          # — E —  RØDE NT-USB → keep mic, drop playback sink
          {
            matches = [{"node.name" = "alsa_output.usb-R__DE_R__DE_NT-USB__.*";}];
            actions.update-props.node.disabled = true;
          }
          {
            matches = [{"node.name" = "alsa_input.usb-R__DE_R__DE_NT-USB__.*";}];
            actions.update-props = {
              node.nick = "RØDE NT-USB Mic";
              node.description = "RØDE NT-USB Mic";
            };
          }
        ];

        # ----------------------------------------------------------------------
        # 2b.  Software-DSP rules – hide or rename individual nodes
        # ----------------------------------------------------------------------
        "node.software-dsp.rules" = [
          # hide the Omni IEC958 node completely
          {
            matches = [
              {
                "node.name" = "alsa_output.usb-Creative_Technology_Ltd_SB_Omni_.*.iec958-stereo";
              }
            ];
            actions.create-filter.hide-parent = true;
          }

          # cosmetic rename for the Omni analogue port
          {
            matches = [
              {
                "node.name" = "alsa_output.usb-Creative_Technology_Ltd_SB_Omni_.*.analog-stereo-output";
              }
            ];
            actions.update-props = {
              node.nick = "Headphones";
              node.description = "Headphones";
            };
          }

          # NEW: hide the EasyEffects virtual sink so it never shows up
          {
            matches = [{"node.name" = "easyeffects_sink";}];
            actions.create-filter.hide-parent = true;
          }
        ];
      };
    };
  };
}
