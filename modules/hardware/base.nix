# modules/hardware/base.nix - Baseline hardware, audio and fonts for all hosts
{ pkgs, ... }:

{
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
