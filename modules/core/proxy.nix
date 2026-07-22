# modules/core/proxy.nix - Transparent proxy configuration using redsocks
{ config, lib, pkgs, conf, ... }:

let
  cfg = config.modules.core.proxy;
  userName = conf.user.name;
in
{
  options.modules.core.proxy = {
    enable = lib.mkEnableOption "Transparent proxying for the 'proxied' group";
    proxyIp = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP of your SOCKS5 proxy";
    };
    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 20172;
      description = "Port of your SOCKS5 proxy";
    };
    redsocksPort = lib.mkOption {
      type = lib.types.port;
      default = 12345;
      description = "Local port redsocks will listen on";
    };
    wrappedApps = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.package;
            description = "Package to wrap (must have .desktop files in share/applications)";
          };
          extraArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            example = [ "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" ];
            description = "Extra CLI arguments appended to the Exec line";
          };
        };
      });
      default = {};
      description = "Apps whose .desktop entries get wrapped to run with the 'proxied' group";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Create a dedicated group for transparent proxying
    users.groups.proxied = {};

    # Add main user to the group
    users.users.${userName}.extraGroups = [ "proxied" ];

    # Setgid wrapper that runs commands with the proxied group.
    # Unlike `sg`, this preserves the full environment (WAYLAND_DISPLAY etc.)
    # so Wayland-native apps don't fall back to XWayland decorations.
    security.wrappers.proxied-exec = {
      source = "${pkgs.writeShellScript "proxied-exec-impl" ''
        exec "$@"
      ''}";
      owner = "root";
      group = "proxied";
      setgid = true;
      permissions = "u+rx,g+rx,o-rx";
    };

    # Generate wrapper .desktop files for proxied apps
    home-manager.users.${userName}.home.file =
      let
        # Collect all .desktop entries from wrapped packages
        desktopEntries = lib.concatMapAttrs (appName: appCfg:
          let
            pkg = appCfg.package;
            extraArgsStr = lib.concatMapStringsSep " " lib.escapeShellArg appCfg.extraArgs;
            desktopDir = "${pkg}/share/applications";
            files = if builtins.pathExists desktopDir
              then builtins.filter
                (n: lib.hasSuffix ".desktop" n)
                (builtins.attrNames (builtins.readDir desktopDir))
              else [];
          in lib.genAttrs files (name: {
            inherit pkg;
            inherit extraArgsStr;
          })
        ) cfg.wrappedApps;

        # Build all wrapped desktop files in one derivation
        wrappedDir = pkgs.runCommand "proxied-desktop-files" {} ''
          mkdir -p $out
          ${lib.concatStrings (lib.mapAttrsToList (name: cfg: ''
            if [ -f "${cfg.pkg}/share/applications/${name}" ]; then
              if [ -n "${cfg.extraArgsStr}" ]; then
                sed "s|^Exec=\(.*\)$|Exec=proxied-exec \1 ${cfg.extraArgsStr}|" \
                  "${cfg.pkg}/share/applications/${name}" > "$out/${name}"
              else
                sed "s|^Exec=\(.*\)$|Exec=proxied-exec \1|" \
                  "${cfg.pkg}/share/applications/${name}" > "$out/${name}"
              fi
            fi
          '') desktopEntries)}
        '';
      in
      builtins.listToAttrs (map (name: {
        name = ".local/share/applications/${name}";
        value.source = "${wrappedDir}/${name}";
      }) (builtins.attrNames desktopEntries));

    # 2. Enable and configure Redsocks
    # Note: Using the specific option structure supported by the NixOS module
    services.redsocks = {
      enable = true;
      redsocks = [
        {
          ip = "127.0.0.1";           # local listen IP
          port = cfg.redsocksPort;    # local listen port
          proxy = "${cfg.proxyIp}:${toString cfg.proxyPort}"; # destination proxy
          type = "socks5";
          
          # We manage the iptables rules manually to target the 'proxied' group
          redirectCondition = false; 
        }
      ];
    };

    # 3. Configure iptables to route traffic for the 'proxied' group
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ cfg.redsocksPort ];
      
      # Apply rules when the firewall starts
      extraCommands = ''
        # Create or flush the REDSOCKS_MANUAL chain
        iptables -t nat -N REDSOCKS_MANUAL 2>/dev/null || true
        iptables -t nat -F REDSOCKS_MANUAL

        # Exclude local and private subnets from being proxied
        iptables -t nat -A REDSOCKS_MANUAL -d 0.0.0.0/8 -j RETURN
        iptables -t nat -A REDSOCKS_MANUAL -d 10.0.0.0/8 -j RETURN
        iptables -t nat -A REDSOCKS_MANUAL -d 127.0.0.0/8 -j RETURN
        iptables -t nat -A REDSOCKS_MANUAL -d 169.254.0.0/16 -j RETURN
        iptables -t nat -A REDSOCKS_MANUAL -d 172.16.0.0/12 -j RETURN
        iptables -t nat -A REDSOCKS_MANUAL -d 192.168.0.0/16 -j RETURN

        # CRITICAL: Exclude the proxy server's IP to prevent infinite network loops!
        iptables -t nat -A REDSOCKS_MANUAL -d ${cfg.proxyIp} -j RETURN

        # Redirect all remaining TCP traffic to the local redsocks port
        iptables -t nat -A REDSOCKS_MANUAL -p tcp -j REDIRECT --to-ports ${toString cfg.redsocksPort}

        # Attach the REDSOCKS_MANUAL chain to the OUTPUT chain, but ONLY for the 'proxied' group
        iptables -t nat -A OUTPUT -p tcp -m owner --gid-owner proxied -j REDSOCKS_MANUAL
      '';
      
      # Clean up rules when the firewall stops
      extraStopCommands = ''
        iptables -t nat -D OUTPUT -p tcp -m owner --gid-owner proxied -j REDSOCKS_MANUAL 2>/dev/null || true
        iptables -t nat -F REDSOCKS_MANUAL 2>/dev/null || true
        iptables -t nat -X REDSOCKS_MANUAL 2>/dev/null || true
      '';
    };
  };
}
