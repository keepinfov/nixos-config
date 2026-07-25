# modules/core/routing.nix - Per-app / per-IP / per-domain route selector
#
# Three route classes, each backed by a setgid group + fwmark:
#   direct : bypass VPN and proxy, straight out the physical uplink   (mark 0x1, table `directTable`)
#   proxy  : through the local SOCKS proxy (v2rayA/xray) via redsocks  (mark 0x2, nat redirect)
#   vpn    : through Amnezia (amn0) - this is the default path when the tunnel is up (no mark)
#
# Selection dimensions:
#   per-app    : wrapped .desktop launches the app under the class group (nft matches meta skgid)
#   per-IP     : static CIDRs placed in nft sets (nft matches ip daddr @<class>_dst)
#   per-domain : dnsmasq populates the same nft sets on resolution (opt-in via dnsmasq.enable)
{ config, lib, pkgs, conf, ... }:

let
  cfg = config.modules.core.routing;
  userName = conf.user.name;

  # Fixed gids so nftables can match by numeric group id deterministically.
  classes = {
    direct = { gid = 3001; mark = 1; };
    proxy  = { gid = 3002; mark = 2; };
    vpn    = { gid = 3003; mark = 3; };
  };
  className = n: "route-${n}";

  appSubmodule = lib.types.submodule {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "Package to wrap (must ship .desktop files in share/applications).";
      };
      label = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Application label shown by choix; defaults to the app attribute name.";
      };
      extraArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Extra CLI arguments appended to the Exec line.";
      };
    };
  };
  perClass = descr: lib.mkOption {
    type = lib.types.submodule {
      options = lib.mapAttrs (n: _: lib.mkOption { type = lib.types.attrsOf appSubmodule; default = {}; }) classes;
    };
    default = {};
    description = descr;
  };
  perClassList = descr: lib.mkOption {
    type = lib.types.submodule {
      options = lib.mapAttrs (n: _: lib.mkOption { type = lib.types.listOf lib.types.str; default = []; }) classes;
    };
    default = {};
    description = descr;
  };

  # Exec uses the Desktop Entry quoting rules rather than shell quoting.
  desktopArg = value:
    ''"${lib.replaceStrings [ "\\" "\"" "`" "$" ] [ "\\\\" "\\\"" "\\`" "\\$" ] value}"'';

  # Build overridden .desktop files, prefixing each Exec command.
  wrappedDesktops = wrapperFor: apps:
    let
      entries = lib.concatMapAttrs (appName: appCfg:
        let
          pkg = appCfg.package;
          appLabel = if appCfg.label == null then appName else appCfg.label;
          extraArgsStr = lib.concatMapStringsSep " " desktopArg appCfg.extraArgs;
          desktopDir = "${pkg}/share/applications";
          files = if builtins.pathExists desktopDir
            then builtins.filter (n: lib.hasSuffix ".desktop" n)
              (builtins.attrNames (builtins.readDir desktopDir))
            else [];
        in lib.genAttrs files (name: { inherit appLabel pkg extraArgsStr; })
      ) apps;
      dir = pkgs.runCommand "route-desktop-files" {} ''
        mkdir -p $out
        ${lib.concatStrings (lib.mapAttrsToList (name: e: ''
          if [ -f "${e.pkg}/share/applications/${name}" ]; then
            prefix=${lib.escapeShellArg (wrapperFor e.appLabel name)}
            extra_args=${lib.escapeShellArg e.extraArgsStr}
            CHOIX_DESKTOP_PREFIX="$prefix" \
            CHOIX_DESKTOP_EXTRA_ARGS="$extra_args" \
              ${pkgs.gawk}/bin/awk '
                /^Exec=/ {
                  command = substr($0, 6)
                  printf "Exec=%s %s", ENVIRON["CHOIX_DESKTOP_PREFIX"], command
                  if (ENVIRON["CHOIX_DESKTOP_EXTRA_ARGS"] != "")
                    printf " %s", ENVIRON["CHOIX_DESKTOP_EXTRA_ARGS"]
                  printf "\n"
                  next
                }
                { print }
              ' "${e.pkg}/share/applications/${name}" > "$out/${name}"
          fi
        '') entries)}
      '';
    in builtins.listToAttrs (map (name: {
      name = ".local/share/applications/${name}";
      value.source = "${dir}/${name}";
    }) (builtins.attrNames entries));

  classDesktops = class: wrappedDesktops (_: _: "${className class}-exec");
  chooserDesktops = wrappedDesktops (appLabel: desktopName:
    "choix ask --profile route --key ${desktopArg desktopName} --app ${desktopArg appLabel} --");

  # nft set element block for static per-IP CIDRs of a class.
  setElements = class:
    let ips = cfg.ips.${class} or [];
    in lib.optionalString (ips != []) "elements = { ${lib.concatStringsSep ", " ips} }";

  dt = toString cfg.directTable;
