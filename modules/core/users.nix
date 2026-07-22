# modules/core/users.nix - User configuration
{ pkgs, config, ... }:

let
  cfg = config;
in
{
  users.users = {
    x = {
      isNormalUser = true;
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICpcSz9dWJobKwLn1QyW4mfo7UCp3jcSBm/2dOxaYSqk u0_a384@localhost"
      ];
      extraGroups = [
        "wheel"
        "docker"
        "vboxusers"
        "kvm"
        "networkmanager"
        "adbusers"
        "video"
        "audio"
        "input"
        "dialout"  # For serial ports (embedded dev)
      ];
    };
    
    root.shell = pkgs.fish;
  };
}
