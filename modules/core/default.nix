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
    ../shell
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

  # ============================================================================
  # HARDWARE BASICS
  # ============================================================================
  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [ pkgs.pocl ];
    };

	ipu6 = {
	  enable = true;
	  platform = "ipu6epmtl";
	};
	enableAllFirmware = true;
	enableRedistributableFirmware = true;
  };

  # ============================================================================
  # AUDIO & VIDEO
  # ============================================================================
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
    wireplumber.enable = true;
  };

  # ============================================================================
  # FONTS
  # ============================================================================
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    corefonts
  ];
}
