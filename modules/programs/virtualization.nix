# modules/programs/virtualization.nix - Docker, VirtualBox
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.programs.virtualization;
in
{
  options.programs.virtualization = {
    enable = mkEnableOption "Virtualization support (Docker, OBS, etc.)" // { default = true; };
  };

  config = mkIf cfg.enable {
    virtualisation = {
      docker = {
        enable = true;
        enableOnBoot = true;
      };

      # virtualbox = {
      #   host = {
      #     enable = true;
      #     enableExtensionPack = true;
      #   };
      # };
    };
    programs.obs-studio = {
      enable = true;
      enableVirtualCamera = true;
      plugins = with pkgs.obs-studio-plugins; [
        droidcam-obs
      ];
    };
  };
}
