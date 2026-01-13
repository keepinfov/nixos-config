# lib/default.nix - Central configuration constants and utilities
{ lib, root }:

rec {
  # ============================================================================
  # VERSION MANAGEMENT
  # Change this single value to update system version across all hosts
  # ============================================================================
  nixosVersion = "unstable";  # Options: "25.05", "25.11", "unstable"
  
  # Derive the nixpkgs branch from version
  nixpkgsBranch = if nixosVersion == "unstable" 
    then "nixos-unstable" 
    else "nixos-${nixosVersion}";
  
  # State version for home-manager and NixOS (usually stays stable)
  stateVersion = "26.05";
  
  # ============================================================================
  # USER CONFIGURATION
  # ============================================================================
  user = {
    name = "x";
    fullName = "x";
    email = "";  # Set if needed
    shell = "fish";
  };
  
  # ============================================================================
  # PATHS
  # ============================================================================
  paths = {
    configDir = "/home/${user.name}/config";
    cargoDir = "/home/${user.name}/.cargo/bin";
  };
  
  # ============================================================================
  # THEMING
  # ============================================================================
  theme = {
    name = "catppuccin-mocha";
    wallpaper = {
      default = root + "/wallpaper.png";
      hyprland = "solid-black.png";
    };
    cursor = {
      name = "phinger-cursors-dark";
      size = 24;
    };
    font = {
      name = "JetBrainsMono NF";
      size = 10;
    };
  };
  
  # ============================================================================
  # NETWORK
  # ============================================================================
  network = {
    dns = [
      "1.1.1.1"         # Cloudflare
      "8.8.8.8"         # Google
    ];
    tailscaleDns = "100.126.179.69";
  };
  
  # ============================================================================
  # KEYBOARD
  # ============================================================================
  keyboard = {
    layout = "us,ru";
    options = "caps:escape,grp:win_space_toggle";
  };
  
  # ============================================================================
  # LOCALE
  # ============================================================================
  locale = {
    timezone = "Europe/Moscow";
    lang = "en_US.UTF-8";
  };
  
  # ============================================================================
  # HOST CONFIGURATIONS
  # ============================================================================
  hosts = {
    maibenben = {
      hostname = "maibenben";
      hardware = {
        cpu = "intel";
        gpu = "nvidia";
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
      swap.size = 16 * 1024;  # 16GB
      features = [ "nvidia" "gaming" ];
    };
    
    carbon = {
      hostname = "carbon";
      hardware = {
        cpu = "intel";
        gpu = "intel";  # ThinkPad X1 Carbon Gen 13 Aura - integrated graphics
      };
      swap.size = 8 * 1024;  # 8GB - sufficient for ultrabook
      features = [ "power-saving" "ultrabook" ];
    };
  };
  
  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================
  
  # Check if a host has a specific feature
  hasFeature = host: feature: builtins.elem feature (hosts.${host}.features or []);
  
  # Get host config or default
  getHost = hostname: hosts.${hostname} or (throw "Unknown host: ${hostname}");
}