in
{
  options.modules.core.routing = {
    enable = lib.mkEnableOption "per-app/per-IP/per-domain route selector (VPN/proxy/direct)";

    proxyIp = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP of the local SOCKS5 proxy (v2rayA/xray).";
    };
    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 20172;
      description = "Port of the local SOCKS5 proxy.";
    };
    redsocksPort = lib.mkOption {
      type = lib.types.port;
      default = 12345;
      description = "Local port redsocks listens on.";
    };
    vpnInterface = lib.mkOption {
      type = lib.types.str;
      default = "amn0";
      description = "Amnezia tunnel interface (informational).";
    };
    directTable = lib.mkOption {
      type = lib.types.int;
      default = 101;
      description = "Routing table id for the 'direct' (VPN-bypass) class.";
    };

    apps = lib.mkOption {
      type = lib.types.submodule {
        options = (lib.mapAttrs (n: _: lib.mkOption {
          type = lib.types.attrsOf appSubmodule;
          default = {};
          description = "Apps whose .desktop entries always launch through the ${n} route.";
        }) classes) // {
          choose = lib.mkOption {
            type = lib.types.attrsOf appSubmodule;
            default = {};
            description = "Apps whose .desktop entries ask choix for a route on launch.";
          };
        };
      };
      default = {};
      description = "Apps with statically selected or interactively chosen routes.";
    };
    ips     = perClassList "Static destination CIDRs routed per class.";
    domains = perClassList "Domains routed per class (requires dnsmasq.enable).";

    dnsmasq.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run dnsmasq as the system resolver and populate the per-class nft sets from DNS
        answers (per-domain routing). Off by default: it takes over :53 and disables
        systemd-resolved, so enable it only after testing on a host.
      '';
    };
    dnsmasq.upstream = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "1.1.1.1" "8.8.8.8" ];
      description = "Upstream DNS servers for dnsmasq.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 1. Route-class groups + membership
    users.groups = lib.mapAttrs' (n: c: lib.nameValuePair (className n) { gid = c.gid; }) classes;
    users.users.${userName}.extraGroups = map className (builtins.attrNames classes);

    # 2. Per-class setgid wrappers (preserve full env for Wayland apps)
    security.wrappers = lib.mapAttrs' (n: c: lib.nameValuePair "${className n}-exec" {
      source = "${pkgs.writeShellScript "${className n}-exec-impl" ''exec "$@"''}";
      owner = "root";
      group = className n;
      setgid = true;
      permissions = "u+rx,g+rx,o-rx";
    }) classes;

    # 3. Wrapped .desktop files for fixed routes and interactive route selection.
    home-manager.users.${userName}.home.file =
      lib.mkMerge (
        [ (chooserDesktops (cfg.apps.choose or {})) ]
        ++ lib.mapAttrsToList (n: _: classDesktops n (cfg.apps.${n} or {})) classes
      );

    # 3b. choix profile: ask "route this app through?" and remember per key.
    #     Each option runs the matching setgid wrapper defined above.
    programs.choix.enable = true;
    programs.choix.profiles.route = {
      question = "Route %APP% through:";
      layout = {
        mode = "rows";
        rows = [ 2 1 ];
      };
      options = [
        { label = "Direct"; exec = "route-direct-exec %CMD%"; }
        { label = "Proxy"; exec = "route-proxy-exec %CMD%"; }
        { label = "VPN"; exec = "route-vpn-exec %CMD%"; }
      ];
    };

    # 4. redsocks: dumb TCP -> SOCKS5 bridge for the 'proxy' class
    services.redsocks = {
      enable = true;
      redsocks = [{
        ip = "127.0.0.1";
        port = cfg.redsocksPort;
        proxy = "${cfg.proxyIp}:${toString cfg.proxyPort}";
        type = "socks5";
        redirectCondition = false;   # rules are managed by nftables below
      }];
    };

    # 5. nftables: one inet table holds the class sets, the nat redirect (proxy)
    #    and the route-mark chain (direct). vpn class needs nothing (default path).
    networking.nftables.enable = true;
    networking.nftables.tables.route = {
      family = "inet";
      content = ''
        set proxy_dst  { type ipv4_addr; flags interval; ${setElements "proxy"} }
        set direct_dst { type ipv4_addr; flags interval; ${setElements "direct"} }
        set vpn_dst    { type ipv4_addr; flags interval; ${setElements "vpn"} }

        chain class_mark {
          type route hook output priority -150; policy accept;
          meta skgid ${toString classes.direct.gid} meta mark set 0x1
          ip daddr @direct_dst meta mark set 0x1
        }

        chain class_nat {
          type nat hook output priority -100; policy accept;
          ip daddr { 0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 } return
          ip daddr ${cfg.proxyIp} return
          meta skgid ${toString classes.proxy.gid} meta l4proto tcp redirect to :${toString cfg.redsocksPort}
          ip daddr @proxy_dst meta l4proto tcp redirect to :${toString cfg.redsocksPort}
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ cfg.redsocksPort ];

    # 6. Policy routing for the 'direct' class: fwmark 0x1 -> directTable.
    #    The default route in that table is seeded by the NM dispatcher (below),
    #    which reads the physical uplink's gateway even while the VPN is up.
    systemd.services.route-direct-rule = {
      description = "ip rule for the 'direct' route class";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-pre.target" ];
      path = [ pkgs.iproute2 ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        ip rule del fwmark 0x1 table ${dt} 2>/dev/null || true
        ip rule add fwmark 0x1 table ${dt} priority 1000
      '';
      preStop = ''
        ip rule del fwmark 0x1 table ${dt} 2>/dev/null || true
      '';
    };

    networking.networkmanager.dispatcherScripts = [{
      source = pkgs.writeShellScript "route-direct-dispatch" ''
        iface="$1"; action="$2"
        case "$iface" in
          lo|${cfg.vpnInterface}|tailscale0|docker*|br-*|veth*|virbr*|wg*) exit 0 ;;
        esac
        case "$action" in
          up|dhcp4-change|dhcp6-change|connectivity-change)
            gw=$(${pkgs.iproute2}/bin/ip -4 -o route show default dev "$iface" \
                 | ${pkgs.gawk}/bin/awk '{print $3; exit}')
            if [ -n "$gw" ]; then
              ${pkgs.iproute2}/bin/ip route replace default via "$gw" dev "$iface" table ${dt}
            fi
            ;;
        esac
      '';
    }];

    # 7. Per-domain routing via dnsmasq (opt-in - takes over the resolver).
    services.dnsmasq = lib.mkIf cfg.dnsmasq.enable {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        server = cfg.dnsmasq.upstream;
        nftset = lib.flatten (lib.mapAttrsToList (n: _:
          map (d: "/${d}/4#inet#route#${n}_dst") (cfg.domains.${n} or [])
        ) classes);
      };
    };
    services.resolved.enable = lib.mkIf cfg.dnsmasq.enable (lib.mkForce false);
  };
}
