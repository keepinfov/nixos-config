# modules/programs/default.nix - System-level program modules
{ pkgs, ... }:

{
  imports = [
    ./virtualization.nix
    ./gaming.nix
    ./rust.nix
    ./ai.nix
  ];

  # Apps that always launch through the proxy
  modules.core.proxy.wrappedApps = {
    vesktop.package = pkgs.vesktop;
    spotify = {
      package = pkgs.spotify;
      extraArgs = [
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
      ];
    };
  };
}
