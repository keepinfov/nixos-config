# modules/core/default.nix - Core system configuration
{ lib, pkgs, config, conf, inputs, ... }:

{
  imports = [
    ./boot.nix
    ./nix.nix
    ./networking.nix
    ./proxy.nix
    ./security.nix
    ./users.nix
    ./locale.nix
    ./packages.nix
    ../desktop
    ../user
    ../programs
  ];

  # ============================================================================
  # SYSTEM BASICS
  # ============================================================================
  system.stateVersion = conf.stateVersion;

  # Allow unfree packages
  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };
}
