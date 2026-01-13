# hosts/carbon/disko.nix - Disk layout for ThinkPad X1 Carbon Gen 13
#
# CONFIGURATION MODES
# ===================
# Set dualBoot = true  -> Uses existing Windows EFI, creates NixOS partition
# Set dualBoot = false -> Wipes disk, creates new EFI + NixOS (DESTROYS ALL DATA)
#
# For dual-boot: First shrink Windows partition to create free space
# Find partitions with: lsblk -f
#
{ ... }:

let
  # ============================================================================
  # CONFIGURATION - ADJUST THESE FOR YOUR SYSTEM
  # ============================================================================

  # Set to true for dual-boot with Windows, false for single-boot (wipes disk!)
  dualBoot = false;

  # Main disk device
  disk = "/dev/nvme0n1";

  # For dual-boot: existing Windows EFI partition
  existingEsp = "/dev/nvme0n1p1";

  # For dual-boot: size for NixOS partition (e.g., "760G")
  # For single-boot: ignored (uses 100%)
  nixosSize = "760G";

  # Swap size
  swapSize = "8G";
in
{
  disko.devices.disk.main = {
    type = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        # EFI System Partition (only created for single-boot)
        ESP = if dualBoot then {} else {
          label = "ESP";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "defaults" "umask=0077" ];
          };
        };

        # LUKS encrypted NixOS partition
        nixos = {
          size = if dualBoot then nixosSize else "100%";
          label = "nixos-luks";
          content = {
            type = "luks";
            name = "cryptroot";

            extraOpenArgs = [
              "--allow-discards"
              "--perf-no_read_workqueue"
              "--perf-no_write_workqueue"
            ];

            # passwordFile = "/tmp/secret.key";  # For install

            content = {
              type = "btrfs";
              extraArgs = [ "-L" "nixos" "-f" ];

              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [ "subvol=root" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
                };

                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [ "subvol=home" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
                };

                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "subvol=nix" "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };

                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = [ "subvol=persist" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
                };

                "/log" = {
                  mountpoint = "/var/log";
                  mountOptions = [ "subvol=log" "compress=zstd:1" "noatime" "ssd" "discard=async" ];
                };

                "/swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = swapSize;
                };
              };
            };
          };
        };
      };
    };
  };

  # For dual-boot: mount existing Windows EFI partition
  fileSystems."/boot" = if dualBoot then {
    device = existingEsp;
    fsType = "vfat";
    options = [ "defaults" "umask=0077" ];
  } else {};

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var/log".neededForBoot = true;
}
