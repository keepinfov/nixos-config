# modules/core/security.nix - Security services
{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.modules.core.security;
in
{
  options.modules.core.security = {
    tailscale.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Tailscale VPN";
    };
    ssh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable OpenSSH server (key-only, no root)";
    };
    fail2ban.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable fail2ban intrusion prevention";
    };
    v2raya.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable v2rayA proxy service";
    };
  };

  config = {
    services = mkMerge [
      (mkIf cfg.tailscale.enable {
        tailscale.enable = true;
      })
      (mkIf cfg.ssh.enable {
        openssh = {
          enable = true;
          settings = {
            PermitRootLogin = "no";
            PasswordAuthentication = false;
          };
        };
      })
      (mkIf cfg.fail2ban.enable {
        fail2ban = {
          enable = true;
          maxretry = 10;
          bantime-increment.enable = true;
        };
      })
      {
        v2rayb = {
          enable = false;
          cliPackage = pkgs.xray;
          desktop = true;
        };
      }
      (mkIf cfg.v2raya.enable {
        v2raya = {
          enable = true;
          cliPackage = pkgs.xray;
        };
      })
    ];

    # Security hardening
    security = {
      sudo.wheelNeedsPassword = true;
      polkit.enable = true;

      pam.services = {
        login = {
          fprintAuth = false;
          u2fAuth = true;
        };
        sudo.u2fAuth = true;
        gdm-fingerprint = lib.mkIf (config.services.fprintd.enable) {
          text = ''
            auth       required                    pam_shells.so
            auth       requisite                   pam_nologin.so
            auth       requisite                   pam_faillock.so      preauth
            auth       required                    ${pkgs.fprintd}/lib/security/pam_fprintd.so
            auth       optional                    pam_permit.so
            auth       required                    pam_env.so
            auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
            auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

            account    include                     login

            password   required                    pam_deny.so

            session    include                     login
            session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
          '';
        };
      };
    };
  };
}
