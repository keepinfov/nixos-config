# modules/user/packages.nix - User applications and terminal programs (home-manager)
{ pkgs, conf, inputs, ... }:

let
  userName = conf.user.name;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home-manager.users.${userName} = {
    home.packages = with pkgs; [
      # === From flake inputs ===
      inputs.firefox.packages.${system}.firefox-nightly-bin
      # inputs.ayugram-desktop.packages.${system}.ayugram-desktop

      # === Communication ===
      telegram-desktop
      vesktop         # Discord (proxied)
      gajim           # XMPP
      localsend

      # === Music ===
      spotify         # (proxied)

      # === Browsers ===
      chromium
      tor-browser

      # === Mail ===
      thunderbird

      # === Media ===
      transmission_4-gtk
      yandex-music

      # === Productivity ===
      libreoffice
      obsidian

      # === Graphics ===
      kdePackages.kolourpaint
      # aseprite
      pix

      # === Development ===
      android-studio
      jetbrains-toolbox
      opencode
      gemini-cli
      claude-code

      # === Gaming/Mods ===
      prismlauncher
      # r2modman

      # === Wine ===
      winetricks
      wineWow64Packages.waylandFull

      # === Wayland tools ===
      wl-clipboard
      cliphist
      grim
      slurp
      swaybg

      # === Notifications ===
      libnotify
      swaynotificationcenter

      # === System utilities ===
      alsa-utils
      bluez
      bluetui
      wmctrl

      # === Terminal tools ===
      clock-rs
    ];

    programs = {
      # Terminals
      kitty.enable = true;
      alacritty.enable = true;

      # Rofi launcher
      rofi = {
        enable = true;
        package = pkgs.rofi;
        extraConfig = {
          show-icons = true;
          modi = "run,drun,window,ssh";
          terminal = "alacritty";
          drun-display-format = "{icon} {name}";
          disable-history = false;
          hide-scrollbar = true;
          display-drun = "   Apps ";
          display-run = "   Run ";
          display-window = " 󰕰  Window ";
          display-ssh = " 󰴽  SSH ";
          sidebar-mode = true;
        };
      };
    };
  };
}
