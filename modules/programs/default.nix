# modules/programs/default.nix - System-level program modules
{ pkgs, ... }:

{
  imports = [
    ./virtualization.nix
    ./gaming.nix
    ./rust.nix
    ./ai.nix
  ];

  # Ask once per desktop entry which route to use; remembered choices can be
  # changed later from `choix panel`.
  modules.core.routing.apps.choose = {
    vesktop = {
      package = pkgs.vesktop;
      label = "Vesktop";
    };
    spotify = {
      package = pkgs.spotify;
      label = "Spotify";
      extraArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
      ];
    };
  };
}
