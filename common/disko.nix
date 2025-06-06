# disko-two-disk-raid0.nix
{disks, ...}: let
  rawdisk1 = builtins.elemAt disks 0;
  rawdisk2 =
    if (builtins.length disks) > 1
    then builtins.elemAt disks 1
    else null;

  # Path to the *partition* we create on the 2nd disk (p1 because there is no ESP here)
  rootPart2 =
    if rawdisk2 != null
    then "${rawdisk2}p1"
    else null;
in {
  disko.devices = {
    disk =
      ########################
      ## 1st physical disk  ##
      ########################
      {
        "${rawdisk1}" = {
          device = rawdisk1;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                label = "EFI";
                name = "ESP";
                size = "1024M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };

              root = {
                label = "rootfs";
                name = "btrfs";
                size = "100%";
                content = {
                  type = "btrfs";

                  # Add the 2nd-disk partition to the mkfs command when it exists
                  extraArgs =
                    if rootPart2 != null
                    then ["-f" "-d" "raid0" "-m" "raid0" rootPart2]
                    else ["-f"];

                  subvolumes = {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "@/home" = {
                      mountpoint = "/home";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "@/docker" = {
                      mountpoint = "/mnt/docker-data";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "@/nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "@/var_local" = {
                      mountpoint = "/var/local";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                    "@/var_log" = {
                      mountpoint = "/var/log";
                      mountOptions = ["compress=zstd" "noatime"];
                    };
                  };
                };
              };
            };
          };
        };

        ########################
        ## 2nd physical disk  ##
        ########################
      }
      // (
        if rawdisk2 != null
        then {
          "${rawdisk2}" = {
            device = rawdisk2;
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                root = {
                  label = "rootfs-2";
                  name = "btrfs-2";
                  size = "100%";

                  # We do *not* format this here—mkfs.btrfs from disk-1 will
                  # consume it—so we leave it blank.
                  content = {type = "btrfs";};
                };
              };
            };
          };
        }
        else {}
      ); # no second disk ⇒ nothing extra
  };
}
