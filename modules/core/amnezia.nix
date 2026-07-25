# modules/core/amnezia.nix - AmneziaVPN client + config-ownership guard
{ lib, config, conf, ... }:

let
  cfg = config.modules.core.amnezia;
  userName = conf.user.name;
in
{
  options.modules.core.amnezia = {
    enable = lib.mkEnableOption "AmneziaVPN client" // { default = true; };
  };

  config = lib.mkIf cfg.enable {
    programs.amnezia-vpn.enable = true;

    # The AmneziaVPN GUI stores its QSettings (imported servers) under the user's
    # home. If the GUI is ever launched as root (sudo/pkexec) the .conf becomes
    # root:root 0600 and the unprivileged GUI can no longer persist changes, so
    # servers silently reset on the next launch. Reassert user ownership on every
    # boot/rebuild so the settings always survive. The GUI never needs root — the
    # privileged AmneziaVPN.service handles tunnels over its daemon socket.
    systemd.tmpfiles.rules = [
      "Z /home/${userName}/.config/AmneziaVPN.ORG - ${userName} users - -"
      "Z /home/${userName}/.local/share/AmneziaVPN.ORG - ${userName} users - -"
      "Z /home/${userName}/.cache/AmneziaVPN.ORG - ${userName} users - -"
    ];
  };
}
