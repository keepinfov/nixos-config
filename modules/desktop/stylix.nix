# modules/desktop/stylix.nix - System-wide theming
{ lib, pkgs, config, conf, ... }:

let
  userName = conf.user.name;

  # Create solid black wallpaper using ImageMagick v7 syntax
  solidBlackWallpaper = pkgs.runCommand "solid-black.png" {} ''
    ${pkgs.imagemagick}/bin/magick -size 1920x1080 canvas:black PNG:$out
  '';
in
{
  stylix = {
    enable = true;

    # Wallpaper from centralized config
    image = conf.theme.wallpaper.default;

    opacity.terminal = 0.9;

    fonts = rec {
      sizes.terminal = 10;
      serif = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono NF";
      };
      sansSerif = serif;
      monospace = serif;
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    cursor = {
      name = "phinger-cursors-dark";
      size = 24;
      package = pkgs.phinger-cursors;
    };

    base16Scheme = "${pkgs.base16-schemes}/share/themes/${conf.theme.name}.yaml";
    polarity = "dark";
  };

  # Home-manager stylix settings (icons renamed from iconTheme)
  home-manager.users.${userName}.stylix = {
    icons = {
      enable = true;
      package = pkgs.adwaita-icon-theme;
      light = "Adwaita";
      dark = "Adwaita";
    };
  };
}
